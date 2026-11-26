import argparse
import os
import subprocess
import sys
import signal
from http.server import HTTPServer, SimpleHTTPRequestHandler
import threading
import time

def parse_args():
    parser = argparse.ArgumentParser(description='Host a local server and open it in Chromium incognito.')
    parser.add_argument('directory', help='Directory to host')
    return parser.parse_args()

def start_server(directory):
    os.chdir(directory)
    server_address = ('', 8000)
    httpd = HTTPServer(server_address, SimpleHTTPRequestHandler)
    httpd.serve_forever()

def open_browser():
    return subprocess.Popen(['chromium-browser', '--incognito', 'http://localhost:8000/DianeDaggers.html'])

def signal_handler(sig, frame):
    sys.exit(0)

def main():
    args = parse_args()
    
    if not os.path.isdir(args.directory):
        print(f"Error: {args.directory} is not a valid directory")
        sys.exit(1)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    server_thread = threading.Thread(target=start_server, args=(args.directory,))
    server_thread.daemon = True
    server_thread.start()
    
    time.sleep(1)  # Give server time to start
    browser_process = open_browser()
    
    try:
        browser_process.wait()
        sys.exit(0)
    except KeyboardInterrupt:
        sys.exit(0)

if __name__ == '__main__':
    main()
