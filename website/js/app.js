// Company Registration App
class CompanyRegistry {
    constructor() {
        this.companies = JSON.parse(localStorage.getItem('companies') || '[]');
        this.init();
    }

    init() {
        const form = document.getElementById('registrationForm');
        if (form) {
            form.addEventListener('submit', (e) => this.handleRegistration(e));
        }
    }

    generateId() {
        return 'REG-' + Date.now() + '-' + Math.random().toString(36).substr(2, 5).toUpperCase();
    }

    handleRegistration(e) {
        e.preventDefault();
        
        const formData = {
            id: this.generateId(),
            companyName: document.getElementById('companyName').value,
            registrationNumber: document.getElementById('registrationNumber').value,
            businessType: document.getElementById('businessType').value,
            address: document.getElementById('address').value,
            contactPerson: document.getElementById('contactPerson').value,
            email: document.getElementById('email').value,
            phone: document.getElementById('phone').value,
            status: 'pending',
            submittedDate: new Date().toISOString(),
            approvedDate: null
        };

        // Check if registration number already exists
        if (this.companies.find(c => c.registrationNumber === formData.registrationNumber)) {
            alert('Registration number already exists!');
            return;
        }

        this.companies.push(formData);
        localStorage.setItem('companies', JSON.stringify(this.companies));
        
        alert(`Registration submitted successfully! Your reference ID is: ${formData.id}`);
        document.getElementById('registrationForm').reset();
    }
}

// Initialize app
new CompanyRegistry();