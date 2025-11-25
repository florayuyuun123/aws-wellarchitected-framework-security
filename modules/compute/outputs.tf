output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "bastion_public_ip" {
  description = "Bastion host public IP"
  value       = aws_instance.bastion.public_ip
}