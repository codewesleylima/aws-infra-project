# ==============================================
# ECS Module Variables
# ==============================================

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  validation {
    condition     = can(regex("^[a-z][-a-z0-9]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with lowercase and contain only alphanumeric and hyphens."
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

variable "aws_region" {
  description = "Região AWS"
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be a valid region code."
  }
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "VPC ID must be valid."
  }
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas (para tasks)"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets required."
  }
}

# Container Configuration
variable "container_name" {
  description = "Nome do container"
  type        = string
  default     = "app"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.container_name))
    error_message = "Container name must contain only alphanumeric, underscore, and hyphen."
  }
}

variable "container_image" {
  description = "Imagem Docker do container"
  type        = string
  validation {
    condition     = length(var.container_image) > 0
    error_message = "Container image  must not be empty."
  }
}

variable "container_port" {
  description = "Porta exposta pelo container"
  type        = number
  default     = 8080
  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

# Task Configuration
variable "task_cpu" {
  description = "CPU units para a task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "Task CPU must be 256, 512, 1024, 2048, or 4096."
  }
}

variable "task_memory" {
  description = "Memória em MB para a task"
  type        = number
  default     = 512
  validation {
    condition     = var.task_memory >= 512 && var.task_memory <= 30720 && var.task_memory % 128 == 0
    error_message = "Task memory must be 512-30720 MB in 128 MB increments."
  }
}

variable "desired_count" {
  description = "Número desejado de tasks"
  type        = number
  default     = 2
  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 100
    error_message = "Desired count must be 1-100."
  }
}

# Environment & Secrets
variable "environment_variables" {
  description = "Variáveis de ambiente para o container"
  type        = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "Secrets do Secrets Manager para o container"
  type        = list(object({
    name       = string
    value_from = string
  }))
  default = []
}

# Health Check
variable "health_check" {
  description = "Configuração de health check do container"
  type = object({
    command      = list(string)
    interval     = number
    timeout      = number
    retries      = number
    start_period = number
  })
  default = null
}

variable "health_check_grace_period" {
  description = "Grace period para health check do service"
  type        = number
  default     = 60
  validation {
    condition     = var.health_check_grace_period >= 0 && var.health_check_grace_period <= 2147483647
    error_message = "Health check grace period must be >= 0."
  }
}

# Load Balancer
variable "alb_target_group_arn" {
  description = "ARN do target group do ALB (quando ALB está habilitado)"
  type        = string
  default     = null
  validation {
    condition     = var.alb_target_group_arn == null || can(regex("^arn:aws:elasticloadbalancing:[a-z0-9-]+:[0-9]{12}:targetgroup/.+$", var.alb_target_group_arn))
    error_message = "ALB target group ARN must be valid."
  }
}

variable "alb_security_group_id" {
  description = "ID do security group do ALB para permitir tráfego"
  type        = string
  default     = null
  validation {
    condition     = var.alb_security_group_id == null || can(regex("^sg-[a-f0-9]+$", var.alb_security_group_id))
    error_message = "ALB security group ID must be valid."
  }
}

# Auto Scaling
variable "enable_autoscaling" {
  description = "Habilitar auto scaling"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Capacidade mínima para auto scaling"
  type        = number
  default     = 1
  validation {
    condition     = var.min_capacity >= 1 && var.min_capacity <= 100
    error_message = "Min capacity must be 1-100."
  }
}

variable "max_capacity" {
  description = "Capacidade máxima para auto scaling"
  type        = number
  default     = 10
  validation {
    condition     = var.max_capacity >= 1 && var.max_capacity <= 100
    error_message = "Max capacity must be between 1 and 100."
  }
}

variable "cpu_target_value" {
  description = "Target de CPU para auto scaling (%)"
  type        = number
  default     = 70
  validation {
    condition     = var.cpu_target_value > 0 && var.cpu_target_value <= 100
    error_message = "CPU target value must be 1-100%."
  }
}

# Logging & Monitoring
variable "enable_container_insights" {
  description = "Habilitar Container Insights"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs"
  type        = number
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention value."
  }
}

variable "enable_execute_command" {
  description = "Habilitar ECS Exec para debugging"
  type        = bool
  default     = false
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
