# ==============================================
# IAM Module - GitHub Actions OIDC
# ==============================================
# This module creates IAM roles for GitHub Actions
# using OIDC (no static credentials needed)

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ----------------------------------------------
# GitHub OIDC Provider
# ----------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = var.tags
}

# ----------------------------------------------
# IAM Role for GitHub Actions
# ----------------------------------------------
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = var.tags
}

# ----------------------------------------------
# Terraform State Access Policy
# ----------------------------------------------
resource "aws_iam_role_policy" "terraform_state" {
  name = "${var.project_name}-${var.environment}-terraform-state"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket}",
          "arn:aws:s3:::${var.terraform_state_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.terraform_lock_table}"
      }
    ]
  })
}

# ----------------------------------------------
# Infrastructure Management Policy
# ----------------------------------------------
resource "aws_iam_role_policy" "infrastructure" {
  name = "${var.project_name}-${var.environment}-infrastructure"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # VPC Management
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:DescribeVpcs",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:DescribeSubnets",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:DescribeInternetGateways",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:DescribeNatGateways",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:DescribeAddresses",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:DescribeRouteTables",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateFlowLogs",
          "ec2:DeleteFlowLogs",
          "ec2:DescribeFlowLogs",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeAccountAttributes"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.allowed_regions
          }
        }
      },
      # ECS Management
      {
        Effect = "Allow"
        Action = [
          "ecs:CreateCluster",
          "ecs:DeleteCluster",
          "ecs:DescribeClusters",
          "ecs:UpdateCluster",
          "ecs:CreateService",
          "ecs:DeleteService",
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:PutClusterCapacityProviders",
          "ecs:TagResource",
          "ecs:UntagResource"
        ]
        Resource = "*"
      },
      # RDS Management
      {
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:CreateDBParameterGroup",
          "rds:DeleteDBParameterGroup",
          "rds:DescribeDBParameterGroups",
          "rds:ModifyDBParameterGroup",
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      # S3 Management
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketEncryption",
          "s3:PutBucketEncryption",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketLogging",
          "s3:PutBucketLogging",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetBucketCORS",
          "s3:PutBucketCORS",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      },
      # Secrets Manager
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:TagResource"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/*"
      },
      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:CreateLogStream",
          "logs:DeleteLogStream"
        ]
        Resource = "*"
      },
      # IAM (limited)
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/${var.project_name}-*"
        ]
      },
      # Elastic Load Balancing
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = "*"
      },
      # Auto Scaling
      {
        Effect = "Allow"
        Action = [
          "application-autoscaling:RegisterScalableTarget",
          "application-autoscaling:DeregisterScalableTarget",
          "application-autoscaling:DescribeScalableTargets",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:DeleteScalingPolicy",
          "application-autoscaling:DescribeScalingPolicies"
        ]
        Resource = "*"
      },
      # CloudWatch Alarms
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      }
    ]
  })
}
