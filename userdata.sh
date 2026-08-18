#!/bin/bash

dnf update -y
dnf install -y python3

mkdir -p /opt/app

cat > /opt/app/server.py <<'EOF'
from http.server import BaseHTTPRequestHandler, HTTPServer
import socket

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        hostname = socket.gethostname()

        response = f"""
        <html>
        <body>
            <h1>Hello from EC2</h1>
            <p>Hostname: {hostname}</p>
            <p>Path: {self.path}</p>
        </body>
        </html>
        """

        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(response.encode())

server = HTTPServer(("0.0.0.0", 8080), Handler)

print("Server running on port 8080")
server.serve_forever()
EOF

nohup python3 /opt/app/server.py > /var/log/app.log 2>&1 &