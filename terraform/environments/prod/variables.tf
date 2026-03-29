# ==============================================
# Production Environment Variables
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

variable "container_image" {
  description = "Imagem Docker para produção"
  type        = string
}
