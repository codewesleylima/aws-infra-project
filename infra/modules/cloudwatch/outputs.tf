# CloudWatch Module Outputs

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.production.dashboard_arn
}

output "dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.production.dashboard_name}"
}

output "log_group_arn" {
  description = "ARN of the ECS application log group"
  value       = aws_cloudwatch_log_group.ecs_app.arn
}

output "log_group_name" {
  description = "Name of the ECS application log group"
  value       = aws_cloudwatch_log_group.ecs_app.name
}

output "rds_log_group_arn" {
  description = "ARN of the RDS log group"
  value       = aws_cloudwatch_log_group.rds.arn
}

output "alarm_arns" {
  description = "ARNs of all configured alarms"
  value = {
    alb_response_time              = aws_cloudwatch_metric_alarm.alb_response_time.arn
    ecs_task_failures              = aws_cloudwatch_metric_alarm.ecs_task_failures.arn
    rds_cpu_high                   = aws_cloudwatch_metric_alarm.rds_cpu_high.arn
    rds_low_memory                 = aws_cloudwatch_metric_alarm.rds_low_memory.arn
    rds_storage_space              = aws_cloudwatch_metric_alarm.rds_storage_space.arn
    ecs_running_count              = aws_cloudwatch_metric_alarm.ecs_running_count.arn
    nat_gateway_error_port_alloc   = aws_cloudwatch_metric_alarm.nat_gateway_error_port_alloc.arn
  }
}
