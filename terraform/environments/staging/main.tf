# ==============================================
# Staging Environment
# ==============================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "aws-infra/staging/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "staging"
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Repository  = "aws-infra-project"
    }
  }
}

locals {
  common_tags = {
    Environment = "staging"
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# VPC
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = "staging"
  vpc_cidr           = "10.1.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  enable_nat_gateway = true
  enable_flow_logs   = true

  tags = local.common_tags
}

# S3
module "s3_storage" {
  source = "../../modules/s3"

  project_name      = var.project_name
  environment       = "staging"
  bucket_suffix     = "storage"
  enable_versioning = true
  enforce_ssl       = true

  tags = local.common_tags
}

# RDS
module "rds" {
  source = "../../modules/rds"

  project_name            = var.project_name
  environment             = "staging"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.ecs_security_group_id]

  db_name        = "app"
  db_username    = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.small"
  multi_az       = false

  backup_retention_period     = 14
  enable_performance_insights = true

  tags = local.common_tags

  depends_on = [module.vpc]
}

# ECS
module "ecs" {
  source = "../../modules/ecs"

  project_name       = var.project_name
  environment        = "staging"
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  container_name  = "app"
  container_image = var.container_image
  container_port  = 8080

  task_cpu      = 512
  task_memory   = 1024
  desired_count = 2

  environment_variables = [
    { name = "ENVIRONMENT", value = "staging" },
    { name = "LOG_LEVEL", value = "info" }
  ]

  secrets = [
    {
      name       = "DATABASE_URL"
      value_from = module.rds.db_credentials_secret_arn
    }
  ]

  enable_alb         = true
  enable_autoscaling = true
  min_capacity       = 2
  max_capacity       = 10

  tags = local.common_tags

  depends_on = [module.vpc, module.rds]
}
