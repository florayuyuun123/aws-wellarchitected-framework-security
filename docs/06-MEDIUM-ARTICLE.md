# Building a Secure AWS Infrastructure with Terraform: A Complete Guide

*Implementing AWS Well-Architected Framework's Security Pillar with Infrastructure as Code*

---

## Introduction

In today's cloud-first world, security isn't just a feature—it's a fundamental requirement. This article walks you through building a production-ready AWS infrastructure that implements the AWS Well-Architected Framework's Security Pillar using Terraform.

**What You'll Learn:**
- How to design secure, multi-tier AWS architecture
- Implementing defense-in-depth security strategies
- Cost optimization techniques (saving $45/month!)
- Infrastructure as Code best practices
- Troubleshooting real-world cloud issues

**Project Repository**: [GitHub Link]

---

## The Challenge

Many developers struggle with:
- ❌ Overly permissive security groups
- ❌ Expensive NAT Gateways ($45/month)
- ❌ Manual, error-prone deployments
- ❌ Lack of network segmentation
- ❌ Unencrypted data at rest

**Our Solution**: A fully automated, secure, cost-optimized AWS infrastructure deployed with Terraform.

---

## Architecture Overview

### High-Level Design

```
Internet
    ↓
AWS WAF (Protection Layer)
    ↓
Application Load Balancer (Public Subnets)
    ↓
EC2 Instances with Flask Backend (Private Subnets)
    ↓
RDS MySQL Database (Private Subnets)

S3 Bucket (Static Website) ← Users
```

### Key Components

1. **Network Layer**: VPC with 4 public and 4 private subnets across 4 Availability Zones
2. **Security Layer**: WAF, Security Groups, IAM Roles, Encryption
3. **Compute Layer**: Auto Scaling Group with Application Load Balancer
4. **Database Layer**: RDS MySQL with Multi-AZ deployment
5. **Storage Layer**: S3 with static website hosting
6. **Access Layer**: Bastion host for secure SSH access

---

## Part 1: Network Foundation

### VPC Design

The foundation of any secure AWS architecture is proper network segmentation. We created a VPC with clear separation between public and private resources.

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "aws-sec-pillar-prod-vpc"
  }
}
```

### Subnet Strategy

**Public Subnets** (Internet-facing):
- 10.0.1.0/24 (us-east-1a) - Bastion, ALB
- 10.0.3.0/24 (us-east-1b) - ALB
- 10.0.5.0/24 (us-east-1c) - ALB
- 10.0.7.0/24 (us-east-1d) - ALB

**Private Subnets** (Internal):
- 10.0.2.0/24 (us-east-1c) - RDS
- 10.0.4.0/24 (us-east-1d) - RDS
- 10.0.10.0/24 (us-east-1a) - EC2 Backend
- 10.0.20.0/24 (us-east-1b) - EC2 Backend

### Cost Optimization: VPC Endpoints vs NAT Gateway

**Traditional Approach**: NAT Gateway
- Cost: $45/month + data transfer
- Purpose: Allow private instances to access internet

**Our Approach**: VPC Endpoints
- Cost: $7.20/month per endpoint
- Savings: ~$30/month
- Benefits: Better security, lower latency

```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
  
  route_table_ids = [aws_route_table.private.id]
}
```

**💡 Key Takeaway**: VPC Endpoints provide private connectivity to AWS services without internet access, saving costs and improving security.

---

## Part 2: Security Implementation

### Defense in Depth Strategy

We implemented multiple layers of security:

#### Layer 1: AWS WAF (Web Application Firewall)

```hcl
resource "aws_wafv2_web_acl" "main" {
  name  = "aws-sec-pillar-prod-waf"
  scope = "REGIONAL"

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
  }
  
  rule {
    name     = "RateLimitRule"
    priority = 2
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
  }
}
```

**Protection Against**:
- SQL Injection
- Cross-Site Scripting (XSS)
- DDoS attacks (rate limiting)
- Known malicious inputs

#### Layer 2: Security Groups (Least Privilege)

**ALB Security Group**:
```hcl
resource "aws_security_group" "alb" {
  name_prefix = "aws-sec-pillar-prod-alb"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**EC2 Security Group** (Restrictive):
```hcl
resource "aws_security_group" "ec2" {
  name_prefix = "aws-sec-pillar-prod-ec2"
  vpc_id      = var.vpc_id

  # Only allow traffic from ALB
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Only allow SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
}
```

**💡 Key Takeaway**: Never use 0.0.0.0/0 for internal resources. Always reference security groups for inter-service communication.

#### Layer 3: Encryption at Rest

**RDS Encryption**:
```hcl
resource "aws_db_instance" "main" {
  identifier        = "aws-sec-pillar-prod-db"
  engine            = "mysql"
  storage_encrypted = true  # ✅ Encryption enabled
  
  # ... other configuration
}
```

**S3 Encryption**:
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

#### Layer 4: IAM Roles (No Hardcoded Credentials)

```hcl
resource "aws_iam_role" "ec2_ssm_role" {
  name = "aws-sec-pillar-prod-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

**💡 Key Takeaway**: Use IAM roles for EC2 instances instead of storing AWS credentials on instances.

---

## Part 3: Compute & Auto Scaling

### Application Load Balancer

```hcl
resource "aws_lb" "main" {
  name               = "aws-sec-pillar-prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "main" {
  port     = 5000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "5000"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }
}
```

### Auto Scaling Group

```hcl
resource "aws_autoscaling_group" "main" {
  name                = "aws-sec-pillar-prod-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.main.arn]
  
  min_size         = 1
  max_size         = 3
  desired_capacity = 2

  health_check_type         = "ELB"
  health_check_grace_period = 600

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
}
```

### Backend Application Deployment

Initially, I planned to use ECS/ECR for containerized deployment. However, I pivoted to direct EC2 deployment for simplicity.

**User Data Script** (`scripts/setup-backend.sh`):
```bash
#!/bin/bash
apt update -y
apt install -y python3 python3-pip

# Install SSM Agent for remote access
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# Create Flask application
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

**💡 Key Takeaway**: Start simple. You can always migrate to containers later. Direct EC2 deployment is easier to debug and sufficient for many use cases.

---

## Part 4: Database & Storage

### RDS MySQL with Multi-AZ

```hcl
resource "aws_db_instance" "main" {
  identifier           = "aws-sec-pillar-prod-db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_encrypted    = true
  
  multi_az             = true  # High availability
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group]
  
  backup_retention_period = 7
  skip_final_snapshot     = false
  final_snapshot_identifier = "aws-sec-pillar-final-snapshot"
}
```

**Benefits**:
- ✅ Automatic failover
- ✅ Encrypted at rest
- ✅ Automated backups
- ✅ Private subnet only

### S3 Static Website Hosting

```hcl
resource "aws_s3_bucket" "website" {
  bucket = "aws-sec-pillar-prod-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

---

## Part 5: CI/CD with GitHub Actions

### Automated Website Deployment

`.github/workflows/deploy.yml`:
```yaml
name: Deploy Website

on:
  push:
    branches: [ main ]
    paths:
      - 'website/**'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Discover AWS Resources
      run: |
        BUCKET_NAME=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'aws-sec-pillar-prod')].Name" --output text)
        echo "BUCKET_NAME=$BUCKET_NAME" >> $GITHUB_ENV
        
        ALB_DNS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'aws-sec-pillar-prod')].DNSName" --output text)
        echo "ALB_DNS=$ALB_DNS" >> $GITHUB_ENV
    
    - name: Update Config with ALB DNS
      run: |
        sed -i "s|ALB_DNS_PLACEHOLDER|http://$ALB_DNS|g" website/js/config.js
    
    - name: Deploy Website
      run: |
        aws s3 sync website/ s3://$BUCKET_NAME/ --delete
```

**💡 Key Takeaway**: Automate everything. Manual deployments are error-prone and time-consuming.

---

## Part 6: Real-World Challenges & Solutions

### Challenge 1: Unhealthy Target Instances

**Problem**: ALB health checks failing, instances marked unhealthy.

**Investigation**:
```bash
aws elbv2 describe-target-health --target-group-arn <ARN>
# Output: "State": "unhealthy", "Reason": "Target.FailedHealthChecks"
```

**Root Causes**:
1. Flask service not starting
2. Health check grace period too short
3. Security group misconfiguration

**Solutions**:
1. Increased health check grace period to 600 seconds
2. Added proper systemd service configuration
3. Verified security groups allow port 5000 from ALB

### Challenge 2: SSH Connectivity Issues

**Problem**: Cannot SSH from bastion to private instances.

**Root Cause**: SSH key not present on bastion host.

**Solution**:
```bash
# Copy SSH key to bastion
scp -i ~/.ssh/argo-key-pair ~/.ssh/argo-key-pair ubuntu@<BASTION_IP>:~/

# On bastion
chmod 600 ~/argo-key-pair
ssh -i ~/argo-key-pair ubuntu@<PRIVATE_IP>
```

### Challenge 3: SSM Session Manager Not Working

**Problem**: `aws ssm start-session` returns "TargetNotConnected"

**Root Cause**: SSM agent not installed on instances.

**Solution**: Added SSM agent installation to user data script:
```bash
snap install amazon-ssm-agent --classic
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
```

**💡 Key Takeaway**: Always include SSM agent in your AMI or user data for easier troubleshooting.

---

## Part 7: Cost Analysis

### Monthly Cost Breakdown

| Service | Configuration | Cost |
|---------|--------------|------|
| EC2 (2x t3.micro) | 730 hours/month | $15.00 |
| ALB | 730 hours + data | $20.00 |
| RDS (db.t3.micro) | Multi-AZ | $30.00 |
| S3 | 5GB storage | $1.00 |
| VPC Endpoints | 3 endpoints | $21.60 |
| Data Transfer | 10GB/month | $0.90 |
| WAF | 1 Web ACL | $6.00 |
| **Total** | | **$94.50/month** |

### Cost Savings

- **NAT Gateway avoided**: $45/month saved
- **Free tier (Year 1)**: ~$45/month saved
- **Net cost (Year 1)**: ~$50/month
- **Net cost (After Year 1)**: ~$95/month

**💡 Key Takeaway**: VPC Endpoints save significant costs compared to NAT Gateway while improving security.

---

## Part 8: Deployment Guide

### Prerequisites

1. AWS Account with appropriate permissions
2. Terraform >= 1.0 installed
3. AWS CLI configured
4. SSH key pair generated

### Step-by-Step Deployment

**1. Clone Repository**
```bash
git clone https://github.com/your-username/aws-wellarchitected-framework.git
cd aws-wellarchitected-framework
```

**2. Configure Variables**
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**3. Initialize Terraform**
```bash
terraform init
```

**4. Plan Deployment**
```bash
terraform plan
# Review: 39 resources to be created
```

**5. Deploy Infrastructure**
```bash
terraform apply
# Type 'yes' when prompted
# Wait 10-15 minutes for deployment
```

**6. Capture Outputs**
```bash
terraform output
# Save ALB DNS, S3 bucket name, bastion IP
```

**7. Deploy Website**
```bash
# Push to GitHub (triggers workflow)
git add .
git commit -m "Deploy infrastructure"
git push origin main
```

**8. Verify Deployment**
```bash
# Test backend health
curl http://<ALB_DNS>/health

# Access website
open http://<S3_BUCKET>.s3-website-us-east-1.amazonaws.com
```

---

## Part 9: Best Practices & Lessons Learned

### 1. Security Best Practices

✅ **DO**:
- Use security groups with least privilege
- Enable encryption at rest for all data
- Implement WAF for web applications
- Use IAM roles instead of access keys
- Enable Multi-AZ for databases
- Implement network segmentation

❌ **DON'T**:
- Use 0.0.0.0/0 for internal resources
- Store credentials in code
- Deploy everything in public subnets
- Skip encryption
- Ignore security group rules

### 2. Cost Optimization

✅ **DO**:
- Use VPC Endpoints instead of NAT Gateway
- Choose appropriate instance sizes
- Enable Auto Scaling
- Use free tier eligible resources
- Monitor AWS bill regularly

❌ **DON'T**:
- Over-provision resources
- Leave unused resources running
- Ignore cost optimization opportunities

### 3. Infrastructure as Code

✅ **DO**:
- Use modular Terraform structure
- Version control all configuration
- Use variables for flexibility
- Document your code
- Test before deploying to production

❌ **DON'T**:
- Hardcode values
- Make manual changes in console
- Skip planning step
- Ignore Terraform state

### 4. Troubleshooting

✅ **DO**:
- Enable detailed logging
- Use SSM Session Manager
- Check cloud-init logs
- Verify security groups
- Test connectivity step by step

❌ **DON'T**:
- Assume everything works
- Skip health checks
- Ignore error messages
- Make multiple changes at once

---

## Conclusion

Building secure AWS infrastructure requires careful planning, implementation of best practices, and continuous monitoring. This project demonstrates:

✅ **Security**: Multi-layered defense with WAF, security groups, encryption
✅ **Cost Optimization**: $45/month savings with VPC Endpoints
✅ **Automation**: Infrastructure as Code with Terraform
✅ **High Availability**: Multi-AZ deployment with Auto Scaling
✅ **Best Practices**: AWS Well-Architected Framework principles

### Key Takeaways

1. **Start with security**: Design security into your architecture from day one
2. **Automate everything**: Use IaC and CI/CD for consistency
3. **Optimize costs**: VPC Endpoints can save significant money
4. **Keep it simple**: Don't overcomplicate (learned from ECS pivot)
5. **Document thoroughly**: Future you will thank present you

### Next Steps

- Add HTTPS with ACM certificate
- Implement CloudFront CDN
- Add monitoring with CloudWatch
- Set up automated backups
- Implement disaster recovery

### Resources

- **GitHub Repository**: [Link to your repo]
- **AWS Well-Architected Framework**: https://aws.amazon.com/architecture/well-architected/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws

---

## About the Author

[Your bio and links]

---

**Found this helpful? Give it a clap 👏 and follow for more cloud architecture content!**

**Questions? Drop them in the comments below! 💬**

---

## Tags

#AWS #Terraform #CloudArchitecture #DevOps #InfrastructureAsCode #Security #CloudSecurity #WellArchitectedFramework #CostOptimization #CICD #GitHubActions #Python #Flask #CloudComputing #TechBlog
