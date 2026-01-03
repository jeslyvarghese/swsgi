import sys
from swsgi_worker import application
import logging

logging.basicConfig(filename='myapp.log', level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

logger.info("Is a tty:" + str(sys.stdout.isatty()))

def start_response(status, response_headers):
    logger.info("Invoked start response")
    sys.stdout.write(f"HTTP/1.1 {status}\r\n")
    logger.info("Wrote status")
    logger.info("Wiring headers")
    logger.info(response_headers)
    for header in response_headers:
        logger.info("Wrote header")
        logger.info(header)
        sys.stdout.write(f"{header[0]}: {header[1]}\r\n")
    logger.info("Finished writing headers")
    sys.stdout.write('\r\n')
    sys.stdout.flush()
    logger.info("Finished writing")
    
def main():
    try:
        while True:
            payload = sys.stdin.readline()

            if not payload:
                continue
            
            logger.info("Payload:")
            logger.info(payload)
            
            environ = eval(payload)

            logger.info(environ)
            
            body = application(environ, start_response)
            
            logger.info(body)
            
            for chunk in body:
                sys.stdout.buffer.write(chunk)
            
            sys.stdout.write('\r\n\r\n')
            sys.stdout.flush()
            logger.info("Finished writing")
            break
    except Exception as e:
            logger.error(e)
        
if __name__ == "__main__":
    main()
