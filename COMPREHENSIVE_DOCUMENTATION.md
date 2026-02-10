# AWS Well-Architected Secure Infrastructure with ECS/ECR
## Comprehensive Technical Documentation

### Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture Design](#architecture-design)
3. [Security Implementation](#security-implementation)
4. [ECS/ECR Container Strategy](#ecsecr-container-strategy)
5. [Infrastructure Components](#infrastructure-components)
6. [Deployment Process](#deployment-process)
7. [Monitoring & Operations](#monitoring--operations)
8. [Security Best Practices](#security-best-practices)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [Cost Optimization](#cost-optimization)

---

## Project Overview

### Mission Statement
Build a secure, well-architected AWS infrastructure for a Company Registration Portal that prioritizes the **Security Pillar** of the AWS Well-Architected Framework while maintaining high availability and operational excellence.

### Key Requirements
- **Zero Internet Access** for backend resources (air-gapped architecture)
- **Strict Network Isolation** with VPC endpoints
- **Containerized Application** deployment using ECS
- **Encrypted Data** at rest and in transit
- **Least Privilege Access** controls
- **High Availability** across multiple AZs
- **Automated CI/CD** pipeline

### Architecture Principles
1. **Security First**: Every design decision prioritizes security
2. **Immutable Infrastructure**: Container-based deployments
3. **Defense in Depth**: Multiple layers of security controls
4. **Zero Trust Network**: No implicit trust, verify everything
5. **Automated Operations**: Infrastructure as Code (IaC)

---

## Architecture Design

### High-Level Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 AWS WAF                                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Application Load Balancer                      │
│                 (Public Subnets)                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                ECS Cluster                                  │
│            (Private Subnets)                               │
│  ┌─────────────────┐    ┌─────────────────┐               │
│  │   ECS Task 1    │    │   ECS Task 2    │               │
│  │  (Container)    │    │  (Container)    │               │
│  └─────────────────┘    └─────────────────┘               │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 RDS MySQL                                   │
│              (Private Subnets)                             │
└─────────────────────────────────────────────────────────────┘
```

### Network Architecture
- **VPC**: Custom VPC with CIDR 10.0.0.0/16
- **Public Subnets**: 2 subnets across 2 AZs for ALB
- **Private Subnets**: 2 subnets across 2 AZs for ECS and RDS
- **VPC Endpoints**: Private connectivity to AWS services
- **No NAT Gateway**: Complete air-gap for private resources

### Container Architecture
- **ECR Repository**: Private Docker image registry
- **ECS Cluster**: EC2 launch type for cost optimization
- **ECS Service**: Manages desired container count and health
- **Task Definition**: Defines container specifications and environment

---

## Security Implementation

### Network Security
1. **VPC Isolation**
   - Custom VPC with private/public subnet separation
   - No internet gateway access for private subnets
   - Security groups with least privilege rules

2. **VPC Endpoints**
   ```hcl
   # S3 Gateway Endpoint
   resource "aws_vpc_endpoint" "s3" {
     vpc_id       = aws_vpc.main.id
     service_name = "com.amazonaws.us-east-1.s3"
   }
   
   # ECR Interface Endpoints
   resource "aws_vpc_endpoint" "ecr_dkr" {
     vpc_id              = aws_vpc.main.id
     service_name        = "com.amazonaws.us-east-1.ecr.dkr"
     vpc_endpoint_type   = "Interface"
   }
   ```

3. **Security Groups**
   - ALB: Allows HTTP/HTTPS from internet
   - ECS: Allows traffic only from ALB
   - RDS: Allows MySQL only from ECS
   - Bastion: SSH access (restricted to admin IPs)

### Identity and Access Management
1. **ECS Task Execution Role**
   ```hcl
   resource "aws_iam_role" "ecs_execution_role" {
     name = "ecs-execution-role"
     assume_role_policy = jsonencode({
       Version = "2012-10-17"
       Statement = [{
         Action = "sts:AssumeRole"
         Effect = "Allow"
         Principal = {
           Service = "ecs-tasks.amazonaws.com"
         }
       }]
     })
   }
   ```

2. **EC2 Instance Role**
   - ECS agent permissions
   - SSM access for management
   - ECR pull permissions

### Data Protection
1. **Encryption at Rest**
   - RDS: AES-256 encryption
   - S3: Server-side encryption
   - EBS: Encrypted volumes

2. **Encryption in Transit**
   - HTTPS/TLS for all communications
   - RDS SSL connections
   - VPC endpoint encryption

### Application Security
1. **Container Security**
   - Minimal base image (Python 3.9-slim)
   - Non-root user execution
   - Image vulnerability scanning

2. **Session Management**
   - Server-side session storage
   - Secure HTTP-only cookies
   - Session timeout controls

---

## ECS/ECR Container Strategy

### Container Design Philosophy
The shift to containers was driven by security requirements:
- **Immutable Infrastructure**: No runtime modifications
- **Dependency Control**: All dependencies baked into image
- **Consistent Deployments**: Same image across environments
- **Security Scanning**: Automated vulnerability detection

### Docker Implementation
```dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]
```

### ECR Repository Configuration
```hcl
resource "aws_ecr_repository" "main" {
  name                 = "aws-sec-pillar-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}
```

### ECS Task Definition
```hcl
resource "aws_ecs_task_definition" "main" {
  family                   = "backend-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = 256
  memory                   = 256
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  
  container_definitions = jsonencode([{
    name  = "backend"
    image = "${var.container_image}"
    cpu   = 256
    memory = 256
    essential = true
    portMappings = [{
      containerPort = 5000
      hostPort      = 0
      protocol      = "tcp"
    }]
    environment = [
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_USER", value = "admin" },
      { name = "DB_PASS", value = "changeme123!" },
      { name = "DB_NAME", value = "appdb" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/backend"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])
}
```

### ECS Service Configuration
```hcl
resource "aws_ecs_service" "main" {
  name            = "backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 2
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  
  health_check_grace_period_seconds  = 60

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "backend"
    container_port   = 5000
  }
}
```

---

## Infrastructure Components

### Terraform Module Structure
```
modules/
├── vpc/           # Network infrastructure
├── security/      # Security groups and rules
├── ecr/          # Container registry
├── ecs/          # Container orchestration
├── alb/          # Load balancer
├── compute/      # EC2 instances for ECS
├── database/     # RDS MySQL
├── storage/      # S3 bucket
└── waf/          # Web Application Firewall
```

### Key Resources

#### VPC Module
- VPC with public/private subnets
- Internet Gateway for public subnets
- Route tables and associations
- VPC endpoints for AWS services

#### Security Module
- Security groups for each tier
- NACLs for additional protection
- IAM roles and policies

#### ECS Module
- ECS cluster configuration
- Task definitions
- Service definitions
- CloudWatch log groups

#### Database Module
- RDS MySQL instance
- Subnet groups
- Parameter groups
- Backup configuration

---

## Deployment Process

### Infrastructure Deployment
1. **Prerequisites**
   ```bash
   # Install Terraform
   # Configure AWS CLI
   # Create SSH key pair
   ```

2. **Deploy Infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

### Application Deployment (CI/CD)

#### Backend Deployment Pipeline
```yaml
name: Deploy Backend to Amazon ECS

on:
  push:
    branches: [main]
    paths: ['backend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1

    - name: Login to Amazon ECR
      uses: aws-actions/amazon-ecr-login@v2

    - name: Build and push image
      run: |
        cd backend
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$GITHUB_SHA .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$GITHUB_SHA
        docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$GITHUB_SHA $ECR_REGISTRY/$ECR_REPOSITORY:latest
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

    - name: Deploy to ECS
      run: |
        aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment
```

#### Website Deployment Pipeline
```yaml
name: Deploy Website

on:
  push:
    branches: [main]
    paths: ['website/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Deploy to S3
      run: |
        aws s3 sync website/ s3://$BUCKET_NAME/ --delete
```

### Deployment Verification
```bash
# Check ECS service status
aws ecs describe-services --cluster $CLUSTER --services $SERVICE

# Check target group health
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# Test application endpoints
curl http://$ALB_DNS/health
curl http://$ALB_DNS/admin/login
```

---

## Monitoring & Operations

### CloudWatch Integration
1. **Container Logs**
   - All container output sent to CloudWatch Logs
   - Log groups: `/ecs/backend`
   - Retention: 7 days

2. **Metrics**
   - ECS service metrics
   - ALB metrics
   - RDS metrics
   - Custom application metrics

3. **Alarms**
   - High CPU utilization
   - Memory usage
   - Failed health checks
   - Database connections

### Health Checks
1. **Application Health Check**
   ```python
   @app.route('/health')
   def health():
       return jsonify({'status': 'healthy'}), 200
   ```

2. **ALB Health Check**
   - Path: `/health`
   - Interval: 30 seconds
   - Timeout: 5 seconds
   - Healthy threshold: 2
   - Unhealthy threshold: 3

### Private Instance Access Methods

#### Method 1: AWS Systems Manager Session Manager (Recommended)

**Prerequisites:**
- SSM Agent installed on instances (included in ECS-optimized AMI)
- Proper IAM roles attached to instances
- VPC endpoints for SSM (if air-gapped)

**1. List Available Instances**
```bash
# List all SSM-managed instances
aws ssm describe-instance-information --query "InstanceInformationList[*].[InstanceId,Name,PingStatus]" --output table

# Filter by project instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*aws-sec-pillar*" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,Tags[?Key=='Name'].Value|[0],PrivateIpAddress,State.Name]" \
  --output table
```

**2. Connect to ECS Instance**
```bash
# Connect to ECS instance
aws ssm start-session --target i-1234567890abcdef0

# Alternative: Connect with specific user
aws ssm start-session --target i-1234567890abcdef0 --document-name AWS-StartInteractiveCommand --parameters command="sudo su - ec2-user"
```

**3. Session Manager with Port Forwarding**
```bash
# Forward local port to remote service
aws ssm start-session --target i-1234567890abcdef0 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["5000"],"localPortNumber":["8080"]}'

# Access application locally
curl http://localhost:8080/health
```

#### Method 2: Bastion Host SSH Access

**1. Get Bastion Host Information**
```bash
# Get bastion public IP
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*bastion*" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]" \
  --output table
```

**2. Retrieve SSH Keys from SSM**
```bash
# Get bastion private key
aws ssm get-parameter \
  --name "/aws-sec-pillar/bastion-private-key" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > bastion_key.pem

# Set proper permissions
chmod 600 bastion_key.pem
```

**3. Connect to Bastion Host**
```bash
# SSH to bastion
ssh -i bastion_key.pem ubuntu@$BASTION_PUBLIC_IP

# From bastion, connect to private instances
ssh ubuntu@$PRIVATE_INSTANCE_IP
```

**4. SSH Tunneling Through Bastion**
```bash
# Create SSH tunnel for database access
ssh -i bastion_key.pem -L 3306:$RDS_ENDPOINT:3306 ubuntu@$BASTION_PUBLIC_IP

# In another terminal, connect to database
mysql -h 127.0.0.1 -P 3306 -u admin -p

# Create tunnel for application access
ssh -i bastion_key.pem -L 5000:$PRIVATE_INSTANCE_IP:5000 ubuntu@$BASTION_PUBLIC_IP

# Access application locally
curl http://localhost:5000/health
```

#### Method 3: ECS Exec (Container Access)

**1. Enable ECS Exec on Service**
```bash
# Update service to enable execute command
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --enable-execute-command
```

**2. Connect to Running Container**
```bash
# List running tasks
aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME

# Get task ARN
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --query "taskArns[0]" --output text)

# Execute command in container
aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ARN \
  --container backend \
  --interactive \
  --command "/bin/bash"
```

**3. Run Commands in Container**
```bash
# Inside container, check application status
ps aux | grep python
netstat -tlnp | grep 5000

# Check environment variables
env | grep DB_

# Test database connection
python3 -c "import pymysql; print('PyMySQL available')"

# Check application logs
tail -f /var/log/application.log
```

#### Method 4: AWS Systems Manager Run Command

**1. Execute Commands on Multiple Instances**
```bash
# Run command on all ECS instances
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["docker ps","docker logs $(docker ps -q --filter name=ecs-backend)"]' \
  --targets "Key=tag:aws:autoscaling:groupName,Values=$ASG_NAME"
```

**2. Get Command Results**
```bash
# Get command ID from previous output
COMMAND_ID="command-id-from-above"

# Check command status
aws ssm list-command-invocations --command-id $COMMAND_ID

# Get command output
aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID
```

#### Method 5: CloudWatch Logs Access

**1. View Container Logs**
```bash
# List log groups
aws logs describe-log-groups --log-group-name-prefix "/ecs/"

# List log streams
aws logs describe-log-streams --log-group-name "/ecs/aws-sec-pillar-prod"

# Tail logs in real-time
aws logs tail "/ecs/aws-sec-pillar-prod" --follow

# Filter logs by pattern
aws logs filter-log-events \
  --log-group-name "/ecs/aws-sec-pillar-prod" \
  --filter-pattern "ERROR"
```

**2. View System Logs**
```bash
# View ECS agent logs
aws logs tail "/aws/ecs/containerinsights/$CLUSTER_NAME/performance" --follow

# View VPC Flow Logs (if enabled)
aws logs tail "VPCFlowLogs" --follow
```

### Access Method Comparison

| Method | Security | Ease of Use | Audit Trail | Use Case |
|--------|----------|-------------|-------------|----------|
| Session Manager | High | High | Complete | General admin tasks |
| Bastion SSH | Medium | Medium | Partial | Traditional SSH workflows |
| ECS Exec | High | High | Complete | Container debugging |
| Run Command | High | High | Complete | Batch operations |
| CloudWatch Logs | High | High | Complete | Log analysis |

### Security Considerations for Private Access

**1. IAM Permissions**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:StartSession",
        "ssm:TerminateSession",
        "ssm:ResumeSession"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:instance/*",
        "arn:aws:ssm:*:*:session/${aws:username}-*"
      ],
      "Condition": {
        "StringEquals": {
          "ssm:resourceTag/Environment": "prod"
        }
      }
    }
  ]
}
```

**2. Session Logging**
```bash
# Enable session logging to S3
aws ssm put-document \
  --name "SSM-SessionManagerRunShell" \
  --document-type "Session" \
  --document-format "JSON" \
  --content '{
    "schemaVersion": "1.0",
    "description": "Document to hold regional settings for Session Manager",
    "sessionType": "Standard_Stream",
    "inputs": {
      "s3BucketName": "session-logs-bucket",
      "s3KeyPrefix": "session-logs/",
      "s3EncryptionEnabled": true,
      "cloudWatchLogGroupName": "session-logs",
      "cloudWatchEncryptionEnabled": true
    }
  }'
```

### Operational Procedures
1. **Scaling**
   ```bash
   # Scale ECS service
   aws ecs update-service --cluster $CLUSTER --service $SERVICE --desired-count 4
   
   # Scale EC2 instances
   aws autoscaling update-auto-scaling-group --auto-scaling-group-name $ASG --desired-capacity 4
   ```

2. **Rolling Updates**
   ```bash
   # Force new deployment
   aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment
   ```

3. **Troubleshooting**
   ```bash
   # Check ECS agent logs via Session Manager
   aws ssm start-session --target $INSTANCE_ID
   sudo docker logs ecs-agent
   
   # Check container logs
   aws logs tail /ecs/backend --follow
   
   # Access container directly
   aws ecs execute-command --cluster $CLUSTER --task $TASK_ARN --container backend --interactive --command "/bin/bash"
   ```

---

## Security Best Practices

### Network Security
1. **Principle of Least Privilege**
   - Security groups allow only necessary traffic
   - NACLs provide additional layer
   - VPC endpoints eliminate internet routing

2. **Network Segmentation**
   - Public subnets: Only ALB
   - Private subnets: ECS and RDS
   - Database subnets: Isolated from application

### Container Security
1. **Image Security**
   - Use minimal base images
   - Regular vulnerability scanning
   - Image signing and verification
   - No secrets in images

2. **Runtime Security**
   - Non-root container execution
   - Read-only root filesystem
   - Resource limits
   - Security contexts

### Data Security
1. **Encryption**
   - All data encrypted at rest
   - TLS for data in transit
   - Key rotation policies
   - Secure key management

2. **Access Control**
   - IAM roles for service access
   - Database authentication
   - Session management
   - Audit logging

### Operational Security
1. **Monitoring**
   - CloudTrail for API logging
   - VPC Flow Logs
   - Application logging
   - Security event alerting

2. **Incident Response**
   - Automated response procedures
   - Isolation capabilities
   - Forensic data collection
   - Recovery procedures

---

## Troubleshooting Guide

### Common Issues

#### ECS Service Not Starting
```bash
# Check service events
aws ecs describe-services --cluster $CLUSTER --services $SERVICE

# Check task definition
aws ecs describe-task-definition --task-definition $TASK_DEF

# Check container logs
aws logs get-log-events --log-group-name /ecs/backend --log-stream-name $STREAM
```

#### Health Check Failures
```bash
# Test health endpoint locally
curl http://localhost:5000/health

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# Check security group rules
aws ec2 describe-security-groups --group-ids $SG_ID
```

#### Database Connection Issues
```bash
# Test database connectivity
mysql -h $DB_HOST -u admin -p

# Check security group rules
aws ec2 describe-security-groups --group-ids $DB_SG_ID

# Check VPC endpoints
aws ec2 describe-vpc-endpoints
```

#### Container Image Issues
```bash
# Check ECR repository
aws ecr describe-repositories

# List images
aws ecr list-images --repository-name $REPO_NAME

# Check image scan results
aws ecr describe-image-scan-findings --repository-name $REPO_NAME
```

#### Database Server Verification

**1. Check RDS Instance Status**
```bash
# Get RDS instance details
aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID

# Check instance status
aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query "DBInstances[0].DBInstanceStatus"

# Check endpoint availability
aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query "DBInstances[0].Endpoint"
```

**2. Network Connectivity Tests**
```bash
# Test from ECS container (via Session Manager)
aws ssm start-session --target $ECS_INSTANCE_ID

# Inside the instance, test database connectivity
sudo docker exec -it $(sudo docker ps -q --filter "name=ecs-agent") /bin/bash

# Test port connectivity
telnet $DB_HOST 3306

# Test DNS resolution
nslookup $DB_HOST

# Test with netcat
nc -zv $DB_HOST 3306
```

**3. Database Connection Verification**
```bash
# Connect to database from ECS instance
mysql -h $DB_HOST -u admin -p$DB_PASSWORD -e "SELECT 1;"

# Check database exists
mysql -h $DB_HOST -u admin -p$DB_PASSWORD -e "SHOW DATABASES;"

# Verify table structure
mysql -h $DB_HOST -u admin -p$DB_PASSWORD -D appdb -e "DESCRIBE companies;"

# Check table data
mysql -h $DB_HOST -u admin -p$DB_PASSWORD -D appdb -e "SELECT COUNT(*) FROM companies;"
```

**4. Application Database Integration Test**
```bash
# Test from application container
sudo docker exec -it $CONTAINER_ID /bin/bash

# Inside container, test Python database connection
python3 -c "
import pymysql
try:
    conn = pymysql.connect(
        host='$DB_HOST',
        user='admin',
        password='changeme123!',
        database='appdb'
    )
    print('Database connection successful')
    with conn.cursor() as cursor:
        cursor.execute('SELECT 1')
        result = cursor.fetchone()
        print(f'Query result: {result}')
    conn.close()
except Exception as e:
    print(f'Database connection failed: {e}')
"
```

**5. Database Performance and Health Checks**
```bash
# Check RDS performance metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=$DB_INSTANCE_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Check database connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=$DB_INSTANCE_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Check for database errors in logs
aws rds describe-db-log-files --db-instance-identifier $DB_INSTANCE_ID
aws rds download-db-log-file-portion --db-instance-identifier $DB_INSTANCE_ID --log-file-name error/mysql-error.log
```

**6. Security Group Verification for Database**
```bash
# Check RDS security group rules
aws ec2 describe-security-groups --group-ids $RDS_SECURITY_GROUP_ID

# Verify inbound rules allow ECS security group
aws ec2 describe-security-groups --group-ids $RDS_SECURITY_GROUP_ID --query "SecurityGroups[0].IpPermissions[?FromPort==\`3306\`]"

# Check ECS security group can reach RDS
aws ec2 describe-security-groups --group-ids $ECS_SECURITY_GROUP_ID --query "SecurityGroups[0].IpPermissionsEgress[?ToPort==\`3306\`]"
```

**7. Database Initialization Verification**
```bash
# Check if database schema is properly initialized
mysql -h $DB_HOST -u admin -p$DB_PASSWORD -D appdb -e "
SHOW TABLES;
DESCRIBE companies;
SELECT COUNT(*) as total_companies FROM companies;
SELECT status, COUNT(*) as count FROM companies GROUP BY status;
"

# Verify database charset and collation
mysql -h $DB_HOST -u admin -p$DB_PASSWORD -e "
SHOW VARIABLES LIKE 'character_set%';
SHOW VARIABLES LIKE 'collation%';
"
```

**8. Application-Level Database Health Check**
```bash
# Test application health endpoint that includes DB check
curl -v http://$ALB_DNS/health

# Test database-dependent endpoints
curl -X POST http://$ALB_DNS/api/companies \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-123",
    "companyName": "Test Company",
    "registrationNumber": "REG123",
    "businessType": "LLC",
    "address": "123 Test St",
    "contactPerson": "John Doe",
    "email": "test@example.com",
    "phone": "555-0123",
    "submittedDate": "2024-01-01T00:00:00Z"
  }'

# Verify data was inserted
curl http://$ALB_DNS/api/companies/test-123
```

**9. Database Backup and Recovery Verification**
```bash
# Check automated backup status
aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query "DBInstances[0].BackupRetentionPeriod"

# List available backups
aws rds describe-db-snapshots --db-instance-identifier $DB_INSTANCE_ID

# Check point-in-time recovery availability
aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query "DBInstances[0].LatestRestorableTime"
```

**10. Common Database Issues and Solutions**

**Issue: Connection Timeout**
```bash
# Check security group rules
# Verify VPC and subnet configuration
# Test network connectivity with telnet/nc
```

**Issue: Authentication Failed**
```bash
# Verify credentials in environment variables
# Check RDS master username/password
# Ensure SSL requirements are met
```

**Issue: Database Not Found**
```bash
# Check if database was created during RDS setup
# Verify database name in connection string
# Run database initialization script
```

**Issue: Table Doesn't Exist**
```bash
# Check if application initialization ran successfully
# Verify database schema creation
# Check application logs for initialization errors
```

#### Database Monitoring and Alerting

**CloudWatch Alarms for Database Health**
```bash
# Create CPU utilization alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "RDS-HighCPU" \
  --alarm-description "RDS CPU utilization is high" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DBInstanceIdentifier,Value=$DB_INSTANCE_ID \
  --evaluation-periods 2

# Create connection count alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "RDS-HighConnections" \
  --alarm-description "RDS connection count is high" \
  --metric-name DatabaseConnections \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 40 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=DBInstanceIdentifier,Value=$DB_INSTANCE_ID \
  --evaluation-periods 2
```

### Performance Optimization

#### ECS Optimization
1. **Task Placement**
   - Use placement strategies
   - Optimize resource allocation
   - Monitor CPU/memory usage

2. **Service Scaling**
   - Configure auto-scaling
   - Set appropriate thresholds
   - Monitor scaling events

#### Database Optimization
1. **Connection Pooling**
   - Implement connection pooling
   - Monitor connection counts
   - Optimize query performance

2. **Backup Strategy**
   - Automated backups
   - Point-in-time recovery
   - Cross-region replication

---

## Cost Optimization

### EC2 Cost Optimization
1. **Instance Types**
   - Use t3.micro for development
   - Consider Spot instances for non-critical workloads
   - Right-size based on metrics

2. **Auto Scaling**
   - Scale based on demand
   - Use scheduled scaling
   - Monitor utilization

### Storage Cost Optimization
1. **S3 Storage Classes**
   - Use appropriate storage classes
   - Implement lifecycle policies
   - Monitor access patterns

2. **EBS Optimization**
   - Use gp3 volumes
   - Right-size volumes
   - Delete unused snapshots

### Network Cost Optimization
1. **VPC Endpoints**
   - Use VPC endpoints instead of NAT Gateway
   - Saves ~$45/month per NAT Gateway
   - Reduces data transfer costs

2. **CloudFront**
   - Use CloudFront for static content
   - Reduce origin requests
   - Improve performance

### Monitoring Costs
1. **Cost Explorer**
   - Monitor spending trends
   - Set up cost alerts
   - Analyze cost drivers

2. **Budgets**
   - Set monthly budgets
   - Configure alerts
   - Track against forecasts

---

## Conclusion

This architecture demonstrates how to build a secure, well-architected application on AWS that prioritizes security without compromising functionality. The use of ECS/ECR provides a robust, scalable platform for containerized applications while maintaining strict security controls.

Key achievements:
- ✅ **Zero Internet Access** for backend resources
- ✅ **Immutable Infrastructure** with containers
- ✅ **Automated CI/CD** pipeline
- ✅ **Comprehensive Security** controls
- ✅ **High Availability** across multiple AZs
- ✅ **Cost Optimization** through VPC endpoints

The architecture serves as a blueprint for organizations requiring high-security environments while maintaining operational excellence and cost efficiency.