output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion (uses generated key)"
  value       = "aws ssm get-parameter --name /aws-sec-pillar/bastion-private-key --with-decryption --query Parameter.Value --output text > bastion_key && chmod 600 bastion_key && ssh -i bastion_key ubuntu@${aws_instance.bastion.public_ip}"
}
