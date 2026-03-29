# ==============================================
# VPC Module Variables
# ==============================================

variable "project_name" {
  description = "Nome do projeto para identificação dos recursos"
  type        = string
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment deve ser: dev, staging ou prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block para a VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR deve ser um bloco CIDR válido."
  }
}

variable "availability_zones" {
  description = "Lista de Availability Zones para usar"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway para subnets privadas"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Habilitar VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Dias de retenção para Flow Logs no CloudWatch"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "ARN da chave KMS para criptografia (opcional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags comuns para todos os recursos"
  type        = map(string)
  default     = {}
}
