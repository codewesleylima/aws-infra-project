# ==============================================
# KMS Module - Variables
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

variable "enable_key_rotation" {
  description = "Enable automatic KMS key rotation (recommended: true for prod)"
  type        = bool
  default     = true
}

variable "rotation_period_in_days" {
  description = "KMS key rotation period in days (365 days = 1 year)"
  type        = number
  default     = 365
  validation {
    condition     = var.rotation_period_in_days >= 90 && var.rotation_period_in_days <= 2920
    error_message = "Rotation period must be between 90 and 2920 days (1-8 years)."
  }
}

variable "deletion_window_in_days" {
  description = "KMS key deletion grace period in days"
  type        = number
  default     = 30
  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "Deletion window must be between 7 and 30 days."
  }
}

variable "multi_region" {
  description = "Create a multi-region primary key (for prod)"
  type        = bool
  default     = false
}

variable "enable_usage_alarms" {
  description = "Enable CloudWatch alarms for KMS key usage"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

variable "key_policy" {
  description = "Custom KMS key policy (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
