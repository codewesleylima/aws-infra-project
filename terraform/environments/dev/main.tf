# ==============================================
# Dev Environment - Main Configuration
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

  # Backend configuration for state management
  # Uncomment and configure for your S3 backend
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "aws-infra/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# ----------------------------------------------
# Provider Configuration
# ----------------------------------------------
provider "aws" {
  region                  = var.aws_region
  access_key              = var.aws_access_key
  secret_key              = var.aws_secret_key
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack

  s3 {
    force_path_style = true
  }

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Repository  = "aws-infra-project"
    }
  }

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      ec2            = var.localstack_endpoint
      rds            = var.localstack_endpoint
      s3             = var.localstack_endpoint
      ecs            = var.localstack_endpoint
      iam            = var.localstack_endpoint
      secretsmanager = var.localstack_endpoint
      cloudwatch     = var.localstack_endpoint
    }
  }
}

# ----------------------------------------------
# Local Variables
# ----------------------------------------------
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# ----------------------------------------------
# VPC Module
# ----------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
  enable_flow_logs   = true

  tags = local.common_tags
}

# ----------------------------------------------
# S3 Module - Application Storage
# ----------------------------------------------
module "s3_storage" {
  source = "../../modules/s3"

  project_name      = var.project_name
  environment       = var.environment
  bucket_suffix     = "storage"
  enable_versioning = true
  enforce_ssl       = true

  lifecycle_rules = [
    {
      id                                 = "archive-old-objects"
      prefix                             = "archive/"
      transition_days                    = 90
      transition_storage_class           = "GLACIER"
      noncurrent_version_expiration_days = 30
    }
  ]

  tags = local.common_tags
}

# ----------------------------------------------
# RDS Module
# ----------------------------------------------
module "rds" {
  source = "../../modules/rds"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = []

  db_name          = var.db_name
  db_username      = var.db_username
  engine_version   = var.db_engine_version
  instance_class   = var.db_instance_class
  multi_az         = var.environment == "prod"
  
  backup_retention_period     = 7
  enable_performance_insights = true
  monitoring_interval         = 60

  tags = local.common_tags

  depends_on = [module.vpc]
}

# ----------------------------------------------
# ECS Module
# ----------------------------------------------
module "ecs" {
  source = "../../modules/ecs"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  container_name  = var.container_name
  container_image = var.container_image
  container_port  = var.container_port

  task_cpu      = var.task_cpu
  task_memory   = var.task_memory
  desired_count = var.desired_count

  environment_variables = [
    {
      name  = "ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  ]

  secrets = []

  enable_alb                = true
  enable_autoscaling        = true
  min_capacity              = 1
  max_capacity              = 5
  enable_container_insights = true

  tags = local.common_tags

  depends_on = [module.vpc, module.rds]
}
