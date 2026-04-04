# Security Groups Module

This module provides centralized security group management for all AWS infrastructure components. It consolidates network access rules into reusable security groups.

## Overview

Managing security groups in a modular fashion reduces sprawl and ensures consistent network policies across environments. This module defines security groups for:

- **ALB**: Load balancer accepting HTTP/HTTPS traffic
- **ECS**: Container tasks accepting traffic from ALB
- **RDS**: Database accepting connections from ECS tasks
- **Lambda**: Lambda functions with outbound internet access
- **VPC Endpoints**: HTTPS access for AWS API endpoints

## Features

- **Centralized Management**: All security group definitions in one place
- **Automatic Dependencies**: Security groups reference each other (ALB → ECS → RDS)
- **Environment-Specific Tagging**: Automatic tags for environment and project identification
- **Validation**: Input validation for VPC IDs, CIDR blocks, and port numbers
- **Lifecycle Management**: Create-before-destroy strategy prevents downtime
- **Flexible Ingress Rules**: Configurable CIDR blocks for ALB access

## Usage

```hcl
module "security_groups" {
  source = "./modules/security_groups"

  project_name         = "myapp"
  environment          = "prod"
  vpc_id              = aws_vpc.main.id
  vpc_cidr            = local.vpc_cidr
  container_port      = 8080
  alb_ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Team      = "platform"
    CostCenter = "engineering"
  }
}
```

Then reference the security groups:

```hcl
module "alb" {
  source = "./modules/alb"

  alb_security_group_id = module.security_groups.alb_security_group_id
  # ... other variables
}

module "ecs" {
  source = "./modules/ecs"

  ecs_security_group_id = module.security_groups.ecs_security_group_id
  # ... other variables
}

module "rds" {
  source = "./modules/rds"

  rds_security_group_id = module.security_groups.rds_security_group_id
  # ... other variables
}
```

## Security Groups

### ALB Security Group

Accepts HTTP (80) and HTTPS (443) traffic from internet, routes to ECS tasks.

**Ingress Rules:**
- Port 80 (HTTP) from `alb_ingress_cidr_blocks` (default: 0.0.0.0/0)
- Port 443 (HTTPS) from `alb_ingress_cidr_blocks` (default: 0.0.0.0/0)

**Egress Rules:**
- All TCP traffic (0-65535) to ECS security group

### ECS Security Group

Accepts traffic from ALB, allows inter-task communication, and outbound to internet.

**Ingress Rules:**
- Application port from ALB security group
- All TCP traffic (0-65535) from self (inter-task communication)

**Egress Rules:**
- All traffic to 0.0.0.0/0 (for pulling images, accessing databases, third-party APIs)

### RDS Security Group

Accepts PostgreSQL (5432) traffic from ECS tasks and read replicas.

**Ingress Rules:**
- Port 5432 (PostgreSQL) from ECS security group
- Port 5432 from self (for read replicas)

**Egress Rules:**
- No outbound rules (RDS is managed by AWS)

### Lambda Security Group

Optional security group for Lambda functions that need VPC access.

**Ingress Rules:**
- None (Lambda doesn't receive inbound traffic)

**Egress Rules:**
- All traffic to 0.0.0.0/0

### VPC Endpoints Security Group

For private access to AWS services (S3, ECR, CloudWatch logs) without internet gateway.

**Ingress Rules:**
- Port 443 (HTTPS) from VPC CIDR

**Egress Rules:**
- Port 443 (HTTPS) to 0.0.0.0/0

## Port Configuration

The module uses a variable `container_port` to set the application port for ECS task ingress. This allows flexibility for different applications:

```hcl
container_port = 8080  # Default in most examples
container_port = 3000  # Node.js applications
container_port = 5000  # Python Flask applications
```

## CIDR Block Management

Control who can access the ALB:

**Allow specific IP ranges:**
```hcl
alb_ingress_cidr_blocks = ["10.0.0.0/8", "203.0.113.0/24"]
```

**Allow internet traffic:**
```hcl
alb_ingress_cidr_blocks = ["0.0.0.0/0"]
```

## Best Practices

1. **Principle of Least Privilege**: Only open ports that are necessary
2. **Environment Isolation**: Use separate VPCs or security groups per environment
3. **Restrict ALB Access**: In production, consider restricting ALB ingress to specific IPs/ranges
4. **Monitor Changes**: CloudTrail logs all security group modifications
5. **Regular Audits**: Review security group rules quarterly for unused rules
6. **Documentation**: Maintain runbooks for common security group modifications

## Cost Considerations

Security groups themselves are **free**. They are a fundamental part of VPC networking and incur no additional charges.

## Troubleshooting

### ECS Tasks Cannot Connect to RDS

- Verify RDS security group allows port 5432 from ECS security group
- Ensure RDS is in the same VPC
- Check RDS status is "available"

### ALB Cannot Route to ECS

- Verify ECS security group allows traffic from ALB on container port
- Check application is listening on specified port
- Verify ALB target group health checks

### Connection Refused Errors

- Check security group rules match the port/protocol being used
- Verify source/destination security groups are correct
- Review CloudTrail logs for any security group modifications

## References

- [AWS VPC Security Groups Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [Security Group Rules Reference](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html#VPCSecurityGroups)
- [EC2 Security Group Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security.html)
