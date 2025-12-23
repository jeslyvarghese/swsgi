import sys
from swsgi_worker import application

def start_response(status, response_headers):
    sys.stdout.write(f"Status: {status}\n")
    for header in response_headers:
        sys.stdout.write(f"{header[0]}: {header[1]}\n")
    sys.stdout.write("\n")
    sys.stdout.flush()
    
def main():
    while True:
        payload = sys.stdin.read()
        environ = eval(payload)
        
        sys.stdout.buffer.write("Got content from Swift WSGI runtime:\n")
        sys.stdout.buffer.write(b'\n')
        sys.stdout.flush()
        
        body = application(environ, start_response)
        for chunk in body:
            sys.stdout.buffer.write(chunk)
            
        sys.stdout.buffer.write(b'\n')
        sys.stdout.flush()
        
if __name__ == "__main__":
    main()