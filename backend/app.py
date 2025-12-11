#!/usr/bin/env python3
import http.server
import socketserver
import json
import urllib.parse
from datetime import datetime
import os
import uuid
import pymysql

PORT = 5000
DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_USER = os.environ.get('DB_USER', 'admin')
DB_PASS = os.environ.get('DB_PASS', 'changeme123!')
DB_NAME = os.environ.get('DB_NAME', 'appdb')
sessions = {}

# Initialize database
def get_db():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor
    )

def init_db():
    import time
    for i in range(30):
        try:
            conn = get_db()
            with conn.cursor() as c:
                c.execute('''CREATE TABLE IF NOT EXISTS companies (
                    id VARCHAR(255) PRIMARY KEY,
                    companyName VARCHAR(255),
                    registrationNumber VARCHAR(255),
                    businessType VARCHAR(255),
                    address TEXT,
                    contactPerson VARCHAR(255),
                    email VARCHAR(255),
                    phone VARCHAR(255),
                    submittedDate VARCHAR(255),
                    status VARCHAR(50),
                    approvedDate VARCHAR(255)
                )''')
            conn.commit()
            conn.close()
            print('Database initialized')
            return
        except Exception as e:
            print(f'DB init attempt {i+1} failed: {e}')
            time.sleep(5)
    print('Failed to initialize database after 30 attempts')

# Run init_db on import/start - MOVED TO THREAD IN MAIN
# init_db()

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
            search_term = parsed.path.split('/')[-1]
            conn = get_db()
            with conn.cursor() as c:
                c.execute('SELECT * FROM companies WHERE id=%s OR registrationNumber=%s', (search_term, search_term))
                company = c.fetchone()
            conn.close()
            if company:
                self.send_json(company)
            else:
                self.send_json({'error': 'Not found'}, 404)
        
        elif parsed.path == '/api/admin/companies':
            conn = get_db()
            with conn.cursor() as c:
                c.execute('SELECT * FROM companies')
                companies = c.fetchall()
            conn.close()
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
            conn = get_db()
            with conn.cursor() as c:
                c.execute('''INSERT INTO companies VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)''',
                         (company['id'], company['companyName'], company['registrationNumber'],
                          company['businessType'], company['address'], company['contactPerson'],
                          company['email'], company['phone'], company['submittedDate'],
                          'pending', None))
            conn.commit()
            conn.close()
            self.send_json({'success': True, 'id': company['id']}, 201)
        
        else:
            self.send_json({'error': 'Not found'}, 404)
    
    def do_PUT(self):
        if '/approve' in self.path:
            company_id = self.path.split('/')[-2]
            conn = get_db()
            with conn.cursor() as c:
                c.execute('UPDATE companies SET status=%s, approvedDate=%s WHERE id=%s',
                         ('approved', datetime.now().isoformat(), company_id))
            conn.commit()
            conn.close()
            self.send_json({'success': True})
        
        elif '/reject' in self.path:
            company_id = self.path.split('/')[-2]
            conn = get_db()
            with conn.cursor() as c:
                c.execute('UPDATE companies SET status=%s WHERE id=%s', ('rejected', company_id))
            conn.commit()
            conn.close()
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
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;background:#f4f4f4}header{background:#007bff;color:white;padding:20px;display:flex;justify-content:space-between;align-items:center}header h1{font-size:24px}header a{color:white;text-decoration:none;padding:8px 16px;background:rgba(255,255,255,0.2);border-radius:4px}header a:hover{background:rgba(255,255,255,0.3)}.container{max-width:1200px;margin:30px auto;padding:0 20px}.dashboard{background:white;padding:30px;border-radius:8px;box-shadow:0 2px 10px rgba(0,0,0,0.1)}h2{color:#333;margin-bottom:20px}.registrations-list{margin-bottom:40px}.company-card{background:#f9f9f9;padding:15px;margin-bottom:10px;border-radius:4px;border-left:4px solid #007bff}.company-card h3{color:#333;margin-bottom:10px}.company-card p{color:#666;margin:5px 0}button{padding:8px 16px;margin:5px;border:none;border-radius:4px;cursor:pointer}.approve{background:#28a745;color:white}.reject{background:#dc3545;color:white}</style>
</head><body><header><h1>Admin Dashboard</h1><a href="/admin/logout">Logout</a></header>
<div class="container"><div class="dashboard"><h2>Pending Registrations</h2>
<div id="pendingRegistrations" class="registrations-list"><p>Loading...</p></div>
<h2>Approved Registrations</h2><div id="approvedRegistrations" class="registrations-list">
<p>Loading...</p></div></div></div>
<script>
async function loadCompanies(){try{const res=await fetch('/api/admin/companies');const data=await res.json();const pending=data.companies.filter(c=>c.status==='pending');const approved=data.companies.filter(c=>c.status==='approved');document.getElementById('pendingRegistrations').innerHTML=pending.length?pending.map(c=>`<div class="company-card"><h3>${c.companyName}</h3><p><strong>Reg #:</strong> ${c.registrationNumber}</p><p><strong>Type:</strong> ${c.businessType}</p><p><strong>Contact:</strong> ${c.contactPerson}</p><p><strong>Email:</strong> ${c.email}</p><button class="approve" onclick="approve('${c.id}')">Approve</button><button class="reject" onclick="reject('${c.id}')">Reject</button></div>`).join(''):'<p>No pending registrations</p>';document.getElementById('approvedRegistrations').innerHTML=approved.length?approved.map(c=>`<div class="company-card"><h3>${c.companyName}</h3><p><strong>Reg #:</strong> ${c.registrationNumber}</p><p><strong>Approved:</strong> ${new Date(c.approvedDate).toLocaleDateString()}</p></div>`).join(''):'<p>No approved registrations</p>'}catch(e){console.error(e)}}
async function approve(id){await fetch(`/api/admin/companies/${id}/approve`,{method:'PUT'});loadCompanies()}
async function reject(id){await fetch(`/api/admin/companies/${id}/reject`,{method:'PUT'});loadCompanies()}
loadCompanies();
</script></body></html>'''

if __name__ == '__main__':
    import threading
    
    # Run DB init in background so server starts immediately for health checks
    db_thread = threading.Thread(target=init_db)
    db_thread.daemon = True
    db_thread.start()

    with socketserver.TCPServer(("", PORT), AdminHandler) as httpd:
        print(f"Server running on port {PORT}")
        httpd.serve_forever()
