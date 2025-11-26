// API Configuration
const API_CONFIG = {
    // Replace with your ALB DNS name
    BASE_URL: 'http://YOUR_ALB_DNS_NAME',
    ENDPOINTS: {
        REGISTER: '/api/companies',
        STATUS: '/api/companies',
        ADMIN_COMPANIES: '/api/admin/companies',
        APPROVE: '/api/admin/companies',
        REJECT: '/api/admin/companies'
    }
};