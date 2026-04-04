# ALB Module

This module creates and manages an Application Load Balancer (ALB) for AWS infrastructure. It provides secure HTTP/HTTPS routing with automatic redirect capabilities.

## Features

- **Application Load Balancer**: High-performance load balancing for HTTP/HTTPS traffic
- **Target Groups**: Configurable health checks and routing targets
- **Security Groups**: Fine-grained network access control
- **HTTPS Support**: SSL/TLS termination with configurable certificate
- **HTTP Redirect**: Automatic HTTP to HTTPS redirection
- **Access Logging**: Optional ALB access logs to S3
- **Production Protection**: Deletion protection enabled for production environments

## Usage

```hcl
module "alb" {
  source = "../modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  
  container_port      = 8080
  health_check_path   = "/health"
  certificate_arn     = aws_acm_certificate.main.arn
  alb_logs_bucket     = aws_s3_bucket.alb_logs.id

  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| `project_name` | Project name | `string` | Yes | N/A |
| `environment` | Environment (dev, staging, prod) | `string` | Yes | N/A |
| `vpc_id` | VPC ID where ALB will be created | `string` | Yes | N/A |
| `public_subnet_ids` | List of public subnet IDs for ALB | `list(string)` | Yes | N/A |
| `enable_alb` | Enable Application Load Balancer | `bool` | No | `true` |
| `container_port` | Container port for routing and health checks | `number` | No | `80` |
| `health_check_path` | Health check path | `string` | No | `/health` |
| `health_check_matcher` | Health check response codes | `string` | No | `200-299` |
| `alb_logs_bucket` | S3 bucket for ALB access logs | `string` | No | `null` |
| `certificate_arn` | ARN of SSL certificate for HTTPS listener | `string` | No | `null` |
| `tags` | Tags to apply to resources | `map(string)` | No | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `alb_arn` | ARN of the load balancer |
| `alb_dns_name` | DNS name of the load balancer |
| `alb_zone_id` | Zone ID of the load balancer |
| `alb_id` | ID of the load balancer |
| `target_group_arn` | ARN of the target group |
| `target_group_name` | Name of the target group |
| `alb_security_group_id` | Security group ID of the ALB |
| `https_listener_arn` | ARN of HTTPS listener (if certificate provided) |
| `http_listener_arn` | ARN of HTTP listener |

## Security

- HTTP traffic (port 80) is automatically redirected to HTTPS when certificate is provided
- Deletion protection is enabled for production environments
- Invalid headers are dropped for security
- Security group follows least-privilege principle
- ALB access logs are supported for audit trails

## Health Checks

The module configures health checks for the target group:
- **Healthy threshold**: 2 consecutive successful checks
- **Unhealthy threshold**: 3 consecutive failed checks
- **Timeout**: 5 seconds
- **Interval**: 30 seconds
- **Path**: Customizable (default: `/health`)
- **Matcher**: HTTP response codes (default: `200-299`)

## Troubleshooting

### ALB not redirecting HTTP to HTTPS
Ensure `certificate_arn` is provided in the module configuration.

### Target group unhealthy
Check:
1. The `health_check_path` is correct for your application
2. The `container_port` matches your container listening port
3. Security groups allow traffic between ALB and targets
4. Application is running and responding on the health check path

### Access logs not being created
Ensure:
1. S3 bucket exists and is accessible
2. S3 bucket has proper permissions for ALB service
3. `alb_logs_bucket` variable is correctly set

## Module Dependencies

This module depends on:
- VPC module (for VPC ID)
- VPC module (for subnet IDs)
- Optional: AWS Certificate Manager (for certificate_arn)
- Optional: S3 (for ALB logs bucket)
