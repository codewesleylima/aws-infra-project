# ==============================================
# CloudTrail Module - Variables
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

variable "enable_cloudtrail" {
  description = "Enable CloudTrail logging"
  type        = bool
  default     = true
}

variable "enable_log_file_validation" {
  description = "Enable CloudTrail log file validation"
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "Include global service events (CloudFront, IAM, etc)"
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "Create a multi-region CloudTrail"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting CloudTrail logs (optional)"
  type        = string
  default     = null
}

variable "s3_log_retention_days" {
  description = "Number of days to retain S3 logs before deletion"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
