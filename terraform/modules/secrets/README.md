# Secrets Management Module

This module creates and manages AWS Secrets Manager secrets for sensitive application data like API keys, database passwords, and credentials.

## Overview

The Secrets Management module provides:

- **Secret Storage**: Secure storage for sensitive strings and JSON
- **Automatic Rotation**: Periodic rotation of credentials
- **Version Management**: Track and manage secret versions
- **Access Control**: Fine-grained IAM permissions per secret
- **Encryption**: KMS encryption with customer-managed keys
- **Audit Logging**: CloudTrail logging of secret access
- **Replication**: Multi-region replication for disaster recovery

## Features

- **Secrets Manager Integration**: AWS native secret management
- **Automatic Rotation**: Lambda-based rotation for database credentials
- **Version Tracking**: Complete audit trail of secret changes
- **Cross-Service Access**: Database password, API credentials, OAuth tokens
- **Binary Secrets**: Support for binary files and certificates
- **Resource-Based Policies**: Control access by resource ARN
- **Tag-Based Access**: Organize secrets with tags
- **Scheduled Rotation**: Daily, weekly, or monthly rotations

## Usage

```hcl
module "secrets" {
  source = "./modules/secrets"

  project_name = "myapp"
  environment  = "prod"

  # Database credentials
  secrets = {
    "myapp/db-password" = {
      type        = "string"
      description = "RDS master password"
      value       = random_password.db_password.result
      rotation    = {
        enabled_days = 30
        lambda_arn   = module.rotation_lambda.arn
      }
    }

    # API keys and credentials
    "myapp/api-keys" = {
      type        = "json"
      description = "Third-party API credentials"
      value       = jsonencode({
        stripe_key  = "sk_live_..."
        github_token = "ghp_..."
        sendgrid_key = "SG...."
      })
    }

    # JWT signing key
    "myapp/jwt-secret" = {
      type        = "string"
      description = "JWT signing key for authentication"
      value       = random_password.jwt_secret.result
    }
  }

  tags = {
    Team = "platform"
  }
}

# Retrieve secret in application code
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = module.secrets.secret_id["myapp/db-password"]
}

output "database_password" {
  value     = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)
  sensitive = true
}
```

## Secrets Architecture

```
┌─────────────────────────────────────────┐
│     AWS Secrets Manager                 │
├─────────────────────────────────────────┤
│                                         │
│  ├─ myapp/db-password                  │
│  │  ├─ Current Version (v1)            │
│  │  └─ Previous Versions (history)     │
│  │                                      │
│  ├─ myapp/api-keys                     │
│  │  ├─ stripe_key                      │
│  │  ├─ github_token                    │
│  │  └─ sendgrid_key                    │
│  │                                      │
│  └─ myapp/jwt-secret                   │
│     └─ Automatically rotated            │
│                                         │
├─ KMS Encryption                        │
├─ CloudTrail Audit Logging              │
├─ Version History (30+ versions)        │
├─ Automatic Rotation (Lambda)           │
└─ IAM Access Control                    │
```

## Secret Types

### String Secrets

Simple text values: API keys, tokens, passwords

```hcl
secrets = {
  "myapp/api-key" = {
    type  = "string"
    value = "sk_live_..."
  }
}
```

### JSON Secrets

Structured data: Multiple related credentials

```hcl
secrets = {
  "myapp/database-config" = {
    type  = "json"
    value = jsonencode({
      host     = "db.example.com"
      port     = 5432
      username = "postgres"
      password = "secret"
    })
  }
}
```

### Binary Secrets

Files and certificates: SSL certificates, keys

```hcl
secrets = {
  "myapp/ssl-cert" = {
    type  = "binary"
    value = file("${path.module}/certificate.pem")
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_name` | string | - | Project identifier |
| `environment` | string | - | Environment (dev, staging, prod) |
| `secrets` | map | {} | Secrets to create and manage |
| `encryption_key_id` | string | - | KMS key for encryption |
| `enable_rotation` | bool | false | Enable automatic rotation |
| `rotation_days` | number | 30 | Rotation frequency in days |
| `recovery_window_in_days` | number | 7 | Grace period before deletion |
| `replica_regions` | list(string) | [] | Regions for replication |

## Outputs

| Name | Description |
|------|-------------|
| `secret_ids` | Map of secret IDs by name |
| `secret_arns` | Map of secret ARNs by name |
| `kms_key_arn` | ARN of the encryption key |
| `rotation_lambda_role_arn` | ARN of the rotation Lambda role |

## Automatic Rotation

### RDS Password Rotation

```hcl
# Enable rotation for RDS password
secret_configuration = {
  rds_password = {
    rotation = {
      enabled = true
      days    = 30
      rules = {
        use_secure_password = true
        length              = 32
        exclude_characters  = "'\"@/\\"
      }
    }
  }
}
```

### Custom Lambda Rotation

```bash
# Lambda function invoked every 30 days
# Steps:
# 1. Create: Generate new secret version
# 2. Set: Set new version in RDS
# 3. Test: Verify connection with new credentials
# 4. Finish: Mark as current version
```

### Rotation Configuration

```hcl
secrets = {
  "myapp/db-password" = {
    rotation = {
      lambda_arn         = aws_lambda_function.rotate_secret.arn
      rotation_days      = 30
      event_bridge_rule  = true
    }
  }
}
```

## Access Control

### IAM Policy for ECS Task

```hcl
# Grant ECS task access to specific secrets
data "aws_iam_policy_document" "ecs_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      module.secrets.secret_arns["myapp/db-password"],
      module.secrets.secret_arns["myapp/api-keys"]
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [module.kms.key_arn]
  }
}
```

### Secret Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowECSTaskAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT:role/myapp-task-role"
      },
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:myapp/*"
    },
    {
      "Sid": "DenyPublicAccess",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "secretsmanager:*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalAccount": "ACCOUNT"
        }
      }
    }
  ]
}
```

## Retrieving Secrets in Application

### Python Example

```python
import boto3
import json

client = boto3.client('secretsmanager')

# Get secret by name
response = client.get_secret_value(
    SecretId='myapp/api-keys'
)

# Parse JSON secret
secret_data = json.loads(response['SecretString'])
stripe_key = secret_data['stripe_key']
```

### Node.js Example

```javascript
const AWS = require('aws-sdk');
const client = new AWS.SecretsManager();

const secret = await client.getSecretValue({
  SecretId: 'myapp/api-keys'
}).promise();

const credentials = JSON.parse(secret.SecretString);
const stripeKey = credentials.stripe_key;
```

### ECS Task Environment Variable

```hcl
resource "aws_ecs_task_definition" "myapp" {
  container_definitions = jsonencode([{
    name  = "app"
    image = "myapp:latest"

    secrets = [
      {
        name      = "DB_PASSWORD"
        valueFrom = module.secrets.secret_arns["myapp/db-password"]
      },
      {
        name      = "JWT_SECRET"
        valueFrom = module.secrets.secret_arns["myapp/jwt-secret"]
      }
    ]
  }])
}
```

## Environment-Specific Configuration

### Development

```hcl
secrets = {
  "dev/db-password" = {
    type     = "string"
    value    = "dev-password"
    rotation = false
  }
}
```

No rotation, simple credentials

### Production

```hcl
secrets = {
  "prod/db-password" = {
    type     = "string"
    value    = random_password.db_password.result
    rotation = {
      enabled = true
      days    = 30
    }
  }
}

replica_regions = ["us-west-2"]  # DR replication
```

Automatic rotation, multi-region replication

## Security Best Practices

### 1. Encryption with Customer-Managed KMS

❌ BAD:
```hcl
encryption_type = "default"  # AWS-managed key
```

✅ GOOD:
```hcl
encryption_key_id = module.kms.key_arn  # Customer-managed KMS key
```

### 2. Enable Automatic Rotation

❌ BAD:
```hcl
rotation = false  # Passwords never change
```

✅ GOOD:
```hcl
rotation = {
  enabled = true
  days    = 30  # Every 30 days
}
```

### 3. Minimal IAM Permissions

❌ BAD:
```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:*",
  "Resource": "*"
}
```

✅ GOOD:
```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:GetSecretValue",
  "Resource": "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:myapp/*"
}
```

### 4. Separate Secrets by Environment

❌ BAD:
```hcl
secrets = {
  "api-key" = { value = "key" }  # Used in all environments
}
```

✅ GOOD:
```hcl
secrets = {
  "prod/api-key"  = { value = "prod-key" }
  "staging/api-key" = { value = "staging-key" }
  "dev/api-key"   = { value = "dev-key" }
}
```

## Cost Optimization

### Pricing Breakdown

- **Secret Storage**: $0.40 per secret per month
- **API Calls**: $0.05 per 10,000 requests
- **Rotation**: Included if using Lambda (Lambda costs apply)

### Reduce Costs

```hcl
# Store related secrets together (fewer secrets)
secrets = {
  "myapp/credentials" = {
    type = "json"
    value = jsonencode({
      db_password = "..."
      api_key = "..."
      jwt_secret = "..."
    })
  }
}

# Cache retrieved secrets in application
# Reduces API calls to Secrets Manager
```

## Troubleshooting

### Access Denied When Retrieving Secret

```bash
# Check IAM permissions
aws iam get-user-policy --user-name username --policy-name policy-name

# Check KMS key permissions
aws kms get-key-policy --key-id alias/myapp-key --policy-name default

# Verify secret exists
aws secretsmanager list-secrets --filters Key=name,Values=myapp
```

### Rotation Lambda Failures

```bash
# Check Lambda function logs
aws logs tail /aws/lambda/rotate-secret --follow

# View rotation history
aws secretsmanager describe-secret --secret-id myapp/db-password \
  --query 'RotationRules,RotationEnabled'
```

### Secret Version Not Available

```bash
# List all versions
aws secretsmanager list-secret-version-ids \
  --secret-id myapp/db-password

# Retrieve specific version
aws secretsmanager get-secret-value \
  --secret-id myapp/db-password \
  --version-id AAAABBBBCCCCDDDD
```

## Related Modules

- **iam**: IAM roles for secret access
- **rds**: Database password secrets
- **kms**: KMS keys for encryption
- **ecs**: ECS task secret injection

## References

- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/)
- [Rotation Configuration](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets.html)
- [Secrets Manager Pricing](https://aws.amazon.com/secrets-manager/pricing/)
- [IAM Best Practices for Secrets](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_identity-and-access-management.html)
