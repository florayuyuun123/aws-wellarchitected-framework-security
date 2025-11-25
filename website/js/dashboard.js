// Admin Dashboard Functionality
class AdminDashboard {
    constructor() {
        this.companies = JSON.parse(localStorage.getItem('companies') || '[]');
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

    loadRegistrations() {
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

    approveRegistration(id) {
        const company = this.companies.find(c => c.id === id);
        if (company) {
            company.status = 'approved';
            company.approvedDate = new Date().toISOString();
            localStorage.setItem('companies', JSON.stringify(this.companies));
            this.loadRegistrations();
            alert(`${company.companyName} has been approved!`);
        }
    }

    rejectRegistration(id) {
        const company = this.companies.find(c => c.id === id);
        if (company && confirm(`Are you sure you want to reject ${company.companyName}?`)) {
            company.status = 'rejected';
            localStorage.setItem('companies', JSON.stringify(this.companies));
            this.loadRegistrations();
            alert(`${company.companyName} has been rejected!`);
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