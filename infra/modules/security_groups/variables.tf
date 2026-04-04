# Variables for Security Groups Module

variable "project_name" {
  description = "Name of the project"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with a lowercase letter, contain only lowercase letters, numbers, and hyphens, and end with a lowercase letter or number."
  }

  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 30
    error_message = "Project name must be between 3 and 30 characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC ID (vpc-*)."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block (used for VPC endpoint rules)"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "container_port" {
  description = "Port on which containers listen"
  type        = number

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB (default allows all internet traffic)"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.alb_ingress_cidr_blocks) > 0
    error_message = "At least one CIDR block must be specified."
  }

  validation {
    condition = alltrue([
      for cidr in var.alb_ingress_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All ALB ingress CIDR blocks must be valid CIDR notation."
  }
}

variable "tags" {
  description = "Tags to apply to all security groups"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.tags : length(k) <= 128 && length(v) <= 256
    ])
    error_message = "Tag keys must be <= 128 characters and values <= 256 characters."
  }
}

variable "enable_vpc_endpoints_sg" {
  description = "Whether to create a security group for VPC endpoints"
  type        = bool
  default     = true
}
