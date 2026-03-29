# ==============================================
# RDS Module Outputs
# ==============================================

output "db_instance_id" {
  description = "ID da instância RDS"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "ARN da instância RDS"
  value       = aws_db_instance.main.arn
}

output "db_endpoint" {
  description = "Endpoint de conexão do RDS"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "Hostname do RDS"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Porta do RDS"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "Username do banco de dados"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_security_group_id" {
  description = "ID do Security Group do RDS"
  value       = aws_security_group.rds.id
}

output "db_credentials_secret_arn" {
  description = "ARN do secret com credenciais"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
  description = "Nome do secret com credenciais"
  value       = aws_secretsmanager_secret.db_credentials.name
}
