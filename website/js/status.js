// Status Check Functionality
class StatusChecker {
    constructor() {
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

    async checkStatus(e) {
        e.preventDefault();

        const regNumber = document.getElementById('searchRegNumber').value.trim();
        const resultDiv = document.getElementById('statusResult');

        try {
            const response = await fetch(`${API_CONFIG.BASE_URL}/api/companies/${regNumber}`);

            if (!response.ok) {
                alert('Registration not found!');
                resultDiv.style.display = 'none';
                return;
            }

            const company = await response.json();

            // Display company information
            document.getElementById('statusCompanyName').textContent = company.companyName;
            document.getElementById('statusRegNumber').textContent = company.registrationNumber;
            document.getElementById('statusDate').textContent = new Date(company.submittedDate).toLocaleDateString();

            const statusSpan = document.getElementById('statusValue');
            statusSpan.textContent = company.status.toUpperCase();
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
        } catch (error) {
            console.error('Error checking status:', error);
            alert('Error checking status. Please try again.');
            resultDiv.style.display = 'none';
        }
    }

    downloadCertificate() {
        if (!this.currentCompany) return;

        // Open the PDF generation endpoint in a new tab/window which triggers download
        window.open(`${API_CONFIG.BASE_URL}/api/companies/${this.currentCompany.id}/certificate`, '_blank');
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