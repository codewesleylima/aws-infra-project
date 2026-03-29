# ==============================================
# IAM Module Variables
# ==============================================

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "github_org" {
  description = "Organização ou usuário do GitHub"
  type        = string
}

variable "github_repo" {
  description = "Nome do repositório GitHub"
  type        = string
}

variable "terraform_state_bucket" {
  description = "Bucket S3 para Terraform state"
  type        = string
}

variable "terraform_lock_table" {
  description = "Tabela DynamoDB para state locking"
  type        = string
  default     = "terraform-state-lock"
}

variable "allowed_regions" {
  description = "Regiões AWS permitidas"
  type        = list(string)
  default     = ["us-east-1"]
}

variable "tags" {
  description = "Tags comuns"
  type        = map(string)
  default     = {}
}
