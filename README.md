# Secure AWS Infrastructure with Terraform

This project deploys a secure, well-architected AWS infrastructure using Terraform with the following components:

## Architecture Overview

- **VPC**: Custom VPC with public and private subnets across 4 Availability Zones
- **Security**: Layered security groups, VPC endpoints, and AWS WAF (no NAT gateway)
- **Compute**: Auto Scaling Group (2 instances) with ALB in public subnets, EC2 in private subnets
- **Backend**: Python HTTP server with admin dashboard (no external dependencies)
- **Database**: Encrypted RDS MySQL in private subnets
- **Storage**: Encrypted S3 bucket for static website hosting
- **Protection**: AWS WAF with managed rules and rate limiting
- **Access**: Bastion host for secure SSH access to private instances

## Security Features

 **Network Segmentation**: Public/private subnet isolation across 4 AZs  
 **VPC Endpoints**: Private connectivity to AWS services (S3, EC2, SSM)  
 **Encryption**: RDS and S3 encryption at rest  
 **WAF Protection**: Web application firewall with managed rules and rate limiting  
 **Security Groups**: Least privilege access controls  
 **Bastion Access**: Secure SSH access to private resources  
 **Admin Backend**: Server-side rendered admin dashboard (not on S3)  
 **Session Management**: Sticky sessions with secure cookies  
 **No Internet Access**: Private instances isolated (no NAT gateway)  

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed

## Deployment Steps

1. **Clone and navigate to project**:
   ```bash
   cd aws-wellarchitected-framwork
   ```

2. **Customize variables**:
   ```bash
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

- **Website**: Company registration portal at S3 website URL
- **Admin Portal**: Access at `http://<ALB_DNS>/admin/login`
  - Username: `admin`
  - Password: `admin123`
- **API Endpoints**: Available at `http://<ALB_DNS>/api/*`
- **Bastion Access**: SSH to bastion host, then to private instances
- **Database**: Connect to RDS from private instances only
- **Monitoring**: Check WAF metrics and ALB target health in CloudWatch

## GitHub Actions Deployment

1. **Setup Repository Secrets**:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. **Deploy**: Push to main branch or trigger manually
3. **Destroy**: Use "Destroy Infrastructure" workflow

## Application Features

### Public Website (S3)
- **Company Registration**: Companies can register online via form
- **Status Tracking**: Check registration status by reference ID or registration number
- **Responsive Design**: Works on all devices

### Admin Dashboard (Backend)
- **Secure Login**: Server-side authentication (admin/admin123)
- **Pending Registrations**: View all pending company registrations
- **Approve/Reject**: One-click approval or rejection
- **Approved List**: View all approved companies with approval dates
- **Session Management**: Secure cookie-based sessions with sticky ALB routing

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