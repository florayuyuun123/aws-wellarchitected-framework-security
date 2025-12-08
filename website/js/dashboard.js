// Admin Dashboard Functionality
class AdminDashboard {
    constructor() {
        this.companies = [];
        this.init();
    }

    init() {
        // Check if admin is logged in
        if (localStorage.getItem('adminLoggedIn') !== 'true') {
            window.location.href = 'login.html';
            return;
        }
        
        this.loadRegistrations();
    }

    async loadRegistrations() {
        try {
            const response = await fetch(`${API_CONFIG.BASE_URL}/api/admin/companies`);
            const data = await response.json();
            this.companies = data.companies || [];
        } catch (error) {
            console.warn('API not available, using localStorage fallback');
            this.companies = JSON.parse(localStorage.getItem('companies') || '[]');
        }
        
        const pendingDiv = document.getElementById('pendingRegistrations');
        const approvedDiv = document.getElementById('approvedRegistrations');
        
        const pending = this.companies.filter(c => c.status === 'pending');
        const approved = this.companies.filter(c => c.status === 'approved');
        
        pendingDiv.innerHTML = pending.length ? 
            pending.map(c => this.createRegistrationCard(c, true)).join('') :
            '<p>No pending registrations</p>';
            
        approvedDiv.innerHTML = approved.length ?
            approved.map(c => this.createRegistrationCard(c, false)).join('') :
            '<p>No approved registrations</p>';
    }

    createRegistrationCard(company, showActions) {
        return `
            <div class="registration-item">
                <h3>${company.companyName}</h3>
                <p><strong>Registration Number:</strong> ${company.registrationNumber}</p>
                <p><strong>Business Type:</strong> ${company.businessType}</p>
                <p><strong>Contact:</strong> ${company.contactPerson} (${company.email})</p>
                <p><strong>Phone:</strong> ${company.phone}</p>
                <p><strong>Address:</strong> ${company.address}</p>
                <p><strong>Submitted:</strong> ${new Date(company.submittedDate).toLocaleDateString()}</p>
                ${showActions ? `
                    <div class="registration-actions">
                        <button class="approve-btn" onclick="dashboard.approveRegistration('${company.id}')">
                            Approve
                        </button>
                        <button class="reject-btn" onclick="dashboard.rejectRegistration('${company.id}')">
                            Reject
                        </button>
                    </div>
                ` : `
                    <p><strong>Approved:</strong> ${new Date(company.approvedDate).toLocaleDateString()}</p>
                `}
            </div>
        `;
    }

    async approveRegistration(id) {
        const company = this.companies.find(c => c.id === id);
        if (company) {
            try {
                const response = await fetch(`${API_CONFIG.BASE_URL}/api/admin/companies/${id}/approve`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' }
                });
                if (response.ok) {
                    alert(`${company.companyName} has been approved!`);
                    this.loadRegistrations();
                } else {
                    alert('Failed to approve registration');
                }
            } catch (error) {
                console.warn('API not available, using localStorage fallback');
                company.status = 'approved';
                company.approvedDate = new Date().toISOString();
                localStorage.setItem('companies', JSON.stringify(this.companies));
                this.loadRegistrations();
                alert(`${company.companyName} has been approved!`);
            }
        }
    }

    async rejectRegistration(id) {
        const company = this.companies.find(c => c.id === id);
        if (company && confirm(`Are you sure you want to reject ${company.companyName}?`)) {
            try {
                const response = await fetch(`${API_CONFIG.BASE_URL}/api/admin/companies/${id}/reject`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' }
                });
                if (response.ok) {
                    alert(`${company.companyName} has been rejected!`);
                    this.loadRegistrations();
                } else {
                    alert('Failed to reject registration');
                }
            } catch (error) {
                console.warn('API not available, using localStorage fallback');
                company.status = 'rejected';
                localStorage.setItem('companies', JSON.stringify(this.companies));
                this.loadRegistrations();
                alert(`${company.companyName} has been rejected!`);
            }
        }
    }
}

// Global functions for button clicks
function logout() {
    localStorage.removeItem('adminLoggedIn');
    window.location.href = 'login.html';
}

// Initialize dashboard
const dashboard = new AdminDashboard();