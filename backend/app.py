from flask import Flask, request, jsonify
from flask_cors import CORS
import pymysql
import json
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Database configuration
DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'user': os.environ.get('DB_USER', 'admin'),
    'password': os.environ.get('DB_PASSWORD', 'changeme123!'),
    'database': os.environ.get('DB_NAME', 'appdb'),
    'charset': 'utf8mb4'
}

def get_db_connection():
    return pymysql.connect(**DB_CONFIG)

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})

@app.route('/api/companies', methods=['POST'])
def register_company():
    try:
        data = request.json
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Insert company registration
        query = """
        INSERT INTO companies (id, company_name, registration_number, business_type, 
                             address, contact_person, email, phone, status, submitted_date)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        cursor.execute(query, (
            data['id'], data['companyName'], data['registrationNumber'],
            data['businessType'], data['address'], data['contactPerson'],
            data['email'], data['phone'], 'pending', data['submittedDate']
        ))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Company registered successfully'})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/companies/<registration_number>', methods=['GET'])
def get_company_status(registration_number):
    try:
        conn = get_db_connection()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        query = "SELECT * FROM companies WHERE registration_number = %s"
        cursor.execute(query, (registration_number,))
        company = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if company:
            return jsonify({'success': True, 'company': company})
        else:
            return jsonify({'success': False, 'error': 'Company not found'}), 404
            
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/admin/companies', methods=['GET'])
def get_all_companies():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        query = "SELECT * FROM companies ORDER BY submitted_date DESC"
        cursor.execute(query)
        companies = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'companies': companies})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/admin/companies/<company_id>/approve', methods=['PUT'])
def approve_company(company_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        query = "UPDATE companies SET status = 'approved', approved_date = %s WHERE id = %s"
        cursor.execute(query, (datetime.now(), company_id))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Company approved'})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/admin/companies/<company_id>/reject', methods=['PUT'])
def reject_company(company_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        query = "UPDATE companies SET status = 'rejected' WHERE id = %s"
        cursor.execute(query, (company_id,))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({'success': True, 'message': 'Company rejected'})
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=False)