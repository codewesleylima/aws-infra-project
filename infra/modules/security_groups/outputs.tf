# Outputs for Security Groups Module

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "alb_security_group_arn" {
  description = "ARN of the ALB security group"
  value       = aws_security_group.alb.arn
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = aws_security_group.ecs.id
}

output "ecs_security_group_arn" {
  description = "ARN of the ECS security group"
  value       = aws_security_group.ecs.arn
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "rds_security_group_arn" {
  description = "ARN of the RDS security group"
  value       = aws_security_group.rds.arn
}

output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda.id
}

output "lambda_security_group_arn" {
  description = "ARN of the Lambda security group"
  value       = aws_security_group.lambda.arn
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}

output "vpc_endpoints_security_group_arn" {
  description = "ARN of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.arn
}

output "all_security_group_ids" {
  description = "Map of all security group IDs by name"
  value = {
    alb           = aws_security_group.alb.id
    ecs           = aws_security_group.ecs.id
    rds           = aws_security_group.rds.id
    lambda        = aws_security_group.lambda.id
    vpc_endpoints = aws_security_group.vpc_endpoints.id
  }
}
