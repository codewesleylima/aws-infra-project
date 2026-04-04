# ==============================================
# CloudTrail Module - Outputs
# ==============================================

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = try(aws_cloudtrail.main[0].arn, null)
}

output "cloudtrail_home_region" {
  description = "Home region of the CloudTrail"
  value       = try(aws_cloudtrail.main[0].home_region, null)
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  value       = try(aws_s3_bucket.cloudtrail_logs[0].id, null)
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for CloudTrail logs"
  value       = try(aws_s3_bucket.cloudtrail_logs[0].arn, null)
}
