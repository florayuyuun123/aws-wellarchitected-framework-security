#!/bin/bash

# Manual Flask deployment script
# Run this to deploy Flask app to instances

BASTION_IP="44.211.238.14"
PRIVATE_IPS="10.0.20.26 10.0.10.51"

echo "🚀 Starting manual Flask deployment..."

# Create Flask app script
cat > flask_app.py << 'EOF'
from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime

app = Flask(__name__)
CORS(app)

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'message': 'Company Registration API is running'
    })

@app.route('/api/companies', methods=['POST'])
def register_company():
    return jsonify({'message': 'Company registered', 'reg_number': 'REG001'})

@app.route('/api/companies/<reg_number>')
def get_company(reg_number):
    return jsonify({'reg_number': reg_number, 'status': 'pending'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Create deployment script
cat > deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "Installing dependencies..."
sudo apt update -y
sudo apt install -y python3 python3-pip

echo "Creating app directory..."
sudo mkdir -p /opt/app
cd /opt/app

echo "Installing Flask..."
sudo pip3 install Flask Flask-CORS

echo "Stopping existing Flask processes..."
sudo pkill -f "python3.*app.py" || true
sleep 2

echo "Starting Flask app..."
sudo nohup python3 /opt/app/app.py > /opt/app/app.log 2>&1 &
sleep 5

echo "Testing Flask app..."
curl -f http://localhost:5000/health && echo "✅ SUCCESS!" || echo "❌ FAILED!"
EOF

chmod +x deploy.sh

echo "📁 Files created. Now deploying to instances..."

for private_ip in $PRIVATE_IPS; do
    echo "🎯 Deploying to $private_ip..."
    
    # Copy files to bastion
    scp -i ~/.ssh/argo-key-pair.pem -o StrictHostKeyChecking=no flask_app.py deploy.sh ubuntu@$BASTION_IP:/tmp/
    
    # Deploy via bastion to private instance
    ssh -i ~/.ssh/argo-key-pair.pem -o StrictHostKeyChecking=no ubuntu@$BASTION_IP "
        echo 'Copying files to $private_ip...'
        scp -i ~/.ssh/argo-key-pair.pem -o StrictHostKeyChecking=no /tmp/flask_app.py /tmp/deploy.sh ubuntu@$private_ip:/tmp/
        
        echo 'Deploying Flask app on $private_ip...'
        ssh -i ~/.ssh/argo-key-pair.pem -o StrictHostKeyChecking=no ubuntu@$private_ip '
            sudo cp /tmp/flask_app.py /opt/app/app.py 2>/dev/null || sudo mkdir -p /opt/app && sudo cp /tmp/flask_app.py /opt/app/app.py
            chmod +x /tmp/deploy.sh
            /tmp/deploy.sh
        '
    "
    
    echo "✅ Deployment to $private_ip completed"
done

echo "⏳ Waiting 30 seconds for health checks..."
sleep 30

echo "🧪 Testing ALB endpoint..."
curl -f http://aws-sec-pillar-prod-alb-1626309480.us-east-1.elb.amazonaws.com/health && echo "🎉 SUCCESS! ALB is working!" || echo "❌ ALB still not working"

echo "🏁 Manual deployment completed!"