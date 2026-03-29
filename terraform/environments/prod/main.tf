# ==============================================
# Production Environment - High Availability
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

  # Production backend - MUST configure before use
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "aws-infra/prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "prod"
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Repository  = "aws-infra-project"
      CostCenter  = "production"
    }
  }
}

locals {
  common_tags = {
    Environment = "prod"
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CostCenter  = "production"
  }
}

# ----------------------------------------------
# VPC - Production with 3 AZs
# ----------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = "prod"
  vpc_cidr           = "10.2.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  enable_nat_gateway = true
  enable_flow_logs   = true

  tags = local.common_tags
}

# ----------------------------------------------
# S3 - Production with replication ready
# ----------------------------------------------
module "s3_storage" {
  source = "../../modules/s3"

  project_name      = var.project_name
  environment       = "prod"
  bucket_suffix     = "storage"
  enable_versioning = true
  enforce_ssl       = true

  lifecycle_rules = [
    {
      id                                 = "intelligent-tiering"
      prefix                             = ""
      transition_days                    = 30
      transition_storage_class           = "INTELLIGENT_TIERING"
      noncurrent_version_expiration_days = 90
    },
    {
      id                       = "archive-logs"
      prefix                   = "logs/"
      transition_days          = 90
      transition_storage_class = "GLACIER"
      expiration_days          = 365
    }
  ]

  tags = local.common_tags
}

# ----------------------------------------------
# RDS - Production with Multi-AZ
# ----------------------------------------------
module "rds" {
  source = "../../modules/rds"

  project_name            = var.project_name
  environment             = "prod"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.ecs_security_group_id]

  db_name        = "app"
  db_username    = "postgres"
  engine_version = "15.4"
  instance_class = "db.r6g.large"
  multi_az       = true

  allocated_storage     = 100
  max_allocated_storage = 500

  backup_retention_period     = 30
  enable_performance_insights = true
  monitoring_interval         = 30

  tags = local.common_tags

  depends_on = [module.vpc]
}

# ----------------------------------------------
# ECS - Production with auto-scaling
# ----------------------------------------------
module "ecs" {
  source = "../../modules/ecs"

  project_name       = var.project_name
  environment        = "prod"
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  container_name  = "app"
  container_image = var.container_image
  container_port  = 8080

  task_cpu      = 1024
  task_memory   = 2048
  desired_count = 3

  environment_variables = [
    {
      name  = "ENVIRONMENT"
      value = "prod"
    },
    {
      name  = "LOG_LEVEL"
      value = "warn"
    }
  ]

  secrets = [
    {
      name       = "DATABASE_URL"
      value_from = module.rds.db_credentials_secret_arn
    }
  ]

  enable_alb         = true
  enable_autoscaling = true
  min_capacity       = 3
  max_capacity       = 20
  cpu_target_value   = 60

  enable_container_insights = true
  enable_execute_command    = false

  tags = local.common_tags

  depends_on = [module.vpc]
}
