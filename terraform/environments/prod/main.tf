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
  # Custom tags added to provider default_tags
  custom_tags = {
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
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = true
  enable_flow_logs   = true
}

# ----------------------------------------------
# ALB - Production
# ----------------------------------------------
module "alb" {
  source = "../../modules/alb"

  project_name      = var.project_name
  environment       = "prod"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  enable_alb             = true
  container_port        = var.container_port
  health_check_path     = "/health"
  health_check_matcher  = "200-299"
  certificate_arn       = null
  alb_logs_bucket       = aws_s3_bucket.alb_logs.id

  depends_on = [module.vpc, aws_s3_bucket.alb_logs]
}

# ----------------------------------------------
# CloudTrail - Production audit logging
# ----------------------------------------------
module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project_name                = var.project_name
  environment                 = "prod"
  enable_cloudtrail           = true
  enable_log_file_validation  = true
  include_global_service_events = true
  is_multi_region_trail       = true
  kms_key_id                  = null
  s3_log_retention_days       = 90

  depends_on = [module.vpc]
}

# ----------------------------------------------
# S3 - ALB Access Logs
# ----------------------------------------------
# Get the ELB service account ID for the region
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.project_name}-alb-logs-${data.aws_caller_identity.current.account_id}-${var.environment}"

  tags = {
    Name = "${var.project_name}-alb-logs-${var.environment}"
  }
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

data "aws_caller_identity" "current" {}

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

  db_name        = var.db_name
  db_username    = var.db_username
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  multi_az       = true

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage

  backup_retention_period     = var.db_backup_retention_period
  enable_performance_insights = true
  monitoring_interval         = 30


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
  private_subnet_ids = module.vpc.private_subnet_ids

  container_name  = "app"
  container_image = var.container_image
  container_port  = var.container_port

  task_cpu      = var.task_cpu
  task_memory   = var.task_memory
  desired_count = var.desired_count

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

  alb_target_group_arn   = module.alb.target_group_arn
  alb_security_group_id  = module.alb.alb_security_group_id
  enable_autoscaling     = true
  min_capacity           = 3
  max_capacity           = 20
  cpu_target_value       = 60

  enable_container_insights = true
  enable_execute_command    = false

  depends_on = [module.vpc, module.alb]
}
