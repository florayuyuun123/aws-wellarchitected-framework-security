// Status Check Functionality
class StatusChecker {
    constructor() {
        this.companies = JSON.parse(localStorage.getItem('companies') || '[]');
        this.init();
    }

    init() {
        const form = document.getElementById('statusForm');
        if (form) {
            form.addEventListener('submit', (e) => this.checkStatus(e));
        }

        const downloadBtn = document.getElementById('downloadCert');
        if (downloadBtn) {
            downloadBtn.addEventListener('click', () => this.downloadCertificate());
        }
    }

    checkStatus(e) {
        e.preventDefault();
        
        const regNumber = document.getElementById('searchRegNumber').value;
        const company = this.companies.find(c => c.registrationNumber === regNumber);
        
        const resultDiv = document.getElementById('statusResult');
        
        if (!company) {
            alert('Registration number not found!');
            resultDiv.style.display = 'none';
            return;
        }

        // Display company information
        document.getElementById('statusCompanyName').textContent = company.companyName;
        document.getElementById('statusRegNumber').textContent = company.registrationNumber;
        document.getElementById('statusDate').textContent = new Date(company.submittedDate).toLocaleDateString();
        
        const statusSpan = document.getElementById('statusValue');
        statusSpan.textContent = company.status;
        statusSpan.className = `status-badge status-${company.status}`;
        
        // Show download button if approved
        const downloadDiv = document.getElementById('certificateDownload');
        if (company.status === 'approved') {
            downloadDiv.style.display = 'block';
            this.currentCompany = company;
        } else {
            downloadDiv.style.display = 'none';
        }
        
        resultDiv.style.display = 'block';
    }

    downloadCertificate() {
        if (!this.currentCompany) return;
        
        const certificate = this.generateCertificate(this.currentCompany);
        const blob = new Blob([certificate], { type: 'text/html' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = `Certificate_${this.currentCompany.registrationNumber}.html`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    generateCertificate(company) {
        return `
<!DOCTYPE html>
<html>
<head>
    <title>Certificate of Registration</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 40px; }
        .certificate { border: 3px solid #2c3e50; padding: 40px; text-align: center; }
        .header { color: #2c3e50; margin-bottom: 30px; }
        .title { font-size: 28px; font-weight: bold; margin-bottom: 20px; }
        .content { font-size: 16px; line-height: 1.8; margin: 20px 0; }
        .company-name { font-size: 24px; font-weight: bold; color: #3498db; margin: 20px 0; }
        .footer { margin-top: 40px; font-size: 14px; color: #666; }
        .seal { width: 100px; height: 100px; border: 2px solid #2c3e50; border-radius: 50%; 
                display: inline-block; line-height: 96px; margin: 20px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="certificate">
        <div class="header">
            <h1>CERTIFICATE OF REGISTRATION</h1>
        </div>
        
        <div class="content">
            <p>This is to certify that</p>
            <div class="company-name">${company.companyName}</div>
            <p>Registration Number: <strong>${company.registrationNumber}</strong></p>
            <p>Business Type: <strong>${company.businessType}</strong></p>
            <p>has been duly registered and is hereby authorized to operate as a business entity.</p>
        </div>
        
        <div class="footer">
            <div class="seal">OFFICIAL SEAL</div>
            <p>Date of Registration: ${new Date(company.approvedDate || company.submittedDate).toLocaleDateString()}</p>
            <p>This certificate is valid and legally binding.</p>
        </div>
    </div>
</body>
</html>`;
    }
}

// Initialize status checker
new StatusChecker();