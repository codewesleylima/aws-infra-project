# ==============================================
# ALB Module - Outputs
# ==============================================

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = try(aws_lb.main[0].arn, null)
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = try(aws_lb.main[0].dns_name, null)
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = try(aws_lb.main[0].zone_id, null)
}

output "alb_id" {
  description = "ID of the load balancer"
  value       = try(aws_lb.main[0].id, null)
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = try(aws_lb_target_group.main[0].arn, null)
}

output "target_group_name" {
  description = "Name of the target group"
  value       = try(aws_lb_target_group.main[0].name, null)
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = try(aws_security_group.alb[0].id, null)
}

output "https_listener_arn" {
  description = "ARN of HTTPS listener (if certificate provided)"
  value       = try(aws_lb_listener.https[0].arn, null)
}

output "http_listener_arn" {
  description = "ARN of HTTP listener"
  value       = try(aws_lb_listener.http[0].arn, null)
}
