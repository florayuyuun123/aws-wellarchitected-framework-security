#!/bin/bash
apt update -y
apt install -y python3 python3-pip awscli

# Install SSM Agent
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Wait for bastion to generate and upload SSH key
sleep 60

# Retrieve bastion public key from SSM and add to authorized_keys
BAST_PUB_KEY=$(aws ssm get-parameter --name "/aws-sec-pillar/bastion-public-key" --query "Parameter.Value" --output text --region us-east-1 2>/dev/null)
if [ -n "$BAST_PUB_KEY" ]; then
  echo "$BAST_PUB_KEY" >> /home/ubuntu/.ssh/authorized_keys
  chmod 600 /home/ubuntu/.ssh/authorized_keys
  chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
fi

# Create backend app structure
mkdir -p /opt/app/templates/admin
mkdir -p /opt/app/static/{css,js}
cd /opt/app

# Install Flask
pip3 install Flask==2.3.3

# Create Flask app with admin routes
cat > app.py << 'PYTHON'
from flask import Flask, jsonify, render_template, request, session, redirect, url_for
import os

app = Flask(__name__)
app.secret_key = os.urandom(24)

# Health check
@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

# API endpoints
@app.route('/api/companies/<company_id>')
def get_company(company_id):
    return jsonify({'id': company_id, 'status': 'active'})

# Admin login
@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        
        if username == 'admin' and password == 'admin123':
            session['admin'] = True
            session['username'] = username
            return jsonify({'success': True})
        return jsonify({'success': False, 'error': 'Invalid credentials'}), 401
    
    return render_template('admin/login.html')

# Admin dashboard
@app.route('/admin/dashboard')
def admin_dashboard():
    if 'admin' not in session:
        return redirect(url_for('admin_login'))
    return render_template('admin/dashboard.html')

# Admin logout
@app.route('/admin/logout')
def admin_logout():
    session.pop('admin', None)
    session.pop('username', None)
    return redirect(url_for('admin_login'))

# Check session
@app.route('/admin/check-session')
def check_session():
    return jsonify({'authenticated': 'admin' in session})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYTHON

# Create admin login template
cat > templates/admin/login.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Login</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f4f4f4; padding: 20px; }
        .container { max-width: 400px; margin: 100px auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { text-align: center; color: #333; margin-bottom: 30px; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; color: #555; }
        input { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; }
        button { width: 100%; padding: 12px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
        button:hover { background: #0056b3; }
        .error { color: red; margin-top: 10px; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Admin Login</h1>
        <form id="loginForm">
            <div class="form-group">
                <label for="username">Username</label>
                <input type="text" id="username" required>
            </div>
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" required>
            </div>
            <button type="submit">Login</button>
            <div id="error" class="error"></div>
        </form>
    </div>
    <script>
        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            
            try {
                const response = await fetch('/admin/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ username, password })
                });
                
                const result = await response.json();
                if (result.success) {
                    window.location.href = '/admin/dashboard';
                } else {
                    document.getElementById('error').textContent = 'Invalid credentials';
                }
            } catch (error) {
                document.getElementById('error').textContent = 'Login failed';
            }
        });
    </script>
</body>
</html>
HTML

# Create admin dashboard template
cat > templates/admin/dashboard.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f4f4f4; }
        header { background: #007bff; color: white; padding: 20px; display: flex; justify-content: space-between; align-items: center; }
        header h1 { font-size: 24px; }
        header a { color: white; text-decoration: none; padding: 8px 16px; background: rgba(255,255,255,0.2); border-radius: 4px; }
        header a:hover { background: rgba(255,255,255,0.3); }
        .container { max-width: 1200px; margin: 30px auto; padding: 0 20px; }
        .dashboard { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h2 { color: #333; margin-bottom: 20px; }
        .registrations-list { margin-bottom: 40px; }
        .company-card { background: #f9f9f9; padding: 15px; margin-bottom: 10px; border-radius: 4px; border-left: 4px solid #007bff; }
        .company-card h3 { color: #333; margin-bottom: 10px; }
        .company-card p { color: #666; margin: 5px 0; }
    </style>
</head>
<body>
    <header>
        <h1>Admin Dashboard</h1>
        <a href="/admin/logout">Logout</a>
    </header>
    <div class="container">
        <div class="dashboard">
            <h2>Pending Registrations</h2>
            <div id="pendingRegistrations" class="registrations-list">
                <p>No pending registrations</p>
            </div>
            <h2>Approved Registrations</h2>
            <div id="approvedRegistrations" class="registrations-list">
                <p>No approved registrations</p>
            </div>
        </div>
    </div>
</body>
</html>
HTML

# Create systemd service
cat > /etc/systemd/system/flask-app.service << 'SERVICE'
[Unit]
Description=Flask Backend App
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
systemctl enable flask-app
systemctl start flask-app
