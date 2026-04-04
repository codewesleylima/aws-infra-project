# ==============================================
# ALB Module - Main Configuration
# ==============================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==============================================
# Security Group for ALB
# ==============================================
resource "aws_security_group" "alb" {
  count       = var.enable_alb ? 1 : 0
  name_prefix = "${var.project_name}-alb-${var.environment}-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # Allow HTTPS traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS inbound traffic"
  }

  # Allow HTTP traffic (will be redirected to HTTPS)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP inbound traffic (redirects to HTTPS)"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-sg-${var.environment}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================
# Application Load Balancer
# ==============================================
resource "aws_lb" "main" {
  count              = var.enable_alb ? 1 : 0
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids

  # Enable deletion protection for production
  enable_deletion_protection = var.environment == "prod"
  
  # Drop invalid headers for security
  drop_invalid_header_fields = true

  # Enable access logs if bucket is provided
  dynamic "access_logs" {
    for_each = var.alb_logs_bucket != null ? [1] : []
    content {
      bucket  = var.alb_logs_bucket
      prefix  = "alb/${var.project_name}-${var.environment}"
      enabled = true
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-${var.environment}"
  })
}

# ==============================================
# ALB Target Group
# ==============================================
resource "aws_lb_target_group" "main" {
  count       = var.enable_alb ? 1 : 0
  name        = "${var.project_name}-tg-${var.environment}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = var.health_check_matcher
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-tg-${var.environment}"
  })
}

# ==============================================
# ALB HTTPS Listener (when certificate is provided)
# ==============================================
resource "aws_lb_listener" "https" {
  count             = var.enable_alb && var.certificate_arn != null ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }
}

# ==============================================
# ALB HTTP Listener (redirect to HTTPS)
# ==============================================
resource "aws_lb_listener" "http" {
  count             = var.enable_alb ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"

  # If certificate exists, redirect to HTTPS; otherwise forward to target group
  default_action {
    type = var.certificate_arn != null ? "redirect" : "forward"
    
    # Redirect to HTTPS when certificate is available
    dynamic "redirect" {
      for_each = var.certificate_arn != null ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    
    # Forward to target group when no certificate (HTTP only)
    target_group_arn = var.certificate_arn == null ? aws_lb_target_group.main[0].arn : null
  }
}
