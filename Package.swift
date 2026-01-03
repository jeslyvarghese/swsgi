// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "wsgi",
  platforms: [
    .macOS(.v14)
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-format.git", from: "601.0.0"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", branch: "main"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "wsgi",
      dependencies: [
        .product(name: "Subprocess", package: "swift-subprocess")
      ],
      exclude: [
        "../__pycache__/",
        "../env",
        "../swsgi_runtime.py",
        "../swsgi_worker.py",
        "../myapp.log"
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
