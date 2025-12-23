import sys
from flask import Flask, request

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    return "Hello, World!", 200

def application(environ, start_response):
    return app.wsgi_app(environ, start_response)  