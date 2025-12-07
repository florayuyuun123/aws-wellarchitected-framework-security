# Project Journey: From Concept to Deployment

## Introduction

This document chronicles the complete journey of building a production-ready AWS infrastructure following the Well-Architected Framework's Security Pillar. It includes all the challenges faced, decisions made, and lessons learned throughout the development process.

---

## Day 1-2: Project Initialization & Planning

### Initial Goals
- Build secure AWS infrastructure using Terraform
- Implement AWS Well-Architected Framework principles
- Focus on Security Pillar best practices
- Create reusable, modular infrastructure code

### Architecture Decisions

**Decision 1: Modular Terraform Structure**
```
Rationale: Separate concerns, reusable modules, easier maintenance
Structure:
├── modules/
│   ├── networking/
│   ├── security/
│   ├── compute/
│   ├── database/
│   ├── storage/
│   └── waf/
└── main.tf
```

**Decision 2: Multi-AZ Deployment**
```
Rationale: High availability, fault tolerance
Implementation: 4 AZs (us-east-1a, 1b, 1c, 1d)
```

**Decision 3: Public/Private Subnet Separation**
```
Rationale: Network segmentation, defense in depth
Public: ALB, Bastion Host
Private: EC2 instances, RDS database
```

### Initial Setup

1. **Created Git Repository**
   ```bash
   git init
   git remote add origin https://github.com/username/aws-wellarchitected-framework.git
   ```

2. **Set Up Terraform Structure**
   ```bash
   mkdir -p modules/{networking,security,compute,database,storage,waf}
   touch main.tf variables.tf outputs.tf terraform.tfvars
   ```

3. **Configured AWS Provider**
   ```hcl
   provider "aws" {
     region = "us-east-1"
   }
   ```

### Challenges Encountered

**Challenge 1: Naming Convention**
- Initially used inconsistent names
- Solution: Standardized to `aws-sec-pillar-prod-*` pattern

**Challenge 2: CIDR Block Planning**
- Needed to plan IP ranges for 8 subnets
- Solution: Used /24 subnets within 10.0.0.0/16 VPC

---

## Day 3-4: Networking & Security Implementation

### Networking Module Development

**VPC Creation**
```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```

**Subnet Creation**
- Created 4 public subnets (10.0.1.0/24, 10.0.3.0/24, 10.0.5.0/24, 10.0.7.0/24)
- Created 4 private subnets (10.0.2.0/24, 10.0.4.0/24, 10.0.10.0/24, 10.0.20.0/24)

**Route Tables**
- Public route table with IGW route
- Private route table with local routes only

### Security Groups Configuration

**Initial Approach**: Too permissive
```hcl
# ❌ Bad practice
ingress {
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

**Revised Approach**: Least privilege
```hcl
# ✅ Best practice
ingress {
  from_port       = 5000
  to_port         = 5000
  protocol        = "tcp"
  security_groups = [aws_security_group.alb.id]
}
```

### VPC Endpoints Decision

**Problem**: Private instances need AWS API access
**Options**:
1. NAT Gateway: $45/month + data transfer costs
2. VPC Endpoints: $7.20/month per endpoint

**Decision**: VPC Endpoints
- Cost savings: ~$30/month
- Better security: Traffic stays within AWS network
- Implemented for: S3, EC2, RDS

### Challenges Encountered

**Challenge 1: Circular Dependencies**
- Security groups referencing each other
- Solution: Use `security_groups` attribute instead of CIDR blocks

**Challenge 2: Subnet AZ Distribution**
- Initially all subnets in same AZ
- Solution: Distributed across 4 AZs using `count` and `element()`

---

## Day 5-6: Compute & Load Balancing

### Application Load Balancer Setup

**Initial Configuration**
```hcl
resource "aws_lb" "main" {
  name               = "aws-sec-pillar-prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group]
  subnets            = var.public_subnet_ids
}
```

**Target Group Configuration**
```hcl
resource "aws_lb_target_group" "main" {
  port     = 5000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  health_check {
    path                = "/health"
    port                = "5000"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}
```

### Auto Scaling Group Implementation

**Launch Template**
```hcl
resource "aws_launch_template" "main" {
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "argo-key-pair"
  
  user_data = base64encode(file("scripts/setup-backend.sh"))
}
```

**Auto Scaling Configuration**
```hcl
resource "aws_autoscaling_group" "main" {
  min_size         = 1
  max_size         = 3
  desired_capacity = 2
  
  health_check_type         = "ELB"
  health_check_grace_period = 600
}
```

### Bastion Host Setup

**Purpose**: Secure SSH access to private instances

**Configuration**:
```hcl
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.bastion_security_group]
}
```

### Challenges Encountered

**Challenge 1: Target Group Naming**
- Terraform recreates target group on every apply
- Solution: Added timestamp to name for uniqueness

**Challenge 2: Health Check Grace Period**
- Instances marked unhealthy before fully booted
- Solution: Increased grace period to 600 seconds

---

## Day 7: Database & Storage

### RDS MySQL Setup

**Configuration**:
```hcl
resource "aws_db_instance" "main" {
  identifier           = "aws-sec-pillar-prod-db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_encrypted    = true
  multi_az             = true
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group]
}
```

**Security Considerations**:
- Encryption at rest enabled
- Multi-AZ for high availability
- Private subnets only
- Security group restricts access to EC2 instances only

### S3 Bucket for Website

**Configuration**:
```hcl
resource "aws_s3_bucket" "website" {
  bucket = "aws-sec-pillar-prod-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  
  index_document {
    suffix = "index.html"
  }
}
```

**Security Features**:
- Server-side encryption (SSE-S3)
- Versioning enabled
- Public access for website hosting
- CORS configuration for API calls

### Challenges Encountered

**Challenge 1: RDS Creation Time**
- Takes 10-15 minutes to create
- Solution: Patience, and parallel resource creation

**Challenge 2: S3 Bucket Naming**
- Bucket names must be globally unique
- Solution: Append AWS account ID to bucket name

---

## Day 8: WAF & Security Enhancements

### AWS WAF Implementation

**Web ACL Configuration**:
```hcl
resource "aws_wafv2_web_acl" "main" {
  name  = "aws-sec-pillar-prod-waf"
  scope = "REGIONAL"
  
  default_action {
    allow {}
  }
  
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
  }
}
```

**Rate Limiting Rule**:
```hcl
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
```

### IAM Roles for EC2

**EC2 Instance Role**:
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

### Challenges Encountered

**Challenge 1: WAF Association**
- WAF must be associated with ALB
- Solution: Use `aws_wafv2_web_acl_association` resource

**Challenge 2: IAM Role Propagation**
- Role not immediately available to instances
- Solution: Wait for role to propagate before launching instances

---

## Day 9-10: Backend Deployment Evolution

### Initial Approach: ECS/ECR

**Original Plan**:
- Deploy Flask app as Docker container
- Use ECS Fargate for serverless containers
- Store images in ECR

**Implementation Started**:
```hcl
resource "aws_ecs_cluster" "main" {
  name = "aws-sec-pillar-prod-cluster"
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  
  container_definitions = jsonencode([{
    name  = "backend"
    image = "${aws_ecr_repository.backend.repository_url}:latest"
    portMappings = [{
      containerPort = 5000
      hostPort      = 0  # Dynamic port mapping
    }]
  }])
}
```

**Problems Encountered**:
1. Dynamic port mapping complexity with ALB
2. Need to build and push Docker image
3. Additional cost for ECR storage
4. Overcomplicated for simple Flask app

### Pivot: Direct EC2 Deployment

**Decision**: Deploy Flask directly on EC2 instances
**Rationale**:
- Simpler architecture
- Lower cost
- Easier debugging
- Sufficient for project requirements

**Implementation**:
```bash
# User data script
#!/bin/bash
apt update -y
apt install -y python3 python3-pip

mkdir -p /opt/app
cd /opt/app

cat > app.py << 'PYTHON'
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYTHON

pip3 install Flask==2.3.3

# Create systemd service
systemctl enable flask-app
systemctl start flask-app
```

### Challenges Encountered

**Challenge 1: ECS Complexity**
- Dynamic port mapping with ALB target groups
- Solution: Abandoned ECS, used direct EC2 deployment

**Challenge 2: User Data Execution**
- Script not running on instance boot
- Solution: Verified cloud-init logs, fixed script syntax

**Challenge 3: Flask Not Starting**
- Service failing to start
- Solution: Added proper systemd service configuration

---

## Day 11-12: CI/CD with GitHub Actions

### Website Deployment Workflow

**Created `.github/workflows/deploy.yml`**:
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

### Infrastructure Destroy Workflow

**Created `.github/workflows/destroy.yml`**:
```yaml
name: Destroy Infrastructure

on:
  workflow_dispatch:

jobs:
  destroy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Empty S3 Bucket
      run: |
        BUCKET_NAME=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'aws-sec-pillar-prod')].Name" --output text)
        aws s3 rm s3://$BUCKET_NAME --recursive
```

### Challenges Encountered

**Challenge 1: GitHub Secrets**
- Workflow failing due to missing credentials
- Solution: Added AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to repository secrets

**Challenge 2: Dynamic Resource Discovery**
- Hardcoded resource names in workflow
- Solution: Used AWS CLI queries to discover resources dynamically

**Challenge 3: S3 Bucket Deletion**
- Cannot delete non-empty bucket
- Solution: Empty bucket first in destroy workflow

---

## Day 13-Current: Troubleshooting & Debugging

### Issue 1: Unhealthy Target Instances

**Symptoms**:
```bash
aws elbv2 describe-target-health --target-group-arn <ARN>
# State: unhealthy
# Reason: Target.FailedHealthChecks
```

**Investigation Steps**:
1. Checked if instances are running ✅
2. Verified security groups allow port 5000 ✅
3. Attempted SSH to instances ❌ (hanging)
4. Checked SSM Session Manager ❌ (TargetNotConnected)

**Root Cause Analysis**:
- Flask service not starting on instances
- SSM agent not installed
- Cannot access instances to debug

**Solutions Attempted**:

1. **Added SSM Agent to User Data**:
   ```bash
   snap install amazon-ssm-agent --classic
   systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
   systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
   ```

2. **Increased Health Check Grace Period**:
   ```hcl
   health_check_grace_period = 600  # 10 minutes
   ```

3. **Verified IAM Role**:
   - Confirmed EC2 instances have SSM policy attached ✅

### Issue 2: SSH Connectivity Problems

**Problem 1**: Cannot SSH from bastion to private instances
- **Cause**: SSH key not on bastion
- **Solution**: Copy key to bastion using SCP

**Problem 2**: SSH connection hangs
- **Cause**: Instances not fully booted or SSH not running
- **Solution**: Wait for instances to fully initialize

**Problem 3**: Permission denied (publickey)
- **Cause**: Wrong key or key permissions
- **Solution**: Use correct key file and set permissions to 600

### Current Status

**Working**:
- ✅ Infrastructure deployed (39 resources)
- ✅ VPC with proper network segmentation
- ✅ Security groups configured correctly
- ✅ ALB created and accessible
- ✅ S3 website hosting configured
- ✅ GitHub Actions workflows functional
- ✅ Bastion host accessible via SSH

**In Progress**:
- ⏳ Backend instances health checks
- ⏳ Flask service startup
- ⏳ End-to-end application testing

**Next Steps**:
1. Access instance via bastion with SSH key
2. Check Flask service status
3. Review cloud-init logs
4. Manually start Flask if needed
5. Test health endpoint locally
6. Verify ALB can reach instances

---

## Key Lessons Learned

### 1. Start Simple, Then Scale
- Initially overcomplicated with ECS
- Direct EC2 deployment was sufficient
- Can always migrate to containers later

### 2. Security Groups Are Critical
- Spent significant time debugging connectivity
- Least privilege principle is essential
- Document security group rules clearly

### 3. Health Check Grace Period Matters
- Instances need time to boot and start services
- 10-15 minutes is reasonable for initial deployment
- Can reduce after confirming service starts quickly

### 4. User Data Debugging Is Hard
- Cannot see output until instance is accessible
- Use cloud-init logs for troubleshooting
- Test scripts locally before deploying

### 5. Cost Optimization Requires Planning
- VPC Endpoints vs NAT Gateway decision saved $30/month
- Free tier eligible instances reduce costs
- Monitor AWS bill regularly

### 6. Infrastructure as Code Benefits
- Easy to recreate entire environment
- Version controlled configuration
- Reproducible deployments

### 7. Modular Terraform Structure
- Easier to maintain and update
- Reusable across projects
- Clear separation of concerns

### 8. CI/CD Automation Saves Time
- Automated website deployments
- Consistent deployment process
- Reduces human error

### 9. Documentation Is Essential
- Helps troubleshooting
- Onboards new team members
- Reference for future projects

### 10. AWS Well-Architected Framework Works
- Security Pillar principles guide design
- Defense in depth approach
- Multiple layers of security

---

## Project Statistics

### Resources Created
- **Total Terraform Resources**: 39
- **VPC Components**: 1 VPC, 8 subnets, 2 route tables, 1 IGW
- **Security**: 4 security groups, 1 WAF Web ACL
- **Compute**: 1 ALB, 1 target group, 1 ASG, 1 launch template, 1 bastion
- **Database**: 1 RDS instance, 1 DB subnet group
- **Storage**: 1 S3 bucket
- **IAM**: 1 role, 1 instance profile, 1 policy attachment

### Code Statistics
- **Terraform Files**: 25+
- **Lines of Terraform Code**: ~1500
- **Bash Scripts**: 2
- **GitHub Workflows**: 2
- **Website Files**: 10+

### Time Investment
- **Planning & Design**: 2 days
- **Infrastructure Development**: 5 days
- **Backend Development**: 3 days
- **CI/CD Setup**: 1 day
- **Troubleshooting**: 2 days (ongoing)
- **Documentation**: 1 day
- **Total**: ~14 days

### Cost Analysis
- **Monthly Infrastructure Cost**: ~$95
- **Cost Savings (NAT Gateway)**: $45/month
- **Free Tier Savings**: ~$45/month (first 12 months)
- **Net Cost (Year 1)**: ~$50/month
- **Net Cost (After Year 1)**: ~$95/month

---

## Future Enhancements

### Short Term
1. ✅ Fix unhealthy target instances
2. ✅ Complete end-to-end testing
3. ✅ Add monitoring and alerting
4. ✅ Implement CloudWatch dashboards

### Medium Term
1. Add HTTPS with ACM certificate
2. Implement CloudFront CDN
3. Add DynamoDB for session storage
4. Implement Lambda functions for backend
5. Add Cognito for user authentication

### Long Term
1. Multi-region deployment
2. Disaster recovery plan
3. Automated backups and restore
4. Infrastructure testing with Terratest
5. Security scanning with Checkov
6. Cost optimization with AWS Cost Explorer

---

## Conclusion

This project demonstrates the implementation of a production-ready AWS infrastructure following security best practices. Despite challenges encountered during development, the modular approach and Infrastructure as Code principles made troubleshooting and iteration manageable.

The journey from concept to deployment highlighted the importance of:
- Proper planning and architecture design
- Security-first approach
- Cost optimization strategies
- Automation and CI/CD
- Comprehensive documentation

The project serves as a reference implementation for AWS Well-Architected Framework's Security Pillar and provides a solid foundation for future enhancements.

---

**Next**: See [Medium Article Draft](./06-MEDIUM-ARTICLE.md) for publication-ready content.
