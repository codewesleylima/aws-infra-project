# ==============================================
# Staging Environment Outputs
# ==============================================

output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = module.ecs.cluster_name
}

output "alb_dns_name" {
  description = "DNS do ALB"
  value       = module.ecs.alb_dns_name
}

output "rds_endpoint" {
  description = "Endpoint do RDS"
  value       = module.rds.db_endpoint
  sensitive   = true
}
