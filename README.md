# Secure AWS Infrastructure with Terraform

This project deploys a secure, well-architected AWS infrastructure using Terraform with the following components:

## Architecture Overview

- **VPC**: Custom VPC with public and private subnets across multiple AZs
- **Security**: Layered security groups and VPC endpoints (no NAT gateway)
- **Compute**: Auto Scaling Group with ALB in public subnets, EC2 instances in private subnets
- **Database**: Encrypted RDS MySQL in private subnets
- **Storage**: Encrypted S3 bucket with security controls
- **Protection**: AWS WAF with managed rules and rate limiting
- **Access**: Bastion host for secure SSH access to private instances

## Security Features

✅ **Network Segmentation**: Public/private subnet isolation  
✅ **VPC Endpoints**: Private connectivity to AWS services  
✅ **Encryption**: RDS and S3 encryption at rest  
✅ **WAF Protection**: Web application firewall with managed rules  
✅ **Security Groups**: Least privilege access controls  
✅ **Bastion Access**: Secure SSH access to private resources  

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. SSH key pair generated (`ssh-keygen -t rsa -b 4096`)

## Deployment Steps

1. **Clone and navigate to project**:
   ```bash
   cd aws-wellarchitected-framwork
   ```

2. **Copy and customize variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Plan deployment**:
   ```bash
   terraform plan
   ```

5. **Deploy infrastructure**:
   ```bash
   terraform apply
   ```

## Post-Deployment

- **ALB DNS**: Access your application via the ALB DNS name
- **Website**: Company registration portal hosted on S3
- **Bastion Access**: SSH to bastion host, then to private instances
- **Database**: Connect to RDS from private instances only
- **Monitoring**: Check WAF metrics in CloudWatch

## GitHub Actions Deployment

1. **Setup Repository Secrets**:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. **Deploy**: Push to main branch or trigger manually
3. **Destroy**: Use "Destroy Infrastructure" workflow

## Website Features

- **Company Registration**: Companies can register online
- **Status Tracking**: Check registration status by number
- **Admin Portal**: Approve/reject registrations (admin/admin123)
- **Certificate Download**: Approved companies get certificates
- **Responsive Design**: Works on all devices

## Security Considerations

- Update bastion security group to restrict SSH access to your IP
- Use AWS Secrets Manager for RDS passwords in production
- Enable CloudTrail and GuardDuty for monitoring
- Implement backup strategies for RDS and S3

## Clean Up

```bash
terraform destroy
```

## Cost Optimization

- Uses t3.micro instances (free tier eligible)
- VPC endpoints instead of NAT gateway saves ~$45/month
- Auto Scaling adjusts capacity based on demand