# KMS Module

This module creates and manages AWS KMS keys for encryption at rest with automatic key rotation. KMS is essential for encrypting sensitive data in EBS, S3, RDS, and other AWS services.

## Features

- **Automatic Key Rotation**: Enabled by default with 1-year rotation cycle
- **Aliases**: User-friendly names for key reference
- **Multi-Region Support**: Optional replication for disaster recovery
- **CloudWatch Monitoring**: Optional alarms for key usage anomalies
- **Custom Policies**: Support for custom KMS key policies
- **Deletion Protection**: Grace period before actual key deletion

## Usage

```hcl
module "kms" {
  source = "../modules/kms"

  project_name           = var.project_name
  environment            = var.environment
  enable_key_rotation    = true
  rotation_period_in_days = 365
  deletion_window_in_days = 30
  multi_region           = var.environment == "prod"
  enable_usage_alarms    = true
  alarm_actions          = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| `project_name` | Project name | `string` | Yes | N/A |
| `environment` | Environment (dev, staging, prod) | `string` | Yes | N/A |
| `enable_key_rotation` | Enable automatic KMS key rotation | `bool` | No | `true` |
| `rotation_period_in_days` | KMS key rotation period (90-2920 days) | `number` | No | `365` |
| `deletion_window_in_days` | KMS key deletion grace period (7-30 days) | `number` | No | `30` |
| `multi_region` | Create a multi-region primary key | `bool` | No | `false` |
| `enable_usage_alarms` | Enable CloudWatch alarms for KMS key usage | `bool` | No | `true` |
| `alarm_actions` | SNS topic ARNs for alarm notifications | `list(string)` | No | `[]` |
| `key_policy` | Custom KMS key policy | `string` | No | `null` |
| `tags` | Tags to apply to resources | `map(string)` | No | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `key_id` | KMS key ID |
| `key_arn` | KMS key ARN |
| `alias_name` | KMS key alias name |
| `key_usage` | KMS key usage type |

## Key Rotation

Automatic key rotation is enabled by default and rotates the key material annually. AWS maintains the old key material indefinitely, so decryption of previously encrypted data is not affected.

- **Rotation Period**: 365 days (recommended)
- **Process**: Automatic, no manual intervention needed
- **Cost**: No additional charge for key rotation

## Security Best Practices

- Enable key rotation for all production keys
- Use separate keys for different services (S3 key, RDS key, EBS key, etc.)
- Regularly audit key usage with CloudTrail
- Implement least-privilege IAM policies for key access
- Enable encryption for all sensitive data

## Monitoring

CloudWatch alarms track:
- Key user errors (failed operations)
- Key usage patterns
- Anomalies in key access

## Compliance

KMS keys with automatic rotation help meet:
- **PCI DSS**: Encryption and key rotation requirements
- **HIPAA**: Data encryption and key management
- **SOC 2**: Encryption and access controls
- **ISO 27001**: Cryptographic controls

## Cost Considerations

- AWS KMS charges per key per month ($1/month per key)
- Additional cost for each encrypt/decrypt operation
- Key rotation has no additional cost
- Use a single key across multiple services to minimize costs

## Troubleshooting

### Key Rotation Issues
- Verify AWS KMS service has sufficient IAM permissions
- Check CloudTrail logs for encryption operation failures
- Ensure rotation period is between 90 and 2920 days

### Alarm Not Triggering
- Verify SNS topic ARN is correct
- Check topic subscription and permissions
- Ensure sufficient KMS operations for error detection
