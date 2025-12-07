#!/bin/bash

echo "=== Checking Target Group Health ==="
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:us-east-1:590184076844:targetgroup/aws-sec-pillar-tg-12071144/f71a39d5a1b553e8

echo -e "\n=== Testing ALB Health Endpoint ==="
curl -v http://aws-sec-pillar-prod-alb-2116670987.us-east-1.elb.amazonaws.com/health

echo -e "\n=== Checking Running Instances ==="
aws ec2 describe-instances --filters "Name=tag:Name,Values=*aws-sec-pillar-prod-instance*" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].[InstanceId,State.Name,LaunchTime,PrivateIpAddress]" --output table

echo -e "\n=== Checking SSM Agent Status ==="
aws ssm describe-instance-information --query "InstanceInformationList[?contains(InstanceId, 'i-')].[InstanceId,PingStatus,LastPingDateTime]" --output table