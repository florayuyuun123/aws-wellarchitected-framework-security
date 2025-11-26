// Company Registration App
class CompanyRegistry {
    constructor() {
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

    async handleRegistration(e) {
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
            submittedDate: new Date().toISOString()
        };

        try {
            const response = await fetch(`${API_CONFIG.BASE_URL}${API_CONFIG.ENDPOINTS.REGISTER}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });

            const result = await response.json();
            
            if (result.success) {
                alert(`Registration submitted successfully! Your reference ID is: ${formData.id}`);
                document.getElementById('registrationForm').reset();
            } else {
                alert(`Error: ${result.error}`);
            }
        } catch (error) {
            // Fallback to localStorage if API is not available
            console.warn('API not available, using localStorage fallback');
            const companies = JSON.parse(localStorage.getItem('companies') || '[]');
            
            if (companies.find(c => c.registrationNumber === formData.registrationNumber)) {
                alert('Registration number already exists!');
                return;
            }
            
            formData.status = 'pending';
            formData.approvedDate = null;
            companies.push(formData);
            localStorage.setItem('companies', JSON.stringify(companies));
            
            alert(`Registration submitted successfully! Your reference ID is: ${formData.id}`);
            document.getElementById('registrationForm').reset();
        }
    }
}

// Initialize app
new CompanyRegistry();