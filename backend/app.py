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