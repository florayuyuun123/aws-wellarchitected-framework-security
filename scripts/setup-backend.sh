#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script at $(date)"

# Install packages that are available in the base AMI
apt update -y || echo "Package update failed, using cached packages"
apt install -y python3 python3-pip awscli curl || echo "Some packages may not be available"

# Install SSM Agent (usually pre-installed in Ubuntu AMIs)
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || echo "SSM agent may already be configured"
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || echo "SSM agent may already be running"

# Wait for bastion to generate and upload SSH key with retry logic
echo "Waiting for bastion key generation..."
for i in {1..10}; do
  echo "Attempt $i: Retrieving bastion public key..."
  BAST_PUB_KEY=$(aws ssm get-parameter --name "/aws-sec-pillar/bastion-public-key" --query "Parameter.Value" --output text --region us-east-1 2>/dev/null)
  if [ -n "$BAST_PUB_KEY" ] && [ "$BAST_PUB_KEY" != "None" ]; then
    echo "$BAST_PUB_KEY" >> /home/ubuntu/.ssh/authorized_keys
    chmod 600 /home/ubuntu/.ssh/authorized_keys
    chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
    echo "Bastion key added successfully"
    break
  else
    echo "Key not ready, waiting 30 seconds..."
    sleep 30
  fi
done

# Create backend app
echo "Creating Flask application..."
mkdir -p /opt/app
cd /opt/app

cat > app.py << 'PYTHON'
import http.server
import socketserver
import json
from datetime import datetime

# In-memory storage
companies = []

class APIHandler(http.server.BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
    
    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()
    
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self._send_cors_headers()
            self.end_headers()
            response = json.dumps({'status': 'healthy'})
            self.wfile.write(response.encode())
        elif self.path == '/api/companies':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self._send_cors_headers()
            self.end_headers()
            response = json.dumps({'companies': companies})
            self.wfile.write(response.encode())
        elif self.path.startswith('/api/companies/') and len(self.path.split('/')) == 4:
            reg_number = self.path.split('/')[-1]
            company = next((c for c in companies if c['registrationNumber'] == reg_number), None)
            self.send_response(200 if company else 404)
            self.send_header('Content-type', 'application/json')
            self._send_cors_headers()
            self.end_headers()
            response = json.dumps(company if company else {'error': 'Not found'})
            self.wfile.write(response.encode())
        elif self.path == '/api/admin/companies':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self._send_cors_headers()
            self.end_headers()
            response = json.dumps({'companies': companies})
            self.wfile.write(response.encode())
        else:
            self.send_response(404)
            self._send_cors_headers()
            self.end_headers()
    
    def do_POST(self):
        if self.path == '/api/companies':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            try:
                company_data = json.loads(post_data.decode('utf-8'))
                company_data['status'] = 'pending'
                companies.append(company_data)
                self.send_response(201)
                self.send_header('Content-type', 'application/json')
                self._send_cors_headers()
                self.end_headers()
                response = json.dumps({'success': True, 'id': company_data['id']})
                self.wfile.write(response.encode())
            except:
                self.send_response(400)
                self._send_cors_headers()
                self.end_headers()
        else:
            self.send_response(404)
            self._send_cors_headers()
            self.end_headers()
    
    def do_PUT(self):
        if '/approve' in self.path:
            company_id = self.path.split('/')[-2]
            company = next((c for c in companies if c['id'] == company_id), None)
            if company:
                company['status'] = 'approved'
                company['approvedDate'] = datetime.now().isoformat()
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self._send_cors_headers()
            self.end_headers()
            response = json.dumps({'success': True})
            self.wfile.write(response.encode())
        elif '/reject' in self.path:
            company_id = self.path.split('/')[-2]
            company = next((c for c in companies if c['id'] == company_id), None)
            if company:
                company['status'] = 'rejected'
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self._send_cors_headers()
            self.end_headers()
            response = json.dumps({'success': True})
            self.wfile.write(response.encode())
        else:
            self.send_response(404)
            self._send_cors_headers()
            self.end_headers()
    
    def log_message(self, format, *args):
        print(f"{datetime.now().isoformat()} - {format % args}")

if __name__ == '__main__':
    PORT = 5000
    with socketserver.TCPServer(("", PORT), APIHandler) as httpd:
        print(f"Starting API server on port {PORT}")
        httpd.serve_forever()
PYTHON

echo "Python HTTP server created (no external dependencies needed)"

# Create systemd service for Python HTTP server
echo "Creating systemd service..."
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
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start the service
echo "Starting backend service..."
systemctl daemon-reload
systemctl enable backend-app
systemctl start backend-app

# Wait a moment and check service status
sleep 5
systemctl status backend-app --no-pager

# Test the health endpoint locally
echo "Testing health endpoint..."
sleep 10
curl -f http://localhost:5000/health || echo "Health check failed"

echo "User data script completed at $(date)"