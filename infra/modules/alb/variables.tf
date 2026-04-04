# ==============================================
# ALB Module - Variables
# ==============================================

variable "project_name" {
  description = "Project name"
  type        = string
  validation {
    condition     = can(regex("^[a-z][-a-z0-9]*$", var.project_name))
    error_message = "Project name must start with lowercase and contain only alphanumeric and hyphens."
  }
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "enable_alb" {
  description = "Enable Application Load Balancer"
  type        = bool
  default     = true
}

variable "container_port" {
  description = "Container port for target group health checks and routing"
  type        = number
  default     = 80
  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/health"
}

variable "health_check_matcher" {
  description = "Health check HTTP response codes"
  type        = string
  default     = "200-299"
}

variable "alb_logs_bucket" {
  description = "S3 bucket for ALB access logs (optional)"
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ARN of SSL certificate for HTTPS listener (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
