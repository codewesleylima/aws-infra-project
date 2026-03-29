# ==============================================
# VPC Module Variables
# ==============================================

variable "project_name" {
  description = "Nome do projeto para identificação dos recursos"
  type        = string
  validation {
    condition     = can(regex("^[a-z][-a-z0-9]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with lowercase, contain only alphanumeric and hyphens, and not end with hyphen."
  }
  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 32
    error_message = "Project name must be between 3 and 32 characters."
  }
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
  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) <= 28
    error_message = "VPC CIDR must have /28 or larger subnet mask."
  }
}

variable "availability_zones" {
  description = "List of availability zones to use (leave empty to auto-discover)"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) >= 2
    error_message = "Either specify no AZs (auto-discover) or at least 2."
  }
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
  validation {
    condition     = var.flow_logs_retention_days > 0
    error_message = "Flow logs retention days must be greater than 0."
  }
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_logs_retention_days)
    error_message = "Flow logs retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "kms_key_arn" {
  description = "ARN da chave KMS para criptografia (opcional)"
  type        = string
  default     = null
  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid ARN format."
  }
}

variable "tags" {
  description = "Tags comuns para todos os recursos"
  type        = map(string)
  default     = {}
  validation {
    condition     = length(var.tags) == 0 || alltrue([for k in keys(var.tags) : length(k) >= 1 && length(k) <= 128])
    error_message = "All tag keys must be between 1 and 128 characters."
  }
}
