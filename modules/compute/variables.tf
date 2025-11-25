variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "alb_security_group" {
  description = "ALB security group ID"
  type        = string
}

variable "ec2_security_group" {
  description = "EC2 security group ID"
  type        = string
}

variable "bastion_security_group" {
  description = "Bastion security group ID"
  type        = string
}