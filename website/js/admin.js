// Admin Login Functionality
class AdminAuth {
    constructor() {
        this.adminCredentials = {
            username: 'admin',
            password: 'admin123'  // Change this in production
        };
        this.init();
    }

    init() {
        const form = document.getElementById('loginForm');
        if (form) {
            form.addEventListener('submit', (e) => this.handleLogin(e));
        }
        
        // Check if already logged in
        if (localStorage.getItem('adminLoggedIn') === 'true') {
            window.location.href = 'dashboard.html';
        }
    }

    handleLogin(e) {
        e.preventDefault();
        
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        
        if (username === this.adminCredentials.username && 
            password === this.adminCredentials.password) {
            localStorage.setItem('adminLoggedIn', 'true');
            window.location.href = 'dashboard.html';
        } else {
            alert('Invalid credentials!');
        }
    }
}

// Initialize admin auth
new AdminAuth();