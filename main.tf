terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Modules
module "vpc" {
  source = "./modules/vpc"
  
  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source = "./modules/security"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
}

module "compute" {
  source = "./modules/compute"
  
  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  alb_security_group  = module.security.alb_security_group_id
  ec2_security_group  = module.security.ec2_security_group_id
  bastion_security_group = module.security.bastion_security_group_id
  rds_endpoint        = module.database.rds_endpoint
}

module "database" {
  source = "./modules/database"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_security_group  = module.security.rds_security_group_id
}

module "storage" {
  source = "./modules/storage"
  
  project_name = var.project_name
  environment  = var.environment
  account_id   = data.aws_caller_identity.current.account_id
}

module "waf" {
  source = "./modules/waf"
  
  project_name = var.project_name
  environment  = var.environment
  alb_arn      = module.compute.alb_arn
}