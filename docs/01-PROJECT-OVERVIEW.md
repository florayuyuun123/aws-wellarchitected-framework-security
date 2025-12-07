# AWS Well-Architected Framework: Secure Infrastructure with Terraform

## Project Overview

This project demonstrates the implementation of a production-ready, secure AWS infrastructure following the AWS Well-Architected Framework principles, specifically focusing on the **Security Pillar**. The infrastructure is deployed using Infrastructure as Code (IaC) with Terraform and includes automated CI/CD pipelines via GitHub Actions.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Key Features](#key-features)
4. [Technology Stack](#technology-stack)
5. [Project Goals](#project-goals)

---

## Architecture

### High-Level Architecture

```
Internet
    ↓
AWS WAF (Web Application Firewall)
    ↓
Application Load Balancer (Public Subnets)
    ↓
EC2 Instances with Flask Backend (Private Subnets)
    ↓
RDS MySQL Database (Private Subnets)

S3 Bucket (Static Website Hosting)
    ↓
CloudFront (Optional CDN)

Bastion Host (Public Subnet) → SSH Access to Private Instances
```

### Network Architecture

- **VPC**: Custom VPC with CIDR `10.0.0.0/16`
- **Public Subnets**: 4 subnets across 4 Availability Zones (us-east-1a, 1b, 1c, 1d)
  - `10.0.1.0/24` (us-east-1a)
  - `10.0.3.0/24` (us-east-1b)
  - `10.0.5.0/24` (us-east-1c)
  - `10.0.7.0/24` (us-east-1d)
- **Private Subnets**: 4 subnets across 4 Availability Zones
  - `10.0.2.0/24` (us-east-1c)
  - `10.0.4.0/24` (us-east-1d)
  - `10.0.10.0/24` (us-east-1a)
  - `10.0.20.0/24` (us-east-1b)

---

## Key Features

### 1. Security Features

✅ **Network Segmentation**
- Public/private subnet isolation
- Multi-AZ deployment for high availability
- No direct internet access to private resources

✅ **VPC Endpoints**
- Private connectivity to AWS services (S3, EC2, RDS)
- Eliminates need for NAT Gateway (cost optimization)

✅ **Encryption at Rest**
- RDS MySQL with encryption enabled
- S3 bucket with server-side encryption
- EBS volumes encrypted

✅ **Web Application Firewall (WAF)**
- AWS Managed Rules for common threats
- Rate limiting to prevent DDoS attacks
- SQL injection and XSS protection

✅ **Security Groups (Least Privilege)**
- ALB: Allows HTTP (80) and HTTPS (443) from internet
- EC2: Allows port 5000 from ALB only, SSH from bastion only
- Bastion: Allows SSH (22) from internet (restrict to your IP in production)
- RDS: Allows MySQL (3306) from EC2 instances only

✅ **IAM Roles and Policies**
- EC2 instances use IAM roles (no hardcoded credentials)
- SSM access for secure instance management
- Principle of least privilege applied

✅ **Bastion Host**
- Secure jump server for SSH access to private instances
- Single point of entry for administrative access

### 2. Compute Features

- **Auto Scaling Group**: 2 EC2 instances (t3.micro) with automatic scaling
- **Application Load Balancer**: Distributes traffic across instances
- **Health Checks**: ALB monitors instance health on `/health` endpoint
- **Flask Backend**: Python Flask API running on port 5000

### 3. Database Features

- **RDS MySQL**: Managed database in private subnets
- **Multi-AZ**: High availability with automatic failover
- **Automated Backups**: Point-in-time recovery
- **Encryption**: Data encrypted at rest

### 4. Storage Features

- **S3 Static Website Hosting**: Frontend hosted on S3
- **Versioning**: Enabled for disaster recovery
- **Encryption**: Server-side encryption (SSE-S3)
- **Public Access Block**: Configured for security

### 5. CI/CD Features

- **GitHub Actions**: Automated deployment workflows
- **Infrastructure Deployment**: Terraform apply on push
- **Website Deployment**: Automatic sync to S3
- **Destroy Workflow**: Clean up resources when needed

---

## Technology Stack

### Infrastructure as Code
- **Terraform**: v1.0+
- **AWS Provider**: Latest version

### Cloud Services (AWS)
- **Compute**: EC2, Auto Scaling, Application Load Balancer
- **Networking**: VPC, Subnets, Route Tables, Internet Gateway, VPC Endpoints
- **Security**: Security Groups, WAF, IAM Roles
- **Database**: RDS MySQL
- **Storage**: S3
- **Monitoring**: CloudWatch (implicit)

### Backend
- **Language**: Python 3
- **Framework**: Flask 2.3.3
- **Server**: Systemd service

### Frontend
- **HTML5/CSS3/JavaScript**
- **Bootstrap**: Responsive design
- **Hosted on**: S3 Static Website

### DevOps
- **CI/CD**: GitHub Actions
- **Version Control**: Git/GitHub
- **SSH Key Management**: AWS Key Pairs

---

## Project Goals

### Primary Goals

1. **Demonstrate AWS Security Best Practices**
   - Implement defense in depth
   - Follow principle of least privilege
   - Encrypt data at rest and in transit

2. **Infrastructure as Code**
   - Reproducible infrastructure
   - Version-controlled configuration
   - Modular and reusable Terraform code

3. **Cost Optimization**
   - Use VPC Endpoints instead of NAT Gateway (~$45/month savings)
   - Free tier eligible instances (t3.micro)
   - Auto Scaling for efficient resource utilization

4. **High Availability**
   - Multi-AZ deployment
   - Auto Scaling Group with health checks
   - Load balancing across instances

5. **Automation**
   - Automated deployment via GitHub Actions
   - Infrastructure provisioning with Terraform
   - Continuous deployment for website updates

### Learning Objectives

- Master Terraform for AWS infrastructure
- Understand AWS networking and security
- Implement CI/CD pipelines
- Deploy production-ready applications
- Troubleshoot cloud infrastructure issues

---

## Project Naming Convention

All resources follow the naming pattern: `aws-sec-pillar-prod-*`

- **Project Name**: `aws-sec-pillar`
- **Environment**: `prod`
- **Examples**:
  - VPC: `aws-sec-pillar-prod-vpc`
  - ALB: `aws-sec-pillar-prod-alb`
  - S3 Bucket: `aws-sec-pillar-prod-{account-id}`
  - Security Groups: `aws-sec-pillar-prod-alb-sg`, `aws-sec-pillar-prod-ec2-sg`

---

## Project Timeline

### Phase 1: Initial Setup (Day 1-2)
- Created Terraform modules structure
- Configured VPC with public/private subnets
- Set up security groups

### Phase 2: Compute & Database (Day 3-4)
- Deployed EC2 instances with Auto Scaling
- Configured Application Load Balancer
- Set up RDS MySQL database

### Phase 3: Storage & Frontend (Day 5)
- Created S3 bucket for static website
- Deployed frontend application
- Configured S3 website hosting

### Phase 4: Security Enhancements (Day 6)
- Added AWS WAF with managed rules
- Implemented VPC Endpoints
- Configured bastion host

### Phase 5: Backend Deployment (Day 7-8)
- Initially attempted ECS/ECR deployment
- Pivoted to direct EC2 deployment
- Created Flask backend with systemd service

### Phase 6: CI/CD & Automation (Day 9)
- Set up GitHub Actions workflows
- Automated website deployment
- Configured infrastructure destroy workflow

### Phase 7: Troubleshooting (Day 10-Current)
- Debugging unhealthy target instances
- Fixing SSH connectivity issues
- Resolving Flask service startup problems

---

## Success Metrics

- ✅ Infrastructure deployed successfully (39 resources)
- ✅ VPC with proper network segmentation
- ✅ Security groups configured correctly
- ✅ S3 website accessible
- ✅ GitHub Actions workflows functional
- ⏳ Backend instances healthy (in progress)
- ⏳ End-to-end application functional (in progress)

---

**Next Steps**: See [Architecture Details](./02-ARCHITECTURE-DETAILS.md) for in-depth technical specifications.
