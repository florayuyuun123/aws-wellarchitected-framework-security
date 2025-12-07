#!/bin/bash

echo "=== 502 Bad Gateway Troubleshooting ==="
echo "Timestamp: $(date)"
echo

# Get current target group ARN
echo "1. Current Target Group ARN:"
terraform output target_group_arn
echo

# Test ALB endpoint
echo "2. Testing ALB Health Endpoint:"
echo "URL: http://aws-sec-pillar-prod-alb-2116670987.us-east-1.elb.amazonaws.com/health"
curl -I http://aws-sec-pillar-prod-alb-2116670987.us-east-1.elb.amazonaws.com/health
echo

# Get bastion IP for SSH access
echo "3. Bastion Host IP (for SSH debugging):"
terraform output bastion_public_ip
echo

echo "=== Common Causes of 502 Error ==="
echo "1. No healthy targets in target group"
echo "2. Flask app not running on EC2 instances"
echo "3. Security group blocking port 5000"
echo "4. User data script failed during instance launch"
echo "5. Health check path/port misconfiguration"
echo

echo "=== Next Steps ==="
echo "1. SSH to bastion: ssh -i ~/.ssh/argo-key-pair.pem ubuntu@$(terraform output -raw bastion_public_ip)"
echo "2. From bastion, SSH to private instances and check:"
echo "   - sudo systemctl status flask-app"
echo "   - curl http://localhost:5000/health"
echo "   - sudo journalctl -u flask-app -f"
echo "3. Check /var/log/user-data.log for setup issues"