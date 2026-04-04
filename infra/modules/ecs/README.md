# ECS Module

This module creates an Elastic Container Service (ECS) cluster with Fargate launch type, including task definitions, services, and Auto Scaling configuration.

## Overview

The ECS module provides:

- **ECS Cluster**: Logical grouping of container resources
- **Task Definition**: Application container configuration (image, CPU, memory, environment variables)
- **ECS Service**: Long-running tasks with load balancer integration
- **Auto Scaling**: Dynamic scaling based on CPU/memory metrics
- **Health Checks**: Integration with ALB health checks
- **CloudWatch Logs**: Centralized container logs
- **IAM Roles**: Least-privilege access for tasks

## Features

- **Fargate Launch Type**: Serverless containers (no EC2 instances to manage)
- **Multi-AZ Deployment**: Tasks distributed across availability zones
- **Canary Deployments**: Gradual rollouts with auto-rollback
- **Auto Scaling**: CPU and memory-based scale up/down
- **Health Monitoring**: ELB health checks integration
- **Logging**: CloudWatch logs for troubleshooting
- **Container Insights**: Optional detailed ECS metrics
- **Graceful Shutdown**: Connection draining (30s default)

## Usage

```hcl
module "ecs" {
  source = "./modules/ecs"

  project_name      = "myapp"
  environment       = "prod"
  cluster_name      = "prod-cluster"
  service_name      = "myapp-service"
  
  container_image   = "myapp:v1.2.3"
  container_port    = 8080
  
  ecs_task_cpu      = "1024"      # 1 vCPU
  ecs_task_memory   = "2048"      # 2GB
  desired_count     = 3            # 3 running tasks
  
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  target_group_arn  = module.alb.target_group_arn
  security_group_id = module.security_groups.ecs_security_group_id

  # Auto scaling
  enable_autoscaling = true
  autoscale_min_count = 2
  autoscale_max_count = 10
  autoscale_target_cpu = 70

  tags = {
    Team = "platform"
  }
}
```

## Architecture

```
┌─ ECS Cluster ────────────────────────────┐
│                                           │
│  ┌─ Task Definition ─────────────────┐  │
│  │ Image: myapp:v1.2.3              │  │
│  │ CPU: 1024 (1 vCPU)              │  │
│  │ Memory: 2048 (2GB)              │  │
│  │ Port: 8080                       │  │
│  └──────────────────────────────────┘  │
│                                           │
│  ┌─ ECS Service ─────────────────────┐  │
│  │ Desired Count: 3                  │  │
│  │ Launch Type: Fargate              │  │
│  │ Deployment Type: Rolling          │  │
│  │                                    │  │
│  │  ┌─ Task 1 (AZ-a) ──────┐        │  │
│  │  │ Running, Healthy      │        │  │
│  │  └───────────────────────┘        │  │
│  │                                    │  │
│  │  ┌─ Task 2 (AZ-b) ──────┐        │  │
│  │  │ Running, Healthy      │        │  │
│  │  └───────────────────────┘        │  │
│  │                                    │  │
│  │  ┌─ Task 3 (AZ-c) ──────┐        │  │
│  │  │ Running, Healthy      │        │  │
│  │  └───────────────────────┘        │  │
│  └──────────────────────────────────┘  │
│                                           │
│  ┌─ Auto Scaling ────────────────────┐  │
│  │ Min: 2 tasks                      │  │
│  │ Max: 10 tasks                     │  │
│  │ Target CPU: 70%                  │  │
│  └──────────────────────────────────┘  │
└───────────────────────────────────────────┘
         ↓
    ┌─ ALB ─────┐
    │ Port 80   │
    │ Port 443  │
    └───────────┘
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_name` | string | - | Project identifier |
| `environment` | string | - | Environment (dev, staging, prod) |
| `cluster_name` | string | - | ECS cluster name |
| `service_name` | string | - | ECS service name |
| `container_image` | string | - | Docker image (e.g., "myapp:v1.2.3") |
| `container_port` | number | 8080 | Container port |
| `ecs_task_cpu` | string | "256" | Task CPU (256, 512, 1024, 2048, 4096) |
| `ecs_task_memory` | string | "512" | Task memory (512-30GB) |
| `desired_count` | number | 1 | Number of running tasks |
| `enable_autoscaling` | bool | true | Enable Auto Scaling |
| `autoscale_min_count` | number | 1 | Minimum tasks |
| `autoscale_max_count` | number | 5 | Maximum tasks |
| `autoscale_target_cpu` | number | 70 | Target CPU percentage |
| `vpc_id` | string | - | VPC ID |
| `private_subnet_ids` | list(string) | - | Private subnet IDs for tasks |
| `target_group_arn` | string | - | ALB target group ARN |
| `security_group_id` | string | - | Security group for tasks |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_name` | ECS cluster name |
| `cluster_arn` | ECS cluster ARN |
| `service_name` | ECS service name |
| `service_arn` | ECS service ARN |
| `task_definition_arn` | Task definition ARN |
| `task_role_arn` | IAM task role ARN |
| `execution_role_arn` | IAM execution role ARN |

## Deployment Options

### Canary Deployment (Gradual Rollout)

```hcl
# Default configuration in module
deployment_circuit_breaker {
  enable   = true
  rollback = true  # Auto-rollback on > 50% failure
}

deployment_configuration {
  minimum_healthy_percent = 90  # Keep 90% running
  maximum_percent         = 110  # Start 10% new tasks
}

# Result: Gradual replacement, automatic rollback if issues
```

### Blue-Green Deployment (Testing)

```hcl
# Create second service for testing
resource "aws_ecs_service" "myapp_green" {
  task_definition = aws_ecs_task_definition.new_version.arn
  desired_count   = 1  # Test with 1 task
}

# After testing, switch traffic and scale down blue
```

## Scaling Configurations

### Development (Cost Optimized)

```hcl
module "ecs" {
  # ...
  ecs_task_cpu    = "256"
  ecs_task_memory = "512"
  desired_count   = 1
  enable_autoscaling = false  # No scaling for dev
}
# Cost: ~$50/month
```

### Staging (Production-like)

```hcl
module "ecs" {
  # ...
  ecs_task_cpu    = "512"
  ecs_task_memory = "1024"
  desired_count   = 2
  enable_autoscaling = true
  autoscale_min_count = 2
  autoscale_max_count = 5
  autoscale_target_cpu = 70
}
# Cost: ~$100-150/month
```

### Production (Maximum Availability)

```hcl
module "ecs" {
  # ...
  ecs_task_cpu    = "1024"
  ecs_task_memory = "2048"
  desired_count   = 3
  enable_autoscaling = true
  autoscale_min_count = 3
  autoscale_max_count = 20
  autoscale_target_cpu = 70
}
# Cost: ~$250-350/month (baseline)
```

## Monitoring

### CloudWatch Metrics

```bash
# View CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=myapp-service Name=ClusterName,Value=prod-cluster \
  --statistics Average,Maximum \
  --period 3600 \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z
```

### View Logs

```bash
aws logs tail /ecs/myapp-prod --follow
```

### Describe Service Status

```bash
aws ecs describe-services \
  --cluster prod-cluster \
  --services myapp-service \
  --query 'services[0].[serviceName, status, runningCount, desiredCount]'
```

## Troubleshooting

### Tasks keep stopping

Check logs:

```bash
aws logs tail /ecs/myapp-prod --follow
```

Common causes:
- Application crash (out of memory, unhandled exception)
- Insufficient CPU or memory allocated
- Health check failing

### Can't connect to container

Verify security group:

```bash
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --query 'SecurityGroups[0].IpPermissions'
```

Ensure:
- ALB security group allows traffic to ECS
- ECS security group allows traffic from ALB

### Scaling not working

Check CloudWatch alarms:

```bash
aws cloudwatch describe-alarms \
  --alarm-names ecs-high-cpu
```

Verify:
- Target group is healthy
- Metrics are being published
- Scaling is enabled in service configuration

## Related Modules

- **vpc**: Provides private subnets for ECS tasks
- **alb**: Load balancer for traffic distribution
- **security_groups**: Network access control for ECS tasks
- **iam**: IAM roles for task and execution permissions
- **cloudwatch**: Monitoring and logging (integrated)

## References

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [Task Definitions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html)
- [ECS Auto Scaling](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html)
