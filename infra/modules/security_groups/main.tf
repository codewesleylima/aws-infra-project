# AWS Security Groups Module
# Centralized security group management for standardized network policies

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================
# ALB Security Group
# ============================================
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "Security group for ${var.project_name} ALB in ${var.environment}"
  vpc_id      = var.vpc_id

  # Inbound: HTTP
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidr_blocks
  }

  # Inbound: HTTPS
  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidr_blocks
  }

  # Outbound: All traffic to VPC
  egress {
    description     = "All traffic to VPC"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-alb-sg"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# ECS Security Group
# ============================================
resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-ecs-"
  description = "Security group for ${var.project_name} ECS tasks in ${var.environment}"
  vpc_id      = var.vpc_id

  # Inbound: From ALB
  ingress {
    description     = "Traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Inbound: Self-referencing for inter-task communication
  ingress {
    description = "Traffic between ECS tasks"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Outbound: All traffic (for pulling images, accessing databases, etc.)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-ecs-sg"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# RDS Security Group
# ============================================
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  description = "Security group for ${var.project_name} RDS database in ${var.environment}"
  vpc_id      = var.vpc_id

  # Inbound: From ECS tasks
  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Inbound: From same security group (read replicas)
  ingress {
    description = "From same security group"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }

  # Egress: None needed for RDS (managed by AWS)
  egress {
    description = "No outbound rules required for RDS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-rds-sg"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# Lambda Security Group (for CloudFormation logs processor, etc.)
# ============================================
resource "aws_security_group" "lambda" {
  name_prefix = "${var.project_name}-lambda-"
  description = "Security group for ${var.project_name} Lambda functions in ${var.environment}"
  vpc_id      = var.vpc_id

  # Outbound: All traffic (for API calls, database access, etc.)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-lambda-sg"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# VPC Endpoint Security Group (for private S3/ECR access)
# ============================================
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-vpce-"
  description = "Security group for ${var.project_name} VPC endpoints in ${var.environment}"
  vpc_id      = var.vpc_id

  # Inbound: HTTPS from VPC
  ingress {
    description = "HTTPS from VPC for API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Egress: Minimal (mainly for internal communication)
  egress {
    description = "Allow outbound HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-vpce-sg"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
