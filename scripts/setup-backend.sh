#!/bin/bash
set -e

# Create backend app structure
mkdir -p /opt/app/templates/admin
mkdir -p /opt/app/static/{css,js}
cd /opt/app

# Create Python HTTP server with admin routes (no external dependencies)
cat > app.py << 'PYTHON'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import urllib.parse
from datetime import datetime
import os
import uuid

PORT = 5000
sessions = {}
companies = []

class AdminHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        
        if parsed.path == '/health':
            self.send_json({'status': 'healthy'})
        
        elif parsed.path == '/admin/login':
            self.send_html(LOGIN_HTML)
        
        elif parsed.path == '/admin/dashboard':
            cookie = self.headers.get('Cookie', '')
            if 'session=' in cookie:
                session_id = cookie.split('session=')[1].split(';')[0]
                if session_id in sessions:
                    self.send_html(DASHBOARD_HTML)
                    return
            self.send_redirect('/admin/login')
        
        elif parsed.path == '/admin/logout':
            self.send_response(302)
            self.send_header('Location', '/admin/login')
            self.send_header('Set-Cookie', 'session=; Max-Age=0')
            self.end_headers()
        
        elif parsed.path == '/admin/check-session':
            cookie = self.headers.get('Cookie', '')
            authenticated = False
            if 'session=' in cookie:
                session_id = cookie.split('session=')[1].split(';')[0]
                authenticated = session_id in sessions
            self.send_json({'authenticated': authenticated})
        
        elif parsed.path.startswith('/api/companies/'):
            company_id = parsed.path.split('/')[-1]
            company = next((c for c in companies if c['id'] == company_id), None)
            if company:
                self.send_json(company)
            else:
                self.send_json({'error': 'Not found'}, 404)
        
        elif parsed.path == '/api/admin/companies':
            self.send_json({'companies': companies})
        
        else:
            self.send_json({'error': 'Not found'}, 404)
    
    def do_POST(self):
        if self.path == '/admin/login':
            content_length = int(self.headers['Content-Length'])
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))
            
            if data.get('username') == 'admin' and data.get('password') == 'admin123':
                session_id = str(uuid.uuid4())
                sessions[session_id] = {'username': 'admin'}
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Set-Cookie', f'session={session_id}; Path=/; HttpOnly')
                self.end_headers()
                self.wfile.write(json.dumps({'success': True}).encode())
            else:
                self.send_json({'success': False, 'error': 'Invalid credentials'}, 401)
        
        elif self.path == '/api/companies':
            content_length = int(self.headers['Content-Length'])
            body = self.rfile.read(content_length)
            company = json.loads(body.decode('utf-8'))
            company['status'] = 'pending'
            companies.append(company)
            self.send_json({'success': True, 'id': company['id']}, 201)
        
        else:
            self.send_json({'error': 'Not found'}, 404)
    
    def do_PUT(self):
        if '/approve' in self.path:
            company_id = self.path.split('/')[-2]
            company = next((c for c in companies if c['id'] == company_id), None)
            if company:
                company['status'] = 'approved'
                company['approvedDate'] = datetime.now().isoformat()
            self.send_json({'success': True})
        
        elif '/reject' in self.path:
            company_id = self.path.split('/')[-2]
            company = next((c for c in companies if c['id'] == company_id), None)
            if company:
                company['status'] = 'rejected'
            self.send_json({'success': True})
        
        else:
            self.send_json({'error': 'Not found'}, 404)
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def send_html(self, html):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())
    
    def send_redirect(self, location):
        self.send_response(302)
        self.send_header('Location', location)
        self.end_headers()

LOGIN_HTML = '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Admin Login</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;background:#f4f4f4;padding:20px}.container{max-width:400px;margin:100px auto;background:white;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,0.1)}h1{text-align:center;color:#333;margin-bottom:30px}.form-group{margin-bottom:20px}label{display:block;margin-bottom:5px;color:#555}input{width:100%;padding:10px;border:1px solid #ddd;border-radius:4px}button{width:100%;padding:12px;background:#007bff;color:white;border:none;border-radius:4px;cursor:pointer;font-size:16px}button:hover{background:#0056b3}.error{color:red;margin-top:10px;text-align:center}</style>
</head><body><div class="container"><h1>Admin Login</h1><form id="loginForm">
<div class="form-group"><label>Username</label><input type="text" id="username" required></div>
<div class="form-group"><label>Password</label><input type="password" id="password" required></div>
<button type="submit">Login</button><div id="error" class="error"></div></form></div>
<script>document.getElementById('loginForm').addEventListener('submit',async(e)=>{e.preventDefault();const username=document.getElementById('username').value;const password=document.getElementById('password').value;try{const response=await fetch('/admin/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username,password})});const result=await response.json();if(result.success){window.location.href='/admin/dashboard'}else{document.getElementById('error').textContent='Invalid credentials'}}catch(error){document.getElementById('error').textContent='Login failed'}});</script>
</body></html>'''

DASHBOARD_HTML = '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Admin Dashboard</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;background:#f4f4f4}header{background:#007bff;color:white;padding:20px;display:flex;justify-content:space-between;align-items:center}header h1{font-size:24px}header a{color:white;text-decoration:none;padding:8px 16px;background:rgba(255,255,255,0.2);border-radius:4px}header a:hover{background:rgba(255,255,255,0.3)}.container{max-width:1200px;margin:30px auto;padding:0 20px}.dashboard{background:white;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,0.1)}h2{color:#333;margin-bottom:20px}.registrations-list{margin-bottom:40px}.company-card{background:#f9f9f9;padding:15px;margin-bottom:10px;border-radius:4px;border-left:4px solid #007bff}.company-card h3{color:#333;margin-bottom:10px}.company-card p{color:#666;margin:5px 0}</style>
</head><body><header><h1>Admin Dashboard</h1><a href="/admin/logout">Logout</a></header>
<div class="container"><div class="dashboard"><h2>Pending Registrations</h2>
<div id="pendingRegistrations" class="registrations-list"><p>No pending registrations</p></div>
<h2>Approved Registrations</h2><div id="approvedRegistrations" class="registrations-list">
<p>No approved registrations</p></div></div></div></body></html>'''

if __name__ == '__main__':
    with socketserver.TCPServer(("", PORT), AdminHandler) as httpd:
        print(f"Server running on port {PORT}")
        httpd.serve_forever()
PYTHON

chmod +x app.py

# Create systemd service
cat > /etc/systemd/system/backend-app.service << 'SERVICE'
[Unit]
Description=Backend HTTP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start service
systemctl daemon-reload
systemctl enable backend-app
systemctl start backend-app
