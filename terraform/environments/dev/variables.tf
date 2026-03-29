# ==============================================
# Dev Environment Variables
# ==============================================

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "aws-infra"
}

variable "environment" {
  description = "Ambiente"
  type        = string
  default     = "dev"
}

# VPC
variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidade"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway"
  type        = bool
  default     = true
}

# Database
variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "app"
}

variable "db_username" {
  description = "Username do banco"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "15.4"
}

variable "db_instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

# ECS
variable "container_name" {
  description = "Nome do container"
  type        = string
  default     = "app"
}

variable "container_image" {
  description = "Imagem Docker"
  type        = string
  default     = "nginx:alpine"
}

variable "container_port" {
  description = "Porta do container"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "CPU da task"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memória da task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Número de tasks"
  type        = number
  default     = 1
}
