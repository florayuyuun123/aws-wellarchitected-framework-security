#!/bin/bash
apt update -y
apt install -y python3 python3-pip

# Create backend app
mkdir -p /opt/app
cd /opt/app

cat > app.py << 'PYTHON'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

@app.route('/api/companies/<company_id>')
def get_company(company_id):
    return jsonify({'id': company_id, 'status': 'active'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYTHON

pip3 install Flask==2.3.3
nohup python3 app.py &