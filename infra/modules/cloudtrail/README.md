# CloudTrail Module

This module creates and manages AWS CloudTrail for audit logging and compliance. CloudTrail records API calls and account activities, storing logs in an S3 bucket with optional encryption and validation.

## Features

- **Comprehensive Audit Logging**: Captures all AWS API calls and account activities
- **Multi-Region Trails**: Optional support for monitoring multiple AWS regions
- **Log File Validation**: Cryptographic validation of CloudTrail log files
- **S3 Storage**: Secure storage of logs with versioning and encryption
- **Lifecycle Management**: Automatic deletion of old logs based on retention policy
- **Public Access Prevention**: Blocks all public access to log buckets
- **Data Events Tracking**: Monitors S3 object operations and Lambda function invocations
- **KMS Encryption**: Optional encryption using custom KMS keys

## Usage

```hcl
module "cloudtrail" {
  source = "../modules/cloudtrail"

  project_name                  = var.project_name
  environment                   = var.environment
  enable_cloudtrail             = true
  enable_log_file_validation    = true
  include_global_service_events = true
  is_multi_region_trail         = true
  kms_key_id                    = aws_kms_key.cloudtrail.id
  s3_log_retention_days         = 90

  tags = local.common_tags
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| `project_name` | Project name | `string` | Yes | N/A |
| `environment` | Environment (dev, staging, prod) | `string` | Yes | N/A |
| `enable_cloudtrail` | Enable CloudTrail logging | `bool` | No | `true` |
| `enable_log_file_validation` | Enable CloudTrail log file validation | `bool` | No | `true` |
| `include_global_service_events` | Include global service events (CloudFront, IAM, etc) | `bool` | No | `true` |
| `is_multi_region_trail` | Create a multi-region CloudTrail | `bool` | No | `true` |
| `kms_key_id` | KMS key ID for encrypting CloudTrail logs | `string` | No | `null` |
| `s3_log_retention_days` | Number of days to retain S3 logs | `number` | No | `90` |
| `tags` | Tags to apply to resources | `map(string)` | No | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `cloudtrail_arn` | ARN of the CloudTrail |
| `cloudtrail_home_region` | Home region of the CloudTrail |
| `s3_bucket_name` | Name of the S3 bucket for CloudTrail logs |
| `s3_bucket_arn` | ARN of the S3 bucket for CloudTrail logs |

## Security Considerations

- CloudTrail logs are stored in an S3 bucket with versioning enabled for integrity
- All public access is blocked by default
- Server-side encryption is enabled (AES256 or KMS)
- IAM policy only allows CloudTrail service to write to the bucket
- Log file validation ensures logs haven't been tampered with
- Logs are automatically deleted after the retention period

## CloudTrail Event Selectors

The module tracks the following events:

- **Management Events**: All AWS API calls (create, update, delete resources)
- **Data Events**: 
  - S3 object operations (GetObject, PutObject, DeleteObject)
  - Lambda function invocations

## Cost Optimization

- S3 logs are automatically deleted after 90 days (configurable)
- Older versions are deleted after 30 days
- Consider using S3 Intelligent-Tiering for cost optimization

## Compliance

CloudTrail is essential for:
- **SOC 2 Compliance**: Demonstrates security controls and monitoring
- **HIPAA Compliance**: Required for healthcare security
- **PCI DSS Compliance**: Payment card industry data security
- **Auditing**: Track who did what and when

## Troubleshooting

### CloudTrail logs are not appearing in S3

1. Verify the bucket policy allows CloudTrail to write
2. Check the S3 bucket name matches the trail configuration
3. Ensure CloudTrail is enabled and logging

### Permission denied errors

Verify:
1. S3 bucket policy is correctly set
2. KMS key policy (if using KMS) allows CloudTrail service
3. IAM role has proper permissions

### Log file validation failures

If using log file validation:
1. Ensure the CloudTrail service has permissions to the S3 bucket
2. Check that log files are not being modified externally
3. Review CloudTrail settings in AWS Console
