# ==============================================
# KMS Module - Outputs
# ==============================================

output "key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.main.key_id
}

output "key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.main.arn
}

output "alias_name" {
  description = "KMS key alias name"
  value       = aws_kms_alias.main.name
}

output "key_usage" {
  description = "KMS key usage (ENCRYPT_DECRYPT or SIGN_VERIFY)"
  value       = aws_kms_key.main.key_usage
}
