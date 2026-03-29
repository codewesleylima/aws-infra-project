# ==============================================
# ECS Module Outputs
# ==============================================

output "cluster_id" {
  description = "ID do cluster ECS"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN do cluster ECS"
  value       = aws_ecs_cluster.main.arn
}

output "service_id" {
  description = "ID do service ECS"
  value       = aws_ecs_service.main.id
}

output "service_name" {
  description = "Nome do service ECS"
  value       = aws_ecs_service.main.name
}

output "task_definition_arn" {
  description = "ARN da task definition"
  value       = aws_ecs_task_definition.app.arn
}

output "alb_dns_name" {
  description = "DNS name do ALB"
  value       = var.enable_alb ? aws_lb.main[0].dns_name : null
}

output "alb_arn" {
  description = "ARN do ALB"
  value       = var.enable_alb ? aws_lb.main[0].arn : null
}

output "alb_zone_id" {
  description = "Zone ID do ALB para Route53"
  value       = var.enable_alb ? aws_lb.main[0].zone_id : null
}

output "target_group_arn" {
  description = "ARN do Target Group"
  value       = var.enable_alb ? aws_lb_target_group.main[0].arn : null
}

output "ecs_security_group_id" {
  description = "ID do Security Group das tasks ECS"
  value       = aws_security_group.ecs.id
}

output "alb_security_group_id" {
  description = "ID do Security Group do ALB"
  value       = var.enable_alb ? aws_security_group.alb[0].id : null
}

output "execution_role_arn" {
  description = "ARN da role de execução ECS"
  value       = aws_iam_role.ecs_execution.arn
}

output "task_role_arn" {
  description = "ARN da role da task ECS"
  value       = aws_iam_role.ecs_task.arn
}

output "log_group_name" {
  description = "Nome do CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.ecs.name
}
