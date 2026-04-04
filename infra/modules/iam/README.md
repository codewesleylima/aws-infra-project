# IAM Module

This module creates Identity and Access Management (IAM) roles, policies, and configurations following the principle of least privilege.

## Overview

The IAM module provides:

- **Task Execution Role**: ECS task execution permissions (pull image, write logs)
- **Task Role**: Application permissions (S3, secrets, DynamoDB, etc.)
- **Service Role**: RDS and other AWS service permissions
- **Policy Attachment**: Fine-grained permission management
- **Trust Relationships**: Cross-service access control
- **Session Duration**: Security-focused session limits

## Features

- **Least Privilege**: Minimal permissions required for operation
- **Environment-Specific**: Separate roles per environment (dev, staging, prod)
- **Service-Specific**: Dedicated roles for ECS, RDS, Lambda, etc.
- **Audit Trail**: CloudTrail integration for access logging
- **Session Security**: Short-lived credentials and session tokens
- **Inline and Managed Policies**: Mix of AWS managed and custom policies
- **Cross-Account Access**: Support for multi-account scenarios

## Usage

```hcl
module "iam" {
  source = "./modules/iam"

  project_name = "myapp"
  environment  = "prod"

  # ECS task permissions
  enable_ecs_task_role = true
  ecs_task_permissions = [
    "s3:GetObject",
    "s3:ListBucket",
    "dynamodb:Query",
    "secretsmanager:GetSecretValue",
    "kms:Decrypt"
  ]

  # Resources the task can access
  allowed_s3_buckets = [
    "arn:aws:s3:::myapp-data/*",
    "arn:aws:s3:::myapp-uploads/*"
  ]

  allowed_secrets = [
    "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:myapp/*"
  ]

  tags = {
    Team = "platform"
  }
}

# Reference in ECS module
module "ecs" {
  # ...
  task_role_arn = module.iam.task_role_arn
  execution_role_arn = module.iam.execution_role_arn
}
```

## IAM Architecture

```
┌─ Application Pod ────────────────┐
│                                   │
│  Task Execution Role             │
│  ├─ ecr:GetAuthorizationToken   │
│  ├─ logs:CreateLogStream        │
│  └─ logs:PutLogEvents           │
│                                   │
│  Task Role (Application)          │
│  ├─ s3:GetObject                │
│  ├─ dynamodb:Query              │
│  ├─ secretsmanager:GetSecret    │
│  └─ kms:Decrypt                 │
└───────────────────────────────────┘
```

## Role Types

### Task Execution Role

Used by ECS to:
- Pull container images from ECR
- Write logs to CloudWatch
- Pull secrets from Secrets Manager

```hcl
# Permissions included
- "ecr:GetAuthorizationToken"
- "ecr:BatchGetImage"
- "ecr:GetDownloadUrlForLayer"
- "logs:CreateLogStream"
- "logs:PutLogEvents"
- "secretsmanager:GetSecretValue"
```

### Task Role

Used by the application container to:
- Read/write to S3
- Query DynamoDB
- Decrypt with KMS
- Access other AWS services

```hcl
# Example permissions
- "s3:GetObject"
- "s3:PutObject"
- "s3:ListBucket"
- "dynamodb:Query"
- "dynamodb:GetItem"
- "kms:Decrypt"
```

### Service Roles

For RDS, Lambda, and other services:

```hcl
# RDS Enhanced Monitoring Role
- "monitoring:PutMetricData"
- "ec2:* (read-only)"

# Lambda Execution Role
- "logs:CreateLogGroup"
- "logs:CreateLogStream"
- "logs:PutLogEvents"
- "ec2:CreateNetworkInterface"
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_name` | string | - | Project identifier |
| `environment` | string | - | Environment (dev, staging, prod) |
| `enable_ecs_task_role` | bool | true | Create ECS task role |
| `enable_rds_monitoring` | bool | true | Create RDS enhanced monitoring role |
| `ecs_task_permissions` | list(string) | [] | IAM actions allowed for ECS task |
| `allowed_s3_buckets` | list(string) | [] | S3 ARNs the task can access |
| `allowed_secrets` | list(string) | [] | Secrets Manager ARNs the task can access |
| `allowed_dynamodb_tables` | list(string) | [] | DynamoDB table ARNs |
| `kms_key_arns` | list(string) | [] | KMS keys for encryption/decryption |

## Outputs

| Name | Description |
|------|-------------|
| `task_role_arn` | ARN of the ECS task role |
| `task_role_name` | Name of the ECS task role |
| `execution_role_arn` | ARN of the ECS task execution role |
| `execution_role_name` | Name of the ECS task execution role |
| `rds_monitoring_role_arn` | ARN of the RDS monitoring role |
| `lambda_execution_role_arn` | ARN of the Lambda execution role |

## Permission Examples

### S3 Access

```hcl
allowed_s3_buckets = [
  "arn:aws:s3:::myapp-data",
  "arn:aws:s3:::myapp-data/*",
  "arn:aws:s3:::myapp-uploads",
  "arn:aws:s3:::myapp-uploads/*"
]

# Grants:
# - s3:GetObject
# - s3:PutObject
# - s3:DeleteObject
# - s3:ListBucket
```

### Database Access

```hcl
allowed_dynamodb_tables = [
  "arn:aws:dynamodb:us-east-1:ACCOUNT:table/users",
  "arn:aws:dynamodb:us-east-1:ACCOUNT:table/sessions"
]

# Grants:
# - dynamodb:Query
# - dynamodb:GetItem
# - dynamodb:PutItem
# - dynamodb:UpdateItem
# - dynamodb:Scan
# - dynamodb:BatchGetItem
```

### Secrets Manager Access

```hcl
allowed_secrets = [
  "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:myapp/*"
]

# Grants:
# - secretsmanager:GetSecretValue
# - secretsmanager:ListSecrets
```

### KMS Encryption

```hcl
kms_key_arns = [
  "arn:aws:kms:us-east-1:ACCOUNT:key/12345678-1234-1234-1234-123456789012"
]

# Grants:
# - kms:Decrypt
# - kms:DescribeKey
# - kms:GenerateDataKey
```

## Environment-Specific Configuration

### Development (Permissive)

```hcl
module "iam" {
  source = "./modules/iam"

  project_name = "myapp"
  environment  = "dev"

  # Broader permissions for development
  ecs_task_permissions = [
    "s3:*",
    "dynamodb:*",
    "logs:*"
  ]
}
```

### Production (Restrictive)

```hcl
module "iam" {
  source = "./modules/iam"

  project_name = "myapp"
  environment  = "prod"

  # Specific, minimal permissions
  ecs_task_permissions = [
    "s3:GetObject",
    "s3:PutObject",
    "dynamodb:Query",
    "dynamodb:GetItem"
  ]

  allowed_s3_buckets = [
    "arn:aws:s3:::myapp-prod-data/*"
  ]
}
```

## Security Best Practices

### 1. Least Privilege

❌ BAD:
```hcl
ecs_task_permissions = ["*"]  # Never do this!
```

✅ GOOD:
```hcl
ecs_task_permissions = [
  "s3:GetObject",
  "s3:ListBucket"
]
```

### 2. Resource-Specific Policies

❌ BAD:
```hcl
allowed_s3_buckets = ["arn:aws:s3:::*"]
```

✅ GOOD:
```hcl
allowed_s3_buckets = [
  "arn:aws:s3:::myapp-prod-data/*",
  "arn:aws:s3:::myapp-prod-uploads/*"
]
```

### 3. Separate Roles by Environment

❌ BAD:
```hcl
# Single role for all environments
allowed_s3_buckets = [
  "arn:aws:s3:::dev/*",
  "arn:aws:s3:::staging/*",
  "arn:aws:s3:::prod/*"
]
```

✅ GOOD:
```hcl
# Separate modules per environment
module "iam_prod" {
  allowed_s3_buckets = ["arn:aws:s3:::prod/*"]
}

module "iam_staging" {
  allowed_s3_buckets = ["arn:aws:s3:::staging/*"]
}
```

### 4. Session Duration

```hcl
# Shorter sessions for production
role_max_session_duration = 3600  # 1 hour

# Longer for development
role_max_session_duration = 43200  # 12 hours
```

## Auditing & Monitoring

### View Role Usage

```bash
# List all attached policies
aws iam list-attached-role-policies \
  --role-name myapp-task-role

# View inline policies
aws iam list-role-policies \
  --role-name myapp-task-role
```

### CloudTrail Logs

```bash
# Find API calls made with a role
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=myapp-task-role \
  --query 'Events[*].[EventName, EventTime, Username]'
```

### Access Advisor

```bash
# See last used services/actions
aws iam get-role \
  --role-name myapp-task-role \
  --query 'Role.Tags'
```

## Troubleshooting

### Task fails with "AccessDenied"

1. Check the task role permissions:
   ```bash
   aws iam list-attached-role-policies --role-name myapp-task-role
   ```

2. Add the missing permission:
   ```hcl
   ecs_task_permissions = [
     # ... existing permissions ...
     "dynamodb:Query"  # Add missing permission
   ]
   ```

3. Re-apply Terraform

### Too many permissions in role

Use `access-analyzer` to identify unused permissions:

```bash
aws accessanalyzer validate-policy \
  --policy-document file://iam-policy.json \
  --policy-type IDENTITY_POLICY
```

## Related Modules

- **ecs**: Uses task role and execution role
- **rds**: Uses monitoring role
- **cloudwatch**: Logs role permissions

## References

- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Least Privilege Principle](https://docs.aws.amazon.com/IAM/latest/userguide/best-practices_services.html)
- [AWS Managed Policies](https://docs.aws.amazon.com/IAM/latest/userguide/access_policies_managed-vs-inline.html)
- [Access Analyzer](https://docs.aws.amazon.com/access-analyzer/)
