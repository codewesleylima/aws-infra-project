# ==============================================
# S3 Module Outputs
# ==============================================

output "bucket_id" {
  description = "ID do bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "ARN do bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "Domain name do bucket"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name do bucket"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}
