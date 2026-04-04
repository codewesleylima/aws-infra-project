# ==============================================
# CloudTrail Module - Main Configuration
# ==============================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==============================================
# S3 Bucket for CloudTrail Logs
# ==============================================
resource "aws_s3_bucket" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = "${var.project_name}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}-${var.environment}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-cloudtrail-logs-${var.environment}"
  })
}

# Enable versioning for audit trail integrity
resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access to logs
resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

# Bucket policy to allow CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs[0].arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Lifecycle rule to delete old logs
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    expiration {
      days = var.s3_log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ==============================================
# CloudTrail Configuration
# ==============================================
resource "aws_cloudtrail" "main" {
  count                          = var.enable_cloudtrail ? 1 : 0
  name                           = "${var.project_name}-trail-${var.environment}"
  s3_bucket_name                 = aws_s3_bucket.cloudtrail_logs[0].id
  include_global_service_events  = var.include_global_service_events
  is_multi_region_trail          = var.is_multi_region_trail
  enable_log_file_validation     = var.enable_log_file_validation
  depends_on                     = [aws_s3_bucket_policy.cloudtrail_logs[0]]

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda:*:*:function/*"]
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-trail-${var.environment}"
  })
}

# ==============================================
# Data Sources
# ==============================================
data "aws_caller_identity" "current" {}
