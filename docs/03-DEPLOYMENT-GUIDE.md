# Deployment Guide

## Prerequisites

### 1. Required Tools

- **AWS CLI** (v2.x)
  ```bash
  # Install on Windows
  msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
  
  # Verify installation
  aws --version
  ```

- **Terraform** (v1.0+)
  ```bash
  # Install on Windows (using Chocolatey)
  choco install terraform
  
  # Verify installation
  terraform version
  ```

- **Git**
  ```bash
  # Install Git for Windows
  # Download from: https://git-scm.com/download/win
  
  # Verify installation
  git --version
  ```

- **SSH Client** (Git Bash or OpenSSH)
  ```bash
  # Comes with Git for Windows
  ssh -V
  ```

### 2. AWS Account Setup

1. **Create AWS Account**
   - Sign up at https://aws.amazon.com
   - Verify email and payment method

2. **Create IAM User**
   ```
   - Go to IAM Console
   - Create user: terraform-user
   - Attach policies:
     * AdministratorAccess (for demo)
     * Or custom policy with required permissions
   ```

3. **Generate Access Keys**
   ```
   - Select user → Security credentials
   - Create access key
   - Download credentials (keep secure!)
   ```

4. **Configure AWS CLI**
   ```bash
   aws configure
   # AWS Access Key ID: <your-access-key>
   # AWS Secret Access Key: <your-secret-key>
   # Default region: us-east-1
   # Default output format: json
   ```

5. **Verify Configuration**
   ```bash
   aws sts get-caller-identity
   ```

### 3. SSH Key Pair

1. **Generate SSH Key**
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/argo-key-pair
   # Press Enter for no passphrase (or set one)
   ```

2. **Import to AWS**
   ```bash
   aws ec2 import-key-pair \
     --key-name argo-key-pair \
     --public-key-material fileb://~/.ssh/argo-key-pair.pub \
     --region us-east-1
   ```

3. **Verify Key Pair**
   ```bash
   aws ec2 describe-key-pairs --key-names argo-key-pair
   ```

### 4. GitHub Repository Setup

1. **Fork or Clone Repository**
   ```bash
   git clone https://github.com/your-username/aws-wellarchitected-framework.git
   cd aws-wellarchitected-framework
   ```

2. **Configure GitHub Secrets**
   - Go to: Settings → Secrets and variables → Actions
   - Add secrets:
     * `AWS_ACCESS_KEY_ID`: Your AWS access key
     * `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

---

## Deployment Steps

### Step 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/your-username/aws-wellarchitected-framework.git
cd aws-wellarchitected-framework
```

### Step 2: Configure Variables

1. **Create `terraform.tfvars`**
   ```bash
   # Copy example file
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`**
   ```hcl
   # Project Configuration
   project_name = "aws-sec-pillar"
   environment  = "prod"
   aws_region   = "us-east-1"

   # Network Configuration
   vpc_cidr = "10.0.0.0/16"

   # Database Configuration
   db_username = "admin"
   db_password = "YourSecurePassword123!"  # Change this!
   db_name     = "companydb"

   # Compute Configuration
   instance_type = "t3.micro"
   key_name      = "argo-key-pair"

   # Auto Scaling Configuration
   min_size         = 1
   max_size         = 3
   desired_capacity = 2
   ```

3. **⚠️ Security Note**
   - Never commit `terraform.tfvars` to Git
   - Add to `.gitignore`
   - Use AWS Secrets Manager in production

### Step 3: Initialize Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init

# Expected output:
# Terraform has been successfully initialized!
```

### Step 4: Validate Configuration

```bash
# Validate Terraform syntax
terraform validate

# Expected output:
# Success! The configuration is valid.
```

### Step 5: Plan Deployment

```bash
# Preview changes
terraform plan

# Review output:
# - 39 resources to be created
# - No resources to be changed or destroyed
```

**Key Resources to Verify**:
- ✅ VPC and subnets
- ✅ Security groups
- ✅ ALB and target group
- ✅ Auto Scaling Group
- ✅ RDS instance
- ✅ S3 bucket
- ✅ WAF Web ACL

### Step 6: Deploy Infrastructure

```bash
# Apply configuration
terraform apply

# Type 'yes' when prompted
```

**Deployment Time**: ~10-15 minutes

**Progress Indicators**:
```
module.networking.aws_vpc.main: Creating...
module.networking.aws_subnet.public[0]: Creating...
module.security.aws_security_group.alb: Creating...
module.compute.aws_lb.main: Creating...
module.database.aws_db_instance.main: Creating... (this takes ~10 min)
...
Apply complete! Resources: 39 added, 0 changed, 0 destroyed.
```

### Step 7: Capture Outputs

```bash
# View outputs
terraform output

# Expected outputs:
# alb_dns_name = "aws-sec-pillar-prod-alb-XXXXXXXXX.us-east-1.elb.amazonaws.com"
# bastion_public_ip = "X.X.X.X"
# s3_bucket_name = "aws-sec-pillar-prod-XXXXXXXXXXXX"
# website_url = "http://aws-sec-pillar-prod-XXXXXXXXXXXX.s3-website-us-east-1.amazonaws.com"
# vpc_id = "vpc-XXXXXXXXXXXXXXXXX"
```

**Save these values** - you'll need them!

### Step 8: Deploy Website

#### Option A: Manual Deployment

```bash
# Navigate to website directory
cd website

# Sync to S3
aws s3 sync . s3://aws-sec-pillar-prod-XXXXXXXXXXXX/ --delete

# Update config.js with ALB DNS
ALB_DNS=$(terraform output -raw alb_dns_name)
sed -i "s|ALB_DNS_PLACEHOLDER|http://$ALB_DNS|g" js/config.js

# Upload updated config
aws s3 cp js/config.js s3://aws-sec-pillar-prod-XXXXXXXXXXXX/js/config.js
```

#### Option B: GitHub Actions (Automated)

```bash
# Push to GitHub
git add .
git commit -m "Deploy infrastructure"
git push origin main

# GitHub Actions will automatically:
# 1. Sync website files to S3
# 2. Replace ALB_DNS_PLACEHOLDER with actual DNS
# 3. Set correct content types
```

### Step 9: Verify Deployment

#### 1. Check Infrastructure

```bash
# Verify VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=aws-sec-pillar-prod-vpc"

# Verify EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=aws-sec-pillar-prod-instance" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]" \
  --output table

# Verify ALB
aws elbv2 describe-load-balancers \
  --names aws-sec-pillar-prod-alb

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

#### 2. Test Backend Health

```bash
# Get ALB DNS
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test health endpoint
curl http://$ALB_DNS/health

# Expected response:
# {"status":"healthy"}
```

#### 3. Test Website

```bash
# Get website URL
WEBSITE_URL=$(terraform output -raw website_url)

# Open in browser
start $WEBSITE_URL  # Windows
open $WEBSITE_URL   # macOS
xdg-open $WEBSITE_URL  # Linux
```

#### 4. Test SSH Access

```bash
# Get bastion IP
BASTION_IP=$(terraform output -raw bastion_public_ip)

# SSH to bastion
ssh -i ~/.ssh/argo-key-pair ubuntu@$BASTION_IP

# From bastion, SSH to private instance
ssh ubuntu@10.0.20.24  # Use actual private IP
```

---

## Post-Deployment Configuration

### 1. Restrict Bastion Access

```bash
# Get your public IP
MY_IP=$(curl -s ifconfig.me)

# Update bastion security group
aws ec2 authorize-security-group-ingress \
  --group-id $(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=aws-sec-pillar-prod-bastion-sg" \
    --query "SecurityGroups[0].GroupId" --output text) \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP/32

# Revoke 0.0.0.0/0 rule
aws ec2 revoke-security-group-ingress \
  --group-id $(aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=aws-sec-pillar-prod-bastion-sg" \
    --query "SecurityGroups[0].GroupId" --output text) \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

### 2. Enable CloudTrail (Optional)

```bash
# Create S3 bucket for logs
aws s3 mb s3://aws-sec-pillar-cloudtrail-logs-$(aws sts get-caller-identity --query Account --output text)

# Create trail
aws cloudtrail create-trail \
  --name aws-sec-pillar-trail \
  --s3-bucket-name aws-sec-pillar-cloudtrail-logs-$(aws sts get-caller-identity --query Account --output text)

# Start logging
aws cloudtrail start-logging --name aws-sec-pillar-trail
```

### 3. Enable GuardDuty (Optional)

```bash
# Enable GuardDuty
aws guardduty create-detector --enable
```

### 4. Set Up CloudWatch Alarms (Optional)

```bash
# Create SNS topic for alerts
aws sns create-topic --name aws-sec-pillar-alerts

# Subscribe to topic
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:aws-sec-pillar-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Create alarm for unhealthy targets
aws cloudwatch put-metric-alarm \
  --alarm-name aws-sec-pillar-unhealthy-targets \
  --alarm-description "Alert when targets are unhealthy" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:aws-sec-pillar-alerts
```

---

## Updating Infrastructure

### Update Terraform Configuration

```bash
# Make changes to .tf files
vim modules/compute/main.tf

# Plan changes
terraform plan

# Apply changes
terraform apply
```

### Update Website

```bash
# Make changes to website files
vim website/index.html

# Option 1: Manual sync
aws s3 sync website/ s3://$(terraform output -raw s3_bucket_name)/ --delete

# Option 2: Push to GitHub (triggers workflow)
git add website/
git commit -m "Update website"
git push origin main
```

### Update Backend Application

```bash
# SSH to instances via bastion
ssh -i ~/.ssh/argo-key-pair ubuntu@$BASTION_IP

# From bastion to private instance
ssh ubuntu@10.0.20.24

# Update Flask app
sudo vim /opt/app/app.py

# Restart service
sudo systemctl restart flask-app

# Check status
sudo systemctl status flask-app
```

---

## Destroying Infrastructure

### ⚠️ Warning
This will delete ALL resources and data. Make sure you have backups!

### Option 1: Terraform Destroy

```bash
# Destroy all resources
terraform destroy

# Type 'yes' when prompted
```

### Option 2: GitHub Actions Workflow

```bash
# Trigger destroy workflow
# Go to: Actions → Destroy Infrastructure → Run workflow
```

### Manual Cleanup (if needed)

```bash
# Empty S3 bucket first
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive

# Then destroy
terraform destroy
```

---

## Rollback Procedures

### Rollback Infrastructure Changes

```bash
# View Terraform state history
terraform state list

# Rollback to previous state
terraform state pull > backup.tfstate
terraform state push previous.tfstate

# Or use version control
git checkout HEAD~1 main.tf
terraform apply
```

### Rollback Website Changes

```bash
# List S3 versions
aws s3api list-object-versions \
  --bucket $(terraform output -raw s3_bucket_name) \
  --prefix index.html

# Restore previous version
aws s3api copy-object \
  --copy-source $(terraform output -raw s3_bucket_name)/index.html?versionId=VERSION_ID \
  --bucket $(terraform output -raw s3_bucket_name) \
  --key index.html
```

---

## Monitoring and Maintenance

### Daily Checks

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Check instance status
aws ec2 describe-instance-status \
  --filters "Name=tag:Name,Values=aws-sec-pillar-prod-instance"
```

### Weekly Checks

- Review CloudWatch metrics
- Check WAF blocked requests
- Review CloudTrail logs
- Verify backups

### Monthly Checks

- Review AWS bill
- Update AMIs
- Patch instances
- Review security groups

---

**Next**: See [Troubleshooting Guide](./04-TROUBLESHOOTING-GUIDE.md) for common issues and solutions.
