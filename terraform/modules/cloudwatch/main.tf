# CloudWatch Monitoring & Dashboards Module

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================
# Production Infrastructure Dashboard
# ============================================
resource "aws_cloudwatch_dashboard" "production" {
  dashboard_name = "${var.project_name}-prod-overview"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Application Health
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
            [".", "RequestCount", { stat = "Sum" }],
            [".", "HTTPCode_Target_4XX_Count", { stat = "Sum", color = "#ff9900" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum", color = "#ff0000" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ALB Health Metrics"
          yAxis = {
            left  = { min = 0 }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },

      # Row 1: ECS Container Health
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "RunningCount", { stat = "Average" }],
            [".", "DesiredCount", { stat = "Average", color = "#1f77b4" }],
            [".", "PendingCount", { stat = "Average", color = "#ff7f0e" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Task Status"
          yAxis = {
            left  = { min = 0 }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      },

      # Row 2: Database Performance
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", { stat = "Average" }],
            [".", "CPUUtilization", { stat = "Average", color = "#ff0000" }],
            [".", "FreeableMemory", { stat = "Average", color = "#00cc00" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Performance"
          yAxis = {
            left  = { min = 0 }
          }
        }
        width  = 12
        height = 6
        x      = 0
        y      = 6
      },

      # Row 2: Storage & Networking
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "StorageSpace", { stat = "Average" }],
            ["AWS/NatGateway", "BytesOutToDestination", { stat = "Sum" }],
            ["AWS/NatGateway", "BytesInFromDestination", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Storage & Network I/O"
        }
        width  = 12
        height = 6
        x      = 12
        y      = 6
      },

      # Row 3: Application Logs
      {
        type = "log"
        properties = {
          query   = "fields @timestamp, @message | stats count() as ErrorCount by @logStream | filter @message like /ERROR/"
          region  = var.aws_region
          title   = "Application Errors (Last 1 hour)"
        }
        width  = 24
        height = 6
        x      = 0
        y      = 12
      },

      # Row 4: Alarms Status
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/CloudWatch", "AlarmStateValue", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Active Alarms"
        }
        width  = 24
        height = 4
        x      = 0
        y      = 18
      }
    ]
  })
}

# ============================================
# CloudWatch Alarms
# ============================================

# ALB Target Response Time
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.project_name}-prod-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1.0"
  alarm_description   = "Alert when ALB response time exceeds 1 second"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  depends_on = [aws_cloudwatch_dashboard.production]
}

# ECS Task Failure Rate
resource "aws_cloudwatch_metric_alarm" "ecs_task_failures" {
  alarm_name          = "${var.project_name}-prod-high-task-failure-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when 5XX errors exceed 10 in 1 minute"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
}

# RDS High CPU
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project_name}-prod-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when RDS CPU exceeds 80%"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

# RDS Low Available Memory
resource "aws_cloudwatch_metric_alarm" "rds_low_memory" {
  alarm_name          = "${var.project_name}-prod-rds-low-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "300"
  ststistic           = "Average"
  threshold           = "268435456"  # 256 MB
  alarm_description   = "Alert when RDS available memory drops below 256MB"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

# RDS Storage Space
resource "aws_cloudwatch_metric_alarm" "rds_storage_space" {
  alarm_name          = "${var.project_name}-prod-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "10737418240"  # 10 GB
  alarm_description   = "Alert when RDS storage drops below 10GB"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

# ECS Running Task Count
resource "aws_cloudwatch_metric_alarm" "ecs_running_count" {
  alarm_name          = "${var.project_name}-prod-ecs-low-task-count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningCount"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "2"  # Alert if less than 2 tasks running
  alarm_description   = "Alert when ECS running count drops below desired"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
}

# NAT Gateway Error Port Allocation
resource "aws_cloudwatch_metric_alarm" "nat_gateway_error_port_alloc" {
  alarm_name          = "${var.project_name}-prod-nat-port-allocation-error"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ErrorPortAllocation"
  namespace           = "AWS/NatGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert when NAT Gateway port allocation errors occur"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
}

# ============================================
# CloudWatch Log Groups
# ============================================

resource "aws_cloudwatch_log_group" "ecs_app" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-ecs-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "rds" {
  name              = "/rds/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-rds-logs"
    Environment = var.environment
  }
}

# ============================================
# CloudWatch Metric Filters
# ============================================

resource "aws_cloudwatch_log_group_metric_filter" "application_errors" {
  name           = "${var.project_name}-errors"
  log_group_name = aws_cloudwatch_log_group.ecs_app.name
  filter_pattern = "[ERROR]"

  metric_transformation {
    name      = "ApplicationErrorCount"
    namespace = "CustomMetrics/${var.project_name}"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_group_metric_filter" "high_latency" {
  name           = "${var.project_name}-high-latency"
  log_group_name = aws_cloudwatch_log_group.ecs_app.name
  filter_pattern = "[..., latency > 1000]"

  metric_transformation {
    name      = "HighLatencyRequests"
    namespace = "CustomMetrics/${var.project_name}"
    value     = "1"
  }
}
