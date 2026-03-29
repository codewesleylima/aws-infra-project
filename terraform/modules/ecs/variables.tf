# ==============================================
# ECS Module Variables
# ==============================================

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs das subnets públicas (para ALB)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas (para tasks)"
  type        = list(string)
}

# Container Configuration
variable "container_name" {
  description = "Nome do container"
  type        = string
  default     = "app"
}

variable "container_image" {
  description = "Imagem Docker do container"
  type        = string
}

variable "container_port" {
  description = "Porta exposta pelo container"
  type        = number
  default     = 8080
}

# Task Configuration
variable "task_cpu" {
  description = "CPU units para a task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memória em MB para a task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Número desejado de tasks"
  type        = number
  default     = 2
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

variable "health_check_path" {
  description = "Path para health check do ALB"
  type        = string
  default     = "/health"
}

variable "health_check_grace_period" {
  description = "Grace period para health check do service"
  type        = number
  default     = 60
}

# Load Balancer
variable "enable_alb" {
  description = "Habilitar Application Load Balancer"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ARN do certificado SSL para HTTPS"
  type        = string
  default     = null
}

variable "alb_logs_bucket" {
  description = "Bucket S3 para logs do ALB"
  type        = string
  default     = null
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
}

variable "max_capacity" {
  description = "Capacidade máxima para auto scaling"
  type        = number
  default     = 10
}

variable "cpu_target_value" {
  description = "Target de CPU para auto scaling (%)"
  type        = number
  default     = 70
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
}

variable "tags" {
  description = "Tags comuns"
  type        = map(string)
  default     = {}
}
