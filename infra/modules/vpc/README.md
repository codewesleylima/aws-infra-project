# VPC Module

This module creates a secure Virtual Private Cloud (VPC) with public and private subnets across multiple availability zones, including NAT gateways and VPC endpoints.

## Overview

The VPC module sets up network infrastructure with:

- **VPC**: Configurable CIDR block for IPv4 addressing
- **Public Subnets**: For ALB and NAT gateways (one per AZ)
- **Private Subnets**: For ECS and RDS (one per AZ)
- **Internet Gateway**: Routes internet traffic for public subnets
- **NAT Gateways**: Enables outbound internet for private subnets
- **Route Tables**: Manages traffic routing for public and private subnets
- **VPC Endpoints**: Reduces data transfer costs for AWS services

## Features

- **Multi-AZ Deployment**: Automatic subnetting across 3 availability zones
- **High Availability**: NAT gateway per AZ eliminates single points of failure
- **Cost Optimization**: VPC endpoints reduce data transfer costs (S3, DynamoDB, ECR, logs)
- **Security First**: Private subnets isolate databases and containers
- **Auto-discovery**: Automatically discovers available AZs in the region
- **Flexible Sizing**: Customizable CIDR blocks for VPC and subnets
- **DNS**: Public DNS enabled for ALB accessibility

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name        = "myapp"
  environment         = "prod"
  aws_region         = "us-east-1"
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = true
  single_nat_gateway = false  # One per AZ for HA

  tags = {
    Team = "platform"
  }
}

# Reference VPC outputs
resource "aws_security_group" "example" {
  vpc_id = module.vpc.vpc_id
  name   = "example-sg"
}
```

## Network Architecture

```
┌─ VPC (10.0.0.0/16) ─────────────────────────┐
│                                               │
│  Public Subnets (10.0.0.0/24, 10.0.1.0/24)  │
│  ├─ ALB                                       │
│  └─ NAT Gateways + EIPs                      │
│                                               │
│  Private Subnets (10.0.10.0/24, etc)        │
│  ├─ ECS Tasks                                │
│  └─ RDS Database (Multi-AZ)                 │
│                                               │
│  ┌─ Internet Gateway (IGW)                   │
│  │ (0.0.0.0/0 → IGW for public subnets)     │
│  └─ NAT Gateways                             │
│    (0.0.0.0/0 → NAT for private subnets)    │
└──────────────────────────────────────────────┘
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_name` | string | - | Project identifier (e.g., "myapp") |
| `environment` | string | - | Environment (dev, staging, prod) |
| `aws_region` | string | - | AWS region (e.g., "us-east-1") |
| `vpc_cidr` | string | `"10.0.0.0/16"` | VPC CIDR block |
| `enable_nat_gateway` | bool | `true` | Create NAT gateways for private subnets |
| `single_nat_gateway` | bool | `false` | Share single NAT across AZs (cost savings) |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr` | VPC CIDR block |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `nat_gateway_ids` | List of NAT gateway IDs |
| `internet_gateway_id` | Internet gateway ID |
| `availability_zones` | List of AZs used |

## Examples

### Standard Production Setup (HA, one NAT per AZ)

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name        = "myapp"
  environment         = "prod"
  aws_region         = "us-east-1"
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = true
  single_nat_gateway = false

  tags = {
    Team       = "platform"
    CostCenter = "engineering"
  }
}
```

**Cost**: ~$105/month (3 NAT gateways @ $35 each)

### Cost-Optimized Development Setup (shared NAT)

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name        = "myapp"
  environment         = "dev"
  aws_region         = "us-east-1"
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = true
  single_nat_gateway = true  # Share NAT across AZs

  tags = {
    Team = "platform"
  }
}
```

**Cost**: ~$35/month (1 NAT gateway shared)

### Without NAT (testing only)

```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name        = "myapp"
  environment         = "test"
  aws_region         = "us-east-1"
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = false  # No internet access for private subnets

  tags = {
    Team = "platform"
  }
}
```

**Cost**: $0 (no NAT gateways)

## Subnet Layout

The module automatically creates subnets in available AZs:

```
Availability Zone a:
├─ Public Subnet:  10.0.0.0/24
└─ Private Subnet: 10.0.10.0/24

Availability Zone b:
├─ Public Subnet:  10.0.1.0/24
└─ Private Subnet: 10.0.11.0/24

Availability Zone c:
├─ Public Subnet:  10.0.2.0/24
└─ Private Subnet: 10.0.12.0/24
```

## Routing Tables

### Public Route Table
- Destination: `0.0.0.0/0`
- Target: Internet Gateway
- Applies to: Public subnets

### Private Route Table
- Destination: `0.0.0.0/0`
- Target: NAT Gateway
- Applies to: Private subnets
- Note: If `enable_nat_gateway = false`, private subnets have no internet access

## VPC Endpoints (Optional)

The module can create VPC endpoints for common AWS services:

```hcl
vpc_endpoints = ["s3", "dynamodb", "ecr.api", "ecr.dkr", "logs", "monitoring"]
```

This reduces data transfer costs by avoiding internet gateway routes.

## Costs

| Component | Cost | Notes |
|-----------|------|-------|
| VPC | FREE | No charge for VPC itself |
| NAT Gateway | $0.045/hour | Per NAT gateway (single-nat-gateway = true saves cost) |
| Elastic IP | $0.005/hour (idle) | Associated with NAT gateway |
| Data transfer | $0.02/GB (out) | For private subnet internet access |
| VPC Endpoints | $0.01/hour each | Optional, save on data transfer |

**Typical costs:**
- Dev (1 NAT): ~$35/month
- Staging (1-3 NAT): ~$35-105/month
- Prod (3 NAT): ~$105/month

## Troubleshooting

### Private subnets have no internet access

Check if NAT gateway is enabled:

```bash
aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=vpc-xxxxx \
  --query 'RouteTables[?Associations[0].Main==`false`].Routes'
```

Look for route with destination `0.0.0.0/0` pointing to NAT gateway.

### Subnets are not in different AZs

Verify AZ auto-discovery:

```bash
aws ec2 describe-availability-zones \
  --region us-east-1 \
  --query 'AvailabilityZones[*].ZoneName'
```

The module automatically uses the available AZs.

## Related Modules

- **security_groups**: Attach to VPC for network access control
- **alb**: Deploy load balancer in public subnets
- **ecs**: Deploy containers in private subnets
- **rds**: Deploy database in private subnets

## References

- [AWS VPC Documentation](https://docs.aws.amazon.com/VPC/)
- [Subnet Sizing](https://docs.aws.amazon.com/VPC/latest/userguide/VPC_Subnets.html)
- [NAT Gateway Best Practices](https://docs.aws.amazon.com/VPC/latest/userguide/vpc-nat-gateway.html)
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
