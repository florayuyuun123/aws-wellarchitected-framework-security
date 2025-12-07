#!/bin/bash

echo "=== Fixing 502 Bad Gateway Error ==="
echo "This script will help diagnose and fix the ALB 502 error"
echo

# The most common issue is that instances aren't healthy
# Let's create an improved user data script

echo "Creating improved backend setup script..."

cat > scripts/setup-backend-fixed.sh << 'EOF'
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting IMPROVED user data script at $(date)"

# Update system
apt update -y
apt install -y python3 python3-pip awscli curl net-tools

# Install SSM Agent
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Wait for bastion to generate and upload SSH key
echo "Waiting for bastion key generation..."
sleep 60

# Retrieve bastion public key from SSM and add to authorized_keys
echo "Retrieving bastion public key..."
BAST_PUB_KEY=$(aws ssm get-parameter --name "/aws-sec-pillar/bastion-public-key" --query "Parameter.Value" --output text --region us-east-1 2>/dev/null)
if [ -n "$BAST_PUB_KEY" ]; then
  echo "$BAST_PUB_KEY" >> /home/ubuntu/.ssh/authorized_keys
  chmod 600 /home/ubuntu/.ssh/authorized_keys
  chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
  echo "Bastion key added successfully"
else
  echo "Warning: Could not retrieve bastion key"
fi

# Create backend app directory
echo "Creating Flask application..."
mkdir -p /opt/app
cd /opt/app

# Create improved Flask app with better error handling
cat > app.py << 'PYTHON'
from flask import Flask, jsonify, request
import logging
import sys
import os

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/flask-app.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

app = Flask(__name__)
logger = logging.getLogger(__name__)

@app.route('/health')
def health():
    logger.info('Health check requested from %s', request.remote_addr)
    return jsonify({
        'status': 'healthy',
        'message': 'Flask app is running',
        'timestamp': str(os.popen('date').read().strip())
    }), 200

@app.route('/api/companies/<company_id>')
def get_company(company_id):
    logger.info('Company lookup for ID: %s from %s', company_id, request.remote_addr)
    return jsonify({
        'id': company_id, 
        'status': 'active',
        'message': 'Company found'
    }), 200

@app.route('/api/test')
def test():
    logger.info('Test endpoint accessed from %s', request.remote_addr)
    return jsonify({
        'message': 'Test endpoint working',
        'status': 'success'
    }), 200

@app.errorhandler(404)
def not_found(error):
    logger.warning('404 error for path: %s from %s', request.path, request.remote_addr)
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error('500 error: %s from %s', str(error), request.remote_addr)
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    logger.info('Starting Flask app on 0.0.0.0:5000')
    app.run(host='0.0.0.0', port=5000, debug=False)
PYTHON

# Install Flask with specific version
echo "Installing Flask..."
pip3 install Flask==2.3.3 Werkzeug==2.3.7

# Test Flask installation
echo "Testing Flask installation..."
python3 -c "import flask; print('Flask version:', flask.__version__)"

# Create improved systemd service
echo "Creating systemd service..."
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
RestartSec=5
Environment=PYTHONUNBUFFERED=1
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start the service
echo "Starting Flask service..."
systemctl daemon-reload
systemctl enable flask-app
systemctl start flask-app

# Wait and check service status
sleep 10
echo "=== Service Status ==="
systemctl status flask-app --no-pager

# Test the health endpoint locally multiple times
echo "=== Testing Health Endpoint Locally ==="
for i in {1..5}; do
    echo "Test $i:"
    curl -f http://localhost:5000/health 2>/dev/null && echo " - SUCCESS" || echo " - FAILED"
    sleep 2
done

# Check if port 5000 is listening
echo "=== Port Status ==="
netstat -tlnp | grep :5000 || echo "Port 5000 not listening!"

# Show recent logs
echo "=== Recent Flask Logs ==="
tail -20 /var/log/flask-app.log 2>/dev/null || echo "No Flask logs found"

echo "User data script completed at $(date)"
EOF

echo "Improved setup script created at: scripts/setup-backend-fixed.sh"
echo

echo "=== Manual Fix Steps ==="
echo "1. The instances need to be recreated with the improved script"
echo "2. You can either:"
echo "   a) Update the launch template and refresh the ASG"
echo "   b) Or manually fix the existing instances via SSH"
echo
echo "=== Option A: Update Launch Template (Recommended) ==="
echo "1. Copy the improved script to replace the current one:"
echo "   cp scripts/setup-backend-fixed.sh scripts/setup-backend.sh"
echo "2. Run: terraform apply"
echo "3. Trigger instance refresh in ASG"
echo
echo "=== Option B: Manual Fix via SSH ==="
echo "1. SSH to bastion: ssh -i ~/.ssh/argo-key-pair.pem ubuntu@35.175.108.88"
echo "2. From bastion, find private instance IPs and SSH to them"
echo "3. Check Flask service: sudo systemctl status flask-app"
echo "4. Check logs: sudo journalctl -u flask-app -f"
echo "5. Restart if needed: sudo systemctl restart flask-app"
echo
echo "=== Quick Test Commands for SSH Session ==="
echo "# Check if Flask is running"
echo "curl http://localhost:5000/health"
echo
echo "# Check service status"
echo "sudo systemctl status flask-app"
echo
echo "# View logs"
echo "sudo tail -f /var/log/user-data.log"
echo "sudo journalctl -u flask-app -f"