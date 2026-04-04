# ==============================================
# IAM Module Outputs
# ==============================================

output "github_actions_role_arn" {
  description = "ARN da role para GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Nome da role para GitHub Actions"
  value       = aws_iam_role.github_actions.name
}

output "oidc_provider_arn" {
  description = "ARN do OIDC provider do GitHub"
  value       = aws_iam_openid_connect_provider.github.arn
}
