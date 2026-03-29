# ==============================================
# RDS Module Variables
# ==============================================

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas"
  type        = list(string)
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
}

variable "db_username" {
  description = "Username do banco de dados"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

# Storage
variable "allocated_storage" {
  description = "Storage inicial em GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage máximo para autoscaling em GB"
  type        = number
  default     = 100
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
}

variable "backup_window" {
  description = "Janela de backup (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Janela de manutenção (UTC)"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
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
}

variable "max_connections_threshold" {
  description = "Threshold de conexões para alarme"
  type        = number
  default     = 100
}

variable "alarm_sns_topic_arn" {
  description = "ARN do tópico SNS para alarmes"
  type        = string
  default     = null
}

# Security
variable "kms_key_arn" {
  description = "ARN da chave KMS para criptografia"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags comuns"
  type        = map(string)
  default     = {}
}
