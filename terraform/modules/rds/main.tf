# ==============================================
# RDS PostgreSQL Module
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
}

# ----------------------------------------------
# Random Password
# ----------------------------------------------
resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ----------------------------------------------
# Secrets Manager
# ----------------------------------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/${var.environment}/rds/credentials"
  description             = "RDS PostgreSQL credentials"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = var.kms_key_arn

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
    engine   = "postgresql"
  })
}

# ----------------------------------------------
# DB Subnet Group
# ----------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  })
}

# ----------------------------------------------
# Security Group
# ----------------------------------------------
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-${var.environment}-"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
    description     = "Allow PostgreSQL from allowed security groups"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rds-sg-${var.environment}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ----------------------------------------------
# Parameter Group
# ----------------------------------------------
resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-pg${replace(var.engine_version, ".", "")}"
  family = "postgres${split(".", var.engine_version)[0]}"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ----------------------------------------------
# RDS Instance
# ----------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}"

  # Engine
  engine               = "postgres"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  parameter_group_name = aws_db_parameter_group.main.name

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result
  port     = 5432

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  # Backup
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  copy_tags_to_snapshot     = true
  delete_automated_backups  = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-${var.environment}-final-snapshot" : null
  skip_final_snapshot       = var.environment != "prod"

  # Monitoring
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null
  performance_insights_kms_key_id       = var.enable_performance_insights ? var.kms_key_arn : null
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  # Security
  iam_database_authentication_enabled = true
  deletion_protection                 = var.environment == "prod"

  # Updates
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = var.environment != "prod"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds"
  })

  lifecycle {
    prevent_destroy = false
  }
}

# ----------------------------------------------
# Enhanced Monitoring Role
# ----------------------------------------------
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.project_name}-${var.environment}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ----------------------------------------------
# CloudWatch Alarms
# ----------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization high"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "storage" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5GB in bytes
  alarm_description   = "RDS free storage space low"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "connections" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.max_connections_threshold
  alarm_description   = "RDS connections high"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = var.tags
}
