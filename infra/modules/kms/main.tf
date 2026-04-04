# ==============================================
# KMS Module - Main Configuration
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
# KMS Key with Automatic Rotation
# ==============================================
resource "aws_kms_key" "main" {
  description             = "KMS key for ${var.project_name}-${var.environment}"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = var.multi_region

  tags = merge(var.tags, {
    Name = "${var.project_name}-key-${var.environment}"
  })
}

# ==============================================
# KMS Key Alias
# ==============================================
resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# ==============================================
# KMS Key Policy (optional custom policy)
# ==============================================
resource "aws_kms_key_policy" "main" {
  count  = var.key_policy != null ? 1 : 0
  key_id = aws_kms_key.main.id
  policy = var.key_policy
}

# ==============================================
# CloudWatch Alarms for Key Usage
# ==============================================
resource "aws_cloudwatch_metric_alarm" "key_usage" {
  count            = var.enable_usage_alarms ? 1 : 0
  alarm_name       = "${var.project_name}-${var.environment}-kms-key-usage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name      = "UserErrorCount"
  namespace        = "AWS/KMS"
  period           = "300"
  statistic        = "Sum"
  threshold        = "10"
  alarm_description = "Alert when KMS key has high error rate"
  alarm_actions    = var.alarm_actions

  dimensions = {
    KeyId = aws_kms_key.main.id
  }
}
