# ==============================================
# RDS Module Variables
# ==============================================

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  validation {
    condition     = can(regex("^[a-z][-a-z0-9]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with lowercase, contain only alphanumeric and hyphens."
  }
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC ID."
  }
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for RDS."
  }
}

variable "allowed_security_groups" {
  description = "Security groups permitidos a conectar"
  type        = list(string)
}

# Database Configuration
variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "app"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "Database name must start with letter and contain only alphanumeric and underscores."
  }
}

variable "db_username" {
  description = "Username do banco de dados"
  type        = string
  default     = "postgres"
  validation {
    condition     = length(var.db_username) >= 1 && length(var.db_username) <= 16
    error_message = "Database username must be 1-16 characters."
  }
}

variable "engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "15.4"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+", var.engine_version))
    error_message = "Engine version must be in X.Y format."
  }
}

variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.instance_class))
    error_message = "Instance class must be a valid RDS instance type."
  }
}

# Storage
variable "allocated_storage" {
  description = "Storage inicial em GB"
  type        = number
  default     = 20
  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB."
  }
}

variable "max_allocated_storage" {
  description = "Storage máximo para autoscaling em GB"
  type        = number
  default     = 100
  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage
    error_message = "Max allocated storage must be >= allocated storage."
  }
}

# High Availability
variable "multi_az" {
  description = "Habilitar Multi-AZ"
  type        = bool
  default     = false
}

# Backup
variable "backup_retention_period" {
  description = "Dias de retenção de backup"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be 0-35 days."
  }
}

variable "backup_window" {
  description = "Janela de backup (UTC)"
  type        = string
  default     = "03:00-04:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]-([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.backup_window))
    error_message = "Backup window must be in HH:MM-HH:MM format (UTC)."
  }
}

variable "maintenance_window" {
  description = "Janela de manutenção (UTC)"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
  validation {
    condition     = can(regex("^(Mon|Tue|Wed|Thu|Fri|Sat|Sun):[0-2][0-3]:[0-5][0-9]-(Mon|Tue|Wed|Thu|Fri|Sat|Sun):[0-2][0-3]:[0-5][0-9]$", var.maintenance_window))
    error_message = "Maintenance window must be in DDD:HH:MM-DDD:HH:MM format."
  }
}

# Monitoring
variable "enable_performance_insights" {
  description = "Habilitar Performance Insights"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Intervalo de Enhanced Monitoring (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be 0, 1, 5, 10, 15, 30, or 60 minutes."
  }
}

variable "max_connections_threshold" {
  description = "Threshold de conexões para alarme"
  type        = number
  default     = 100
  validation {
    condition     = var.max_connections_threshold > 0
    error_message = "Max connections threshold must be greater than 0."
  }
}

variable "alarm_sns_topic_arn" {
  description = "ARN do tópico SNS para alarmes"
  type        = string
  default     = null
  validation {
    condition     = var.alarm_sns_topic_arn == null || can(regex("^arn:aws:sns:[a-z0-9-]+:[0-9]{12}:[a-zA-Z0-9_-]+$", var.alarm_sns_topic_arn))
    error_message = "SNS topic ARN must be valid."
  }
}

# Security
variable "kms_key_arn" {
  description = "ARN da chave KMS para criptografia"
  type        = string
  default     = null
  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "KMS key ARN must be valid."
  }
}

variable "tags" {
  description = "Tags comuns"
  type        = map(string)
  default     = {}
}
