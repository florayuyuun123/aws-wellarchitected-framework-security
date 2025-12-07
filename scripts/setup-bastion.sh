#!/bin/bash

# Generate SSH key pair on bastion
ssh-keygen -t rsa -b 4096 -f /home/ubuntu/.ssh/bastion_key -N ""
chown ubuntu:ubuntu /home/ubuntu/.ssh/bastion_key*
chmod 600 /home/ubuntu/.ssh/bastion_key
chmod 644 /home/ubuntu/.ssh/bastion_key.pub

# Store private key in SSM Parameter Store
aws ssm put-parameter \
  --name "/aws-sec-pillar/bastion-private-key" \
  --value "$(cat /home/ubuntu/.ssh/bastion_key)" \
  --type "SecureString" \
  --overwrite \
  --region us-east-1

# Store public key in SSM Parameter Store
aws ssm put-parameter \
  --name "/aws-sec-pillar/bastion-public-key" \
  --value "$(cat /home/ubuntu/.ssh/bastion_key.pub)" \
  --type "String" \
  --overwrite \
  --region us-east-1
