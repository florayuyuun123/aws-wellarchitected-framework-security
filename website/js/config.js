// API Configuration
const API_CONFIG = {
    // Replace with your ALB DNS name
    BASE_URL: 'http://aws-sec-pillar-prod-alb-2032155670.us-east-1.elb.amazonaws.com',
    ENDPOINTS: {
        REGISTER: '/api/companies',
        STATUS: '/api/companies',
        ADMIN_COMPANIES: '/api/admin/companies',
        APPROVE: '/api/admin/companies',
        REJECT: '/api/admin/companies'
    }
};