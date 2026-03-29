# ==============================================
# Production Environment Outputs
# ==============================================

output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Nome do service ECS"
  value       = module.ecs.service_name
}

output "alb_dns_name" {
  description = "DNS do Application Load Balancer"
  value       = module.ecs.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID do ALB para Route53"
  value       = module.ecs.alb_zone_id
}

output "rds_endpoint" {
  description = "Endpoint do RDS"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "rds_credentials_secret_arn" {
  description = "ARN do secret com credenciais do RDS"
  value       = module.rds.db_credentials_secret_arn
}

output "s3_bucket_name" {
  description = "Nome do bucket S3"
  value       = module.s3_storage.bucket_id
}
