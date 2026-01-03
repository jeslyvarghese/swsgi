import sys
from flask import Flask, request
import logging

logging.basicConfig(filename='myapp.log', level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    return "Hello, World!", 200

def application(environ, start_response):
    bytes = app.wsgi_app(environ, start_response)
    return bytes
