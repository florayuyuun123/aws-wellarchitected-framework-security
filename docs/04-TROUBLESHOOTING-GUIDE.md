# Troubleshooting Guide

## Common Issues and Solutions

### 1. Unhealthy Target Instances

#### Symptoms
```bash
aws elbv2 describe-target-health --target-group-arn <ARN>
# Output: "State": "unhealthy", "Reason": "Target.FailedHealthChecks"
```

#### Possible Causes

**A. Flask Application Not Running**

Check service status:
```bash
# SSH to instance via bastion
ssh -i ~/.ssh/argo-key-pair ubuntu@<BASTION_IP>
ssh ubuntu@<PRIVATE_IP>

# Check Flask service
sudo systemctl status flask-app

# If not running:
sudo systemctl start flask-app

# Check logs
sudo journalctl -u flask-app -n 50 --no-pager
```

**B. User Data Script Failed**

Check cloud-init logs:
```bash
# View user data execution log
sudo cat /var/log/cloud-init-output.log

# Check for errors
sudo grep -i error /var/log/cloud-init-output.log

# View cloud-init status
sudo cloud-init status
```

**C. Port 5000 Not Listening**

Verify Flask is listening:
```bash
# Check listening ports
sudo netstat -tlnp | grep 5000

# Or using ss
sudo ss -tlnp | grep 5000

# Test locally
curl localhost:5000/health
```

**D. Security Group Misconfiguration**

Verify security groups:
```bash
# Check EC2 security group allows port 5000 from ALB
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*ec2-sg*" \
  --query "SecurityGroups[*].IpPermissions"

# Check ALB security group allows port 80 from internet
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*alb-sg*" \
  --query "SecurityGroups[*].IpPermissions"
```

**E. Health Check Path Incorrect**

Verify health check configuration:
```bash
# Check target group health check settings
aws elbv2 describe-target-groups \
  --names aws-sec-pillar-tg-* \
  --query "TargetGroups[*].HealthCheckPath"

# Should return: "/health"
```

#### Solutions

**Solution 1: Restart Flask Service**
```bash
sudo systemctl restart flask-app
sudo systemctl enable flask-app
```

**Solution 2: Manually Install Flask**
```bash
sudo apt update
sudo apt install -y python3 python3-pip
sudo pip3 install Flask==2.3.3
```

**Solution 3: Recreate Instances**
```bash
# Terminate unhealthy instances (ASG will create new ones)
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id <INSTANCE_ID> \
  --should-decrement-desired-capacity false
```

**Solution 4: Increase Health Check Grace Period**
```hcl
# In modules/compute/main.tf
resource "aws_autoscaling_group" "main" {
  health_check_grace_period = 900  # Increase to 15 minutes
}
```

---

### 2. SSH Connection Issues

#### Symptoms
- SSH hangs or times out
- "Permission denied (publickey)" error
- "Connection refused" error

#### Issue A: Cannot SSH to Bastion

**Cause**: Security group not allowing SSH from your IP

**Solution**:
```bash
# Get your public IP
MY_IP=$(curl -s ifconfig.me)

# Update bastion security group
aws ec2 authorize-security-group-ingress \
  --group-id <BASTION_SG_ID> \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP/32
```

**Cause**: Wrong SSH key

**Solution**:
```bash
# Verify key pair exists
aws ec2 describe-key-pairs --key-names argo-key-pair

# Use correct key file
ssh -i ~/.ssh/argo-key-pair ubuntu@<BASTION_IP>

# Check key permissions
chmod 600 ~/.ssh/argo-key-pair
```

#### Issue B: Cannot SSH from Bastion to Private Instance

**Cause**: SSH key not on bastion

**Solution**:
```bash
# From local machine, copy key to bastion
scp -i ~/.ssh/argo-key-pair ~/.ssh/argo-key-pair ubuntu@<BASTION_IP>:~/

# On bastion, set permissions
chmod 600 ~/argo-key-pair

# SSH to private instance
ssh -i ~/argo-key-pair ubuntu@<PRIVATE_IP>
```

**Cause**: Security group not allowing SSH from bastion

**Solution**:
```bash
# Verify EC2 security group allows SSH from bastion SG
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*ec2-sg*" \
  --query "SecurityGroups[*].IpPermissions[?FromPort==\`22\`]"
```

**Cause**: Instance not fully booted

**Solution**:
```bash
# Wait 5-10 minutes after instance launch
# Check instance status
aws ec2 describe-instance-status --instance-ids <INSTANCE_ID>

# Check system log
aws ec2 get-console-output --instance-id <INSTANCE_ID> --output text
```

#### Issue C: SSH Hangs

**Cause**: Network ACL blocking traffic

**Solution**:
```bash
# Check NACL rules
aws ec2 describe-network-acls \
  --filters "Name=association.subnet-id,Values=<SUBNET_ID>"

# Ensure NACL allows:
# - Inbound: Port 22 from bastion subnet
# - Outbound: Ephemeral ports (1024-65535)
```

**Cause**: Route table misconfiguration

**Solution**:
```bash
# Check route tables
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=<SUBNET_ID>"

# Ensure local route exists: 10.0.0.0/16 → local
```

---

### 3. SSM Session Manager Not Working

#### Symptoms
```bash
aws ssm start-session --target <INSTANCE_ID>
# Error: TargetNotConnected
```

#### Possible Causes

**A. SSM Agent Not Installed**

**Solution**:
```bash
# Update user data script (already done)
# Terminate instances to force recreation
aws autoscaling terminate-instance-in-auto-scaling-group \
  --instance-id <INSTANCE_ID> \
  --should-decrement-desired-capacity false
```

**B. IAM Role Missing**

**Solution**:
```bash
# Verify instance has IAM role
aws ec2 describe-instances \
  --instance-ids <INSTANCE_ID> \
  --query "Reservations[*].Instances[*].IamInstanceProfile"

# Verify role has SSM policy
aws iam list-attached-role-policies \
  --role-name aws-sec-pillar-prod-ec2-ssm-role
```

**C. SSM Agent Not Running**

**Solution** (via SSH):
```bash
# Check SSM agent status
sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent

# Start if not running
sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent

# Enable on boot
sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent
```

**D. No Internet Access**

**Solution**:
```bash
# Instances need internet access for SSM
# Option 1: Add NAT Gateway (costs $45/month)
# Option 2: Use VPC Endpoints for SSM (already configured)

# Verify VPC endpoints exist
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=<VPC_ID>"
```

---

### 4. Terraform Errors

#### Issue A: Resource Already Exists

**Error**:
```
Error: Error creating VPC: VpcLimitExceeded
```

**Solution**:
```bash
# Import existing resource
terraform import module.networking.aws_vpc.main vpc-XXXXXXXXX

# Or delete existing resource
aws ec2 delete-vpc --vpc-id vpc-XXXXXXXXX
```

#### Issue B: State Lock Error

**Error**:
```
Error: Error acquiring the state lock
```

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>

# Or wait for lock to expire (usually 15 minutes)
```

#### Issue C: Dependency Errors

**Error**:
```
Error: Error deleting security group: DependencyViolation
```

**Solution**:
```bash
# Destroy in correct order
terraform destroy -target=module.compute
terraform destroy -target=module.database
terraform destroy -target=module.security
terraform destroy
```

#### Issue D: Invalid Credentials

**Error**:
```
Error: error configuring Terraform AWS Provider: no valid credential sources
```

**Solution**:
```bash
# Reconfigure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity

# Check environment variables
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
```

---

### 5. Website Issues

#### Issue A: 404 Not Found

**Cause**: Files not uploaded to S3

**Solution**:
```bash
# Sync website files
aws s3 sync website/ s3://<BUCKET_NAME>/ --delete

# Verify files exist
aws s3 ls s3://<BUCKET_NAME>/
```

**Cause**: Index document not set

**Solution**:
```bash
# Configure website hosting
aws s3 website s3://<BUCKET_NAME>/ \
  --index-document index.html \
  --error-document error.html
```

#### Issue B: API Calls Failing (CORS)

**Error** (in browser console):
```
Access to fetch at 'http://alb-dns/api/...' from origin 'http://s3-website...' 
has been blocked by CORS policy
```

**Solution**:
```bash
# Add CORS to Flask app
# In app.py:
from flask_cors import CORS
app = Flask(__name__)
CORS(app)

# Install flask-cors
pip3 install flask-cors

# Restart service
sudo systemctl restart flask-app
```

#### Issue C: ALB DNS Not Replaced

**Cause**: GitHub Actions workflow not running

**Solution**:
```bash
# Manually replace placeholder
ALB_DNS=$(terraform output -raw alb_dns_name)
sed -i "s|ALB_DNS_PLACEHOLDER|http://$ALB_DNS|g" website/js/config.js

# Upload to S3
aws s3 cp website/js/config.js s3://<BUCKET_NAME>/js/config.js
```

---

### 6. Database Connection Issues

#### Issue A: Cannot Connect to RDS

**Cause**: Security group not allowing connection

**Solution**:
```bash
# Verify RDS security group allows port 3306 from EC2 SG
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*rds-sg*" \
  --query "SecurityGroups[*].IpPermissions"
```

**Cause**: Wrong endpoint

**Solution**:
```bash
# Get RDS endpoint
terraform output rds_endpoint

# Test connection from EC2 instance
mysql -h <RDS_ENDPOINT> -u admin -p
```

#### Issue B: Authentication Failed

**Cause**: Wrong password

**Solution**:
```bash
# Reset password
aws rds modify-db-instance \
  --db-instance-identifier aws-sec-pillar-prod-db \
  --master-user-password NewPassword123! \
  --apply-immediately
```

---

### 7. Auto Scaling Issues

#### Issue A: Instances Not Scaling

**Cause**: No scaling policy defined

**Solution**:
```hcl
# Add to modules/compute/main.tf
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.main.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
}
```

#### Issue B: Instances Terminating Immediately

**Cause**: Health check failing

**Solution**:
```bash
# Increase grace period
# In modules/compute/main.tf:
health_check_grace_period = 900  # 15 minutes
```

---

### 8. WAF Blocking Legitimate Traffic

#### Symptoms
- Users getting 403 Forbidden
- Legitimate requests blocked

#### Solution

**Check WAF logs**:
```bash
# Enable WAF logging
aws wafv2 put-logging-configuration \
  --logging-configuration ResourceArn=<WAF_ARN>,LogDestinationConfigs=<KINESIS_ARN>

# View blocked requests
aws wafv2 list-web-acls --scope REGIONAL
```

**Adjust rate limit**:
```hcl
# In modules/waf/main.tf
limit = 5000  # Increase from 2000
```

**Whitelist IP**:
```hcl
resource "aws_wafv2_ip_set" "whitelist" {
  name  = "${var.project_name}-whitelist"
  scope = "REGIONAL"
  ip_address_version = "IPV4"
  addresses = ["1.2.3.4/32"]
}
```

---

### 9. Cost Overruns

#### Issue: Unexpected High Costs

**Check costs**:
```bash
# View current month costs
aws ce get-cost-and-usage \
  --time-period Start=2024-12-01,End=2024-12-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

**Common culprits**:
- NAT Gateway: $45/month (we don't use this)
- Data transfer: Monitor outbound traffic
- RDS Multi-AZ: $30/month
- VPC Endpoints: $7.20/month each

**Solutions**:
- Use t3.micro (free tier eligible)
- Delete unused resources
- Enable S3 lifecycle policies
- Use Reserved Instances for long-term

---

### 10. GitHub Actions Failures

#### Issue A: Workflow Not Triggering

**Cause**: Path filter not matching

**Solution**:
```yaml
# In .github/workflows/deploy.yml
on:
  push:
    branches: [ main ]
    paths:
      - 'website/**'
      - '.github/workflows/deploy.yml'  # Add this
```

#### Issue B: AWS Credentials Invalid

**Error**:
```
Error: The security token included in the request is invalid
```

**Solution**:
```bash
# Regenerate AWS access keys
# Update GitHub secrets:
# Settings → Secrets → AWS_ACCESS_KEY_ID
# Settings → Secrets → AWS_SECRET_ACCESS_KEY
```

#### Issue C: S3 Sync Fails

**Error**:
```
fatal error: An error occurred (403) when calling the PutObject operation: Forbidden
```

**Solution**:
```bash
# Verify IAM user has S3 permissions
aws iam attach-user-policy \
  --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

---

## Debugging Commands

### Quick Health Check Script

```bash
#!/bin/bash
# health-check.sh

echo "=== Infrastructure Health Check ==="

# 1. Check VPC
echo "1. VPC Status:"
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=aws-sec-pillar-prod-vpc" \
  --query "Vpcs[*].[VpcId,State]" --output table

# 2. Check EC2 Instances
echo "2. EC2 Instances:"
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=aws-sec-pillar-prod-instance" \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]" \
  --output table

# 3. Check Target Health
echo "3. Target Health:"
TG_ARN=$(aws elbv2 describe-target-groups \
  --names aws-sec-pillar-tg-* \
  --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 describe-target-health --target-group-arn $TG_ARN \
  --query "TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]" \
  --output table

# 4. Check ALB
echo "4. ALB Status:"
aws elbv2 describe-load-balancers \
  --names aws-sec-pillar-prod-alb \
  --query "LoadBalancers[*].[LoadBalancerName,State.Code,DNSName]" \
  --output table

# 5. Check RDS
echo "5. RDS Status:"
aws rds describe-db-instances \
  --db-instance-identifier aws-sec-pillar-prod-db \
  --query "DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]" \
  --output table

# 6. Test Backend
echo "6. Backend Health:"
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names aws-sec-pillar-prod-alb \
  --query "LoadBalancers[0].DNSName" --output text)
curl -s http://$ALB_DNS/health || echo "Backend not responding"

echo "=== Health Check Complete ==="
```

### Instance Debugging Script

```bash
#!/bin/bash
# debug-instance.sh <INSTANCE_ID>

INSTANCE_ID=$1

echo "=== Debugging Instance: $INSTANCE_ID ==="

# 1. Instance details
echo "1. Instance Details:"
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query "Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress,SubnetId]" \
  --output table

# 2. Security groups
echo "2. Security Groups:"
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query "Reservations[*].Instances[*].SecurityGroups[*].[GroupId,GroupName]" \
  --output table

# 3. IAM role
echo "3. IAM Role:"
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query "Reservations[*].Instances[*].IamInstanceProfile.Arn" \
  --output text

# 4. System status
echo "4. System Status:"
aws ec2 describe-instance-status --instance-ids $INSTANCE_ID \
  --query "InstanceStatuses[*].[SystemStatus.Status,InstanceStatus.Status]" \
  --output table

# 5. Console output (last 50 lines)
echo "5. Console Output (last 50 lines):"
aws ec2 get-console-output --instance-id $INSTANCE_ID --output text | tail -50

echo "=== Debug Complete ==="
```

---

## Getting Help

### AWS Support
- **Basic Support**: Included with account
- **Developer Support**: $29/month
- **Business Support**: $100/month

### Community Resources
- AWS Forums: https://forums.aws.amazon.com
- Stack Overflow: Tag `amazon-web-services`
- Terraform Registry: https://registry.terraform.io

### Documentation
- AWS Documentation: https://docs.aws.amazon.com
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws

---

**Next**: See [Project Journey](./05-PROJECT-JOURNEY.md) for the complete development story.
