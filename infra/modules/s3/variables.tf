# ==============================================
# S3 Module Variables
# ==============================================

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "bucket_suffix" {
  description = "Sufixo para o nome do bucket"
  type        = string
  default     = "storage"
}

variable "enable_versioning" {
  description = "Habilitar versionamento"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN da chave KMS para criptografia"
  type        = string
  default     = null
}

variable "enforce_ssl" {
  description = "Forçar conexões SSL"
  type        = bool
  default     = true
}

variable "logging_bucket" {
  description = "Bucket para logs de acesso"
  type        = string
  default     = null
}

variable "lifecycle_rules" {
  description = "Regras de lifecycle"
  type = list(object({
    id                                 = string
    prefix                             = string
    transition_days                    = optional(number)
    transition_storage_class           = optional(string, "GLACIER")
    expiration_days                    = optional(number)
    noncurrent_version_expiration_days = optional(number)
  }))
  default = []
}

variable "cors_rules" {
  description = "Regras CORS"
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3600)
  }))
  default = []
}

variable "bucket_policy" {
  description = "Política customizada do bucket"
  type        = string
  default     = null
}

variable "replication_bucket_arn" {
  description = "ARN do bucket de replicação"
  type        = string
  default     = null
}

variable "replication_kms_key_arn" {
  description = "ARN da chave KMS do bucket de replicação"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags comuns"
  type        = map(string)
  default     = {}
}
