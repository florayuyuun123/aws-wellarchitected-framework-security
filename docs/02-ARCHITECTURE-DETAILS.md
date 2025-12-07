# Architecture Details

## Detailed Component Breakdown

### 1. Networking Layer

#### VPC Configuration
```hcl
CIDR Block: 10.0.0.0/16
DNS Hostnames: Enabled
DNS Support: Enabled
```

#### Subnet Strategy

**Public Subnets** (Internet-facing resources)
| Subnet | CIDR | AZ | Resources |
|--------|------|-----|-----------|
| public-1 | 10.0.1.0/24 | us-east-1a | Bastion Host, ALB |
| public-2 | 10.0.3.0/24 | us-east-1b | ALB |
| public-3 | 10.0.5.0/24 | us-east-1c | ALB |
| public-4 | 10.0.7.0/24 | us-east-1d | ALB |

**Private Subnets** (Internal resources)
| Subnet | CIDR | AZ | Resources |
|--------|------|-----|-----------|
| private-1 | 10.0.2.0/24 | us-east-1c | RDS |
| private-2 | 10.0.4.0/24 | us-east-1d | RDS |
| private-3 | 10.0.10.0/24 | us-east-1a | EC2 Backend |
| private-4 | 10.0.20.0/24 | us-east-1b | EC2 Backend |

#### Route Tables

**Public Route Table**
```
Destination: 0.0.0.0/0 → Internet Gateway
Destination: 10.0.0.0/16 → Local
```

**Private Route Table**
```
Destination: 10.0.0.0/16 → Local
VPC Endpoints for S3, EC2, RDS
```

#### Internet Gateway
- Attached to VPC
- Enables internet access for public subnets
- Used by ALB and Bastion Host

#### VPC Endpoints (Cost Optimization)
- **S3 Gateway Endpoint**: Free, private S3 access
- **EC2 Interface Endpoint**: Private EC2 API access
- **RDS Interface Endpoint**: Private RDS API access
- **Benefit**: Eliminates NAT Gateway (~$45/month savings)

---

### 2. Security Layer

#### Security Groups

**ALB Security Group** (`aws-sec-pillar-prod-alb-sg`)
```
Ingress:
  - Port 80 (HTTP) from 0.0.0.0/0
  - Port 443 (HTTPS) from 0.0.0.0/0

Egress:
  - All traffic to 0.0.0.0/0
```

**EC2 Security Group** (`aws-sec-pillar-prod-ec2-sg`)
```
Ingress:
  - Port 5000 (Flask) from ALB Security Group
  - Port 22 (SSH) from Bastion Security Group

Egress:
  - All traffic to 0.0.0.0/0
```

**Bastion Security Group** (`aws-sec-pillar-prod-bastion-sg`)
```
Ingress:
  - Port 22 (SSH) from 0.0.0.0/0
  ⚠️ Production: Restrict to your IP address

Egress:
  - All traffic to 0.0.0.0/0
```

**RDS Security Group** (`aws-sec-pillar-prod-rds-sg`)
```
Ingress:
  - Port 3306 (MySQL) from EC2 Security Group

Egress:
  - None (database doesn't initiate outbound connections)
```

#### AWS WAF Configuration

**Web ACL**: `aws-sec-pillar-prod-waf`

**Managed Rule Groups**:
1. **AWSManagedRulesCommonRuleSet**
   - Protection against common threats
   - OWASP Top 10 vulnerabilities
   - SQL injection, XSS, LFI, RFI

2. **AWSManagedRulesKnownBadInputsRuleSet**
   - Known malicious inputs
   - Exploit patterns

**Custom Rules**:
- **Rate Limiting**: 2000 requests per 5 minutes per IP
- **Action**: Block excessive requests

**Associated Resource**: Application Load Balancer

#### IAM Roles

**EC2 Instance Role** (`aws-sec-pillar-prod-ec2-ssm-role`)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Attached Policies**:
- `AmazonSSMManagedInstanceCore`: Systems Manager access

**Instance Profile**: `aws-sec-pillar-prod-ec2-profile`

---

### 3. Compute Layer

#### Application Load Balancer

**Configuration**:
```
Name: aws-sec-pillar-prod-alb
Type: Application Load Balancer
Scheme: Internet-facing
IP Address Type: IPv4
Subnets: All 4 public subnets
Security Group: aws-sec-pillar-prod-alb-sg
```

**Listener**:
```
Protocol: HTTP
Port: 80
Default Action: Forward to Target Group
```

**Target Group**:
```
Name: aws-sec-pillar-tg-{timestamp}
Protocol: HTTP
Port: 5000
Target Type: Instance
VPC: aws-sec-pillar-prod-vpc

Health Check:
  Protocol: HTTP
  Path: /health
  Port: 5000
  Healthy Threshold: 2
  Unhealthy Threshold: 3
  Timeout: 5 seconds
  Interval: 30 seconds
  Success Codes: 200
```

#### Auto Scaling Group

**Configuration**:
```
Name: aws-sec-pillar-prod-asg
Min Size: 1
Max Size: 3
Desired Capacity: 2
Health Check Type: ELB
Health Check Grace Period: 600 seconds (10 minutes)
Subnets: private-3, private-4
```

**Scaling Policy**: (Can be added)
```
Target Tracking:
  - CPU Utilization: 70%
  - Request Count per Target: 1000
```

#### Launch Template

**Configuration**:
```
Name: aws-sec-pillar-prod-{timestamp}
AMI: Ubuntu 22.04 LTS (latest)
Instance Type: t3.micro
Key Pair: argo-key-pair
Security Group: aws-sec-pillar-prod-ec2-sg
IAM Instance Profile: aws-sec-pillar-prod-ec2-profile
```

**User Data Script**: `scripts/setup-backend.sh`
```bash
#!/bin/bash
apt update -y
apt install -y python3 python3-pip

# Install SSM Agent
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Create Flask app
mkdir -p /opt/app
cd /opt/app

cat > app.py << 'PYTHON'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

@app.route('/api/companies/<company_id>')
def get_company(company_id):
    return jsonify({'id': company_id, 'status': 'active'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYTHON

pip3 install Flask==2.3.3

# Create systemd service
cat > /etc/systemd/system/flask-app.service << 'SERVICE'
[Unit]
Description=Flask Backend App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable flask-app
systemctl start flask-app
```

#### Bastion Host

**Configuration**:
```
Name: aws-sec-pillar-prod-bastion
AMI: Ubuntu 22.04 LTS
Instance Type: t3.micro
Key Pair: argo-key-pair
Subnet: public-1 (10.0.1.0/24)
Security Group: aws-sec-pillar-prod-bastion-sg
Public IP: Auto-assigned
```

**Purpose**:
- SSH jump server to access private instances
- Administrative access point
- Security audit logging

---

### 4. Database Layer

#### RDS MySQL Instance

**Configuration**:
```
Identifier: aws-sec-pillar-prod-db
Engine: MySQL 8.0
Instance Class: db.t3.micro
Storage: 20 GB (gp2)
Multi-AZ: Yes
Subnets: private-1, private-2
Security Group: aws-sec-pillar-prod-rds-sg
```

**Security**:
```
Encryption at Rest: Enabled
Backup Retention: 7 days
Automated Backups: Enabled
Public Access: Disabled
```

**DB Subnet Group**:
```
Name: aws-sec-pillar-prod-db-subnet-group
Subnets: private-1, private-2
```

**Credentials**:
- Username: admin
- Password: Stored in terraform.tfvars (⚠️ Use AWS Secrets Manager in production)

---

### 5. Storage Layer

#### S3 Bucket

**Configuration**:
```
Name: aws-sec-pillar-prod-{account-id}
Region: us-east-1
Versioning: Enabled
Encryption: SSE-S3 (AES-256)
```

**Website Hosting**:
```
Index Document: index.html
Error Document: error.html
Endpoint: http://aws-sec-pillar-prod-{account-id}.s3-website-us-east-1.amazonaws.com
```

**Bucket Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::aws-sec-pillar-prod-{account-id}/*"
    }
  ]
}
```

**CORS Configuration**:
```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": []
  }
]
```

---

### 6. Application Layer

#### Backend API (Flask)

**Endpoints**:

1. **Health Check**
```
GET /health
Response: {"status": "healthy"}
Status Code: 200
```

2. **Get Company**
```
GET /api/companies/<company_id>
Response: {"id": "<company_id>", "status": "active"}
Status Code: 200
```

**Service Configuration**:
```
Port: 5000
Host: 0.0.0.0
Process Manager: systemd
Auto-restart: Enabled
Restart Delay: 3 seconds
```

#### Frontend (Static Website)

**Structure**:
```
website/
├── index.html          # Main page
├── register.html       # Company registration
├── status.html         # Check registration status
├── admin.html          # Admin portal
├── css/
│   └── style.css       # Styling
└── js/
    ├── config.js       # API configuration
    ├── register.js     # Registration logic
    ├── status.js       # Status check logic
    └── admin.js        # Admin logic
```

**API Configuration** (`js/config.js`):
```javascript
const BASE_URL = 'http://ALB_DNS_PLACEHOLDER';
// Replaced during deployment with actual ALB DNS
```

---

## Data Flow

### User Request Flow

1. **User** → Accesses website via S3 URL
2. **S3** → Serves static HTML/CSS/JS
3. **Browser** → Makes API call to ALB DNS
4. **AWS WAF** → Inspects request, applies rules
5. **ALB** → Receives request on port 80
6. **Target Group** → Routes to healthy EC2 instance
7. **EC2** → Flask app processes request on port 5000
8. **RDS** → (If needed) Query database
9. **EC2** → Returns JSON response
10. **ALB** → Forwards response to browser
11. **Browser** → Displays data to user

### SSH Access Flow

1. **Admin** → SSH to Bastion Host (public IP)
2. **Bastion** → SSH to Private EC2 instance (private IP)
3. **Private EC2** → Administrative tasks

### Deployment Flow

1. **Developer** → Push code to GitHub
2. **GitHub Actions** → Triggered on push
3. **Workflow** → Syncs website files to S3
4. **Workflow** → Replaces ALB_DNS_PLACEHOLDER with actual ALB DNS
5. **S3** → Website updated and live

---

## Cost Breakdown (Monthly Estimate)

| Service | Configuration | Estimated Cost |
|---------|--------------|----------------|
| EC2 (2x t3.micro) | 730 hours/month | $15.00 |
| ALB | 730 hours + data | $20.00 |
| RDS (db.t3.micro) | Multi-AZ | $30.00 |
| S3 | 5GB storage + requests | $1.00 |
| VPC Endpoints | 3 endpoints | $21.60 |
| Data Transfer | 10GB/month | $0.90 |
| WAF | 1 Web ACL + rules | $6.00 |
| **Total** | | **~$94.50/month** |

**Cost Savings**:
- NAT Gateway avoided: **$45/month saved**
- Free tier eligible (first 12 months): **~$45/month saved**

---

**Next**: See [Deployment Guide](./03-DEPLOYMENT-GUIDE.md) for step-by-step instructions.
