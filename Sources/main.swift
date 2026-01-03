// The Swift Programming Language
// https://docs.swift.org/swift-book
import Darwin
import Foundation
import Subprocess
import System

enum SocketError: Error {
    case creationFailed
    case bindFailed
    case listenFailed
    case acceptFailed
    case closeFailed
}

enum ReceiveError: Error {
    case eof
    case readFailed(Int32)
}
struct Socket: ~Copyable {
    enum State {
        case created
        case bound
        case listening
        case closed
    }

    struct Config {
        let backlog: Int32 = 128
        let address: String
        let port: UInt16
        let acceptMaxLength: Int = 1024
    }

    struct Connection: ~Copyable {
        let fd: Int32
        let acceptMaxLength: Int

        func send(data: Data) throws {
            try data.withUnsafeBytes { buffer in
                guard Darwin.send(fd, buffer.baseAddress, buffer.count, 0) != -1
                else {
                    throw SocketError.creationFailed
                }
            }
        }

        func receive() throws -> Environment {
            var buffer = Data(count: acceptMaxLength)
            let bytesRead = buffer.withUnsafeMutableBytes { ptr in
                Darwin.recv(fd, ptr.baseAddress, acceptMaxLength, 0)
            }
            guard bytesRead != -1 else {
                throw SocketError.creationFailed
            }
            return try Environment(data: buffer.prefix(bytesRead))
        }

        deinit {
            Darwin.close(fd)
            print("Closed connection with fd: \(fd)")
        }
    }

    private let fd: Int32
    private(set) var state: State = .created

    let config: Config

    init(config: Config) throws {
        let socketFD = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD != -1 else {
            fatalError("Failed to create socket: Error \(errno)")
        }
        self.fd = socketFD
        self.state = .created
        self.config = config
        print("Created socket with fd: \(fd)")
    }

    mutating func bind() throws {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(config.port).bigEndian
        inet_pton(AF_INET, config.address, &addr.sin_addr)
        withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                guard
                    Darwin.bind(
                        self.fd,
                        $0,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    ) != -1
                else {
                    fatalError("Failed to bind socket: Error \(errno)")
                }
                print("Bound socket with fd: \(fd) to address: \($0.pointee)")
            }
        }
        state = .bound
    }

    mutating func close() throws {
        guard Darwin.close(self.fd) != -1 else {
            throw SocketError.closeFailed
        }
        print("Closed socket with fd: \(fd)")
        state = .closed
    }

    mutating func listen() throws {
        guard Darwin.listen(self.fd, config.backlog) != -1 else {
            throw SocketError.listenFailed
        }
        state = .listening
    }

    func accept() throws -> Connection {
        var addr = sockaddr_storage()
        var addrLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let clientFD = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.accept(self.fd, $0, &addrLen)
            }
        }
        guard clientFD != -1 else {
            fatalError("Failed to accept connection")
        }
        print("Accepted connection with fd: \(clientFD)")
        return Connection(fd: clientFD, acceptMaxLength: config.acceptMaxLength)
    }
}

struct Environment: Codable {
    let requestMethod: String
    let scriptName: String
    let pathInfo: String
    let queryString: String
    let contentType: String
    let contentLength: String
    let serverName: String
    let serverPort: String
    let serverProtocol: String
    let wsgiVersion: String = "(1, 0)"
    let wsgiUrlScheme: String = "http"
    let wsgiInput: String = "/dev/stdin"
    let wsgiErrors: String = "/dev/stderr"
    let wsgiMultithread: String = "false"
    let wsgiMultiprocess: String = "false"
    let wsgiRunOnce: String = "false"

    enum CodingKeys: String, CodingKey, CaseIterable {
        case requestMethod = "REQUEST_METHOD"
        case scriptName = "SCRIPT_NAME"
        case pathInfo = "PATH_INFO"
        case queryString = "QUERY_STRING"
        case contentType = "CONTENT_TYPE"
        case contentLength = "CONTENT_LENGTH"
        case serverName = "SERVER_NAME"
        case serverPort = "SERVER_PORT"
        case serverProtocol = "SERVER_PROTOCOL"
        case wsgiVersion = "wsgi.version"
        case wsgiUrlScheme = "wsgi.url_scheme"
        case wsgiInput = "wsgi.input"
        case wsgiErrors = "wsgi.errors"
        case wsgiMultithread = "wsgi.multithread"
        case wsgiMultiprocess = "wsgi.multiprocess"
        case wsgiRunOnce = "wsgi.run_once"
    }

    var cString: String {
        let cString =
            "{\"REQUEST_METHOD\":\"\(requestMethod)\",\"SCRIPT_NAME\":\"\(scriptName)\",\"PATH_INFO\":\"\(pathInfo)\",\"QUERY_STRING\":\"\(queryString)\",\"CONTENT_TYPE\":\"\(contentType)\",\"CONTENT_LENGTH\":\"\(contentLength)\",\"SERVER_NAME\":\"\(serverName)\",\"SERVER_PORT\":\"\(serverPort)\",\"SERVER_PROTOCOL\":\"\(serverProtocol)\",\"wsgi.version\":\"\(wsgiVersion)\",\"wsgi.url_scheme\":\"\(wsgiUrlScheme)\",\"wsgi.input\":\"\(wsgiInput)\",\"wsgi.errors\":\"\(wsgiErrors)\",\"wsgi.multithread\":\"\(wsgiMultithread)\",\"wsgi.multiprocess\":\"\(wsgiMultiprocess)\",\"wsgi.run_once\":\"\(wsgiRunOnce)\"}\n"
        return cString
    }

    init(data: Data) throws {
        guard let requestString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "InvalidData", code: 0, userInfo: nil)
        }
        print("Request String: \(requestString)")

        self.scriptName = ""

        let components = requestString.components(separatedBy: "\r\n\r\n")
        let headerPart = components[0]

        let headerLines = headerPart.components(separatedBy: "\r\n")
        let requestLine = headerLines[0].components(separatedBy: " ")

        self.requestMethod = requestLine[0]

        let pathComponents = requestLine[1].components(separatedBy: "?")
        self.pathInfo = pathComponents[0]
        self.queryString = pathComponents.count > 1 ? pathComponents[1] : ""
        self.serverProtocol = requestLine[2]

        self.contentType =
            headerLines.first(where: { $0.hasPrefix("Content-Type:") })?
            .replacingOccurrences(
                of: "Content-Type: ",
                with: ""
            ) ?? ""
        self.contentLength =
            headerLines.first(where: { $0.hasPrefix("Content-Length:") })?
            .replacingOccurrences(
                of: "Content-Length: ",
                with: ""
            ) ?? ""

        self.serverName = "SWGI-Server"
        self.serverPort = "8100"

        var headersDict = [String: String]()
        for line in headerLines.dropFirst() {
            let headerComponents = line.components(separatedBy: ": ")
            if headerComponents.count == 2 {
                headersDict[headerComponents[0]] = headerComponents[1]
            }
        }
    }
}

struct PythonSupervisor: ~Copyable {
    let config: Configuration
    struct SpawnConfiguration {
        let execution: Execution
        let writer: StandardInputWriter
        let reader: () async -> AsyncBufferSequence
    }

    init(parentPath: String) async {
        let executablePath = FilePath(parentPath + "/env/bin/python")
        let scriptPath = parentPath + "/swsgi_runtime.py"
        self.config = Configuration(
            .path(executablePath),
            arguments: [scriptPath],
            workingDirectory: FilePath(parentPath)
        )
    }

    consuming func spawn(
        _ spwanContext: (SpawnConfiguration) async throws -> Void
    ) async throws -> TerminationStatus {
        return try await run(
            config,
            preferredBufferSize: 1024
        ) { execution, input, output, _ in
            try await spwanContext(
                SpawnConfiguration(
                    execution: execution,
                    writer: input,
                    reader: { output }
                )
            )
        }.terminationStatus
    }
}

struct HTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data?

    func toData() -> Data {
        var responseString = "HTTP/1.1 \(statusCode) \r\n"
        for (key, value) in headers {
            responseString += "\(key): \(value)\r\n"
        }
        responseString += "\r\n"
        var responseData = Data(responseString.utf8)
        if let body = body {
            responseData.append(body)
        }
        return responseData
    }
}
struct App {
    static func main() async throws {
        var socket = try Socket(config: .init(address: "127.0.0.1", port: 8100))
        defer { try? socket.close() }

        try socket.bind()
        try socket.listen()

        let terminationResult = try await PythonSupervisor(
            parentPath: "/Users/jesly/Workspace/swsgi/"
        )
        .spawn { context in
            while true {
                let connection = try socket.accept()
                let payload = try connection.receive()

                _ = try await context.writer.write(payload.cString)

                for try await line in await context.reader().lines() {
                    print(line)
                    try connection.send(data: line.data(using: .utf8)!)
                }
            }
        }

        print(terminationResult)
    }
}

try await App.main()
