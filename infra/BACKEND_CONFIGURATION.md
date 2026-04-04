# ==============================================
# Terraform State Backend Configuration Example
# ==============================================
# This file demonstrates how to configure Terraform state locking
# and encryption using S3 + DynamoDB.
#
# To use this configuration:
# 1. Create the S3 bucket and DynamoDB table first (see setup script)
# 2. Uncomment the backend block in each environment's terraform block
# 3. Run: terraform init
#
# For Security:
# - S3 bucket should have versioning enabled
# - S3 bucket should block all public access
# - SSE encryption should be enabled
# - DynamoDB should have point-in-time recovery enabled

terraform {
  # Uncomment and configure for your S3 backend
  # backend "s3" {
  #   # AWS credentials can be provided via:
  #   # - AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
  #   # - AWS profile: AWS_PROFILE environment variable
  #   # - EC2 IAM role (when running on EC2)
  #
  #   bucket         = "your-terraform-state-bucket"  # Change to your bucket name
  #   key            = "aws-infra/dev/terraform.tfstate"  # Change path as needed
  #   region         = "us-east-1"  # Match your primary region
  #   encrypt        = true  # Enable server-side encryption
  #   dynamodb_table = "terraform-state-lock"  # DynamoDB table for locking
  #
  #   # Optional: Skip checking if provided credentials are valid
  #   # skip_credentials_validation = false
  #
  #   # Optional: Skip metadata API check  
  #   # skip_metadata_api_check = false
  #
  #   # Optional: Skip requesting account ID
  #   # skip_region_validation = false
  # }

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
}

# Example IAM policy for state management
# This policy should be attached to the IAM user running Terraform

locals {
  state_bucket_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = "arn:aws:s3:::your-terraform-state-bucket"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::your-terraform-state-bucket/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/terraform-state-lock"
      }
    ]
  })
}

# Configuration for Dev Environment
# backend.dev.tfbackend:
# bucket         = "your-terraform-state-bucket"
# key            = "aws-infra/dev/terraform.tfstate"
# region         = "us-east-1"
# encrypt        = true
# dynamodb_table = "terraform-state-lock"

# Configuration for Hom Environment
# backend.hom.tfbackend:
# bucket         = "your-terraform-state-bucket"
# key            = "aws-infra/hom/terraform.tfstate"
# region         = "us-east-1"
# encrypt        = true
# dynamodb_table = "terraform-state-lock"

# Configuration for Prod Environment
# backend.prod.tfbackend:
# bucket         = "your-terraform-state-bucket"
# key            = "aws-infra/prod/terraform.tfstate"
# region         = "us-east-1"
# encrypt        = true
# dynamodb_table = "terraform-state-lock"

# Usage:
# terraform init -backend-config=backend.dev.tfbackend
# terraform init -backend-config=backend.hom.tfbackend
# terraform init -backend-config=backend.prod.tfbackend
