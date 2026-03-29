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

# All resources automatically tagged via provider.default_tags

# VPC
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = "staging"
  vpc_cidr           = "10.1.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  enable_nat_gateway = true
  enable_flow_logs   = true
}

# ALB
module "alb" {
  source = "../../modules/alb"

  project_name      = var.project_name
  environment       = "staging"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  enable_alb             = true
  container_port        = 8080
  health_check_path     = "/health"
  health_check_matcher  = "200-299"
  certificate_arn       = null
  alb_logs_bucket       = null

  depends_on = [module.vpc]
}

# S3
module "s3_storage" {
  source = "../../modules/s3"

  project_name      = var.project_name
  environment       = "staging"
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


  depends_on = [module.vpc]
}

# ECS
module "ecs" {
  source = "../../modules/ecs"

  project_name       = var.project_name
  environment        = "staging"
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
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

  alb_target_group_arn   = module.alb.target_group_arn
  alb_security_group_id  = module.alb.alb_security_group_id
  enable_autoscaling     = true
  min_capacity           = 2
  max_capacity           = 10

  depends_on = [module.vpc, module.alb]
}
