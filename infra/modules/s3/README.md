# S3 Module

This module creates and manages AWS S3 buckets with encryption, versioning, lifecycle policies, and access control following security best practices.

## Overview

The S3 module provides:

- **S3 Buckets**: Scalable object storage for application data
- **Versioning**: Keep multiple versions of objects
- **Server-Side Encryption**: AES-256 or KMS encryption
- **Lifecycle Policies**: Automatic archival and deletion rules
- **Access Control**: Block public access, bucket policies, ACLs
- **Logging**: Access logs for audit trails
- **Replication**: Cross-region backup and disaster recovery
- **CORS Configuration**: Enable cross-origin requests for web apps
- **Static Website Hosting**: Host websites from S3

## Features

- **Private by Default**: Block all public access
- **Encryption**: KMS encryption for sensitive data
- **Versioning**: Complete history of object changes
- **Lifecycle Management**: Auto-archive to Glacier, auto-delete old versions
- **Replication**: Cross-region or same-region backup
- **Logging**: CloudTrail and S3 access logs
- **CORS Support**: Allow web app cross-origin access
- **MFA Delete**: Require MFA for permanent deletion
- **Compliance**: Support for regulatory requirements (HIPAA, PCI-DSS)

## Usage

```hcl
module "s3" {
  source = "./modules/s3"

  project_name = "myapp"
  environment  = "prod"

  # Bucket configuration
  buckets = {
    data = {
      description    = "Application data storage"
      versioning     = true
      mfa_delete     = true
      cors_enabled   = false
      encryption_key = module.kms.s3_key_id
    }
    uploads = {
      description    = "User uploads"
      versioning     = true
      mfa_delete     = false
      cors_enabled   = true
      encryption_key = module.kms.s3_key_id
    }
    backups = {
      description    = "Database backups"
      versioning     = false
      mfa_delete     = false
      cors_enabled   = false
      encryption_key = module.kms.s3_key_id
    }
  }

  # Lifecycle policies
  lifecycle_rules = {
    data = {
      enable = true
      transition_storage_class = "GLACIER"
      transition_days = 90
      expiration_days = 2555  # 7 years
    }
  }

  # Replication
  enable_replication = true
  replication_destination_bucket = "myapp-prod-backup"
  replication_destination_region = "us-west-2"

  tags = {
    Team = "data"
  }
}
```

## S3 Architecture

```
┌─────────────────────────────────────────┐
│        S3 Bucket (us-east-1)            │
├─────────────────────────────────────────┤
│                                         │
│  /application-data/                    │
│  ├─ user-profiles.json (Current)       │
│  ├─ user-profiles.json (v2 - deleted)  │
│  ├─ user-profiles.json (v1 - archived) │
│  └─ ...                                │
│                                         │
│  /user-uploads/                        │
│  ├─ avatar.jpg (Current, encrypted)    │
│  └─ documents/ (CORS enabled)          │
│                                         │
│  /database-backups/                    │
│  ├─ backup-2024-01-15.sql.gz           │
│  ├─ backup-2024-01-14.sql.gz           │
│  └─ ...                                │
│                                         │
├─ Versioning enabled (all versions kept)│
├─ KMS encryption (at rest)              │
├─ Server access logging                 │
├─ Replication to backup bucket          │
├─ Lifecycle rules (archive → Glacier)   │
└─ Blocked public access (secure)        │
```

## Bucket Types

### Application Data Bucket

```hcl
buckets = {
  data = {
    description = "Application data"
    versioning = true
    encryption_key = module.kms.s3_key_id
    cors_enabled = false
  }
}
```

**Use Cases**: JSON files, configuration, documents

### User Uploads Bucket

```hcl
buckets = {
  uploads = {
    description = "User-generated uploads"
    versioning = true
    encryption_key = module.kms.s3_key_id
    cors_enabled = true  # If accessed from web frontend
  }
}
```

**Use Cases**: Profile pictures, document uploads, user files

### Backups Bucket

```hcl
buckets = {
  backups = {
    description = "Database and system backups"
    versioning = false
    encryption_key = module.kms.s3_key_id
    cors_enabled = false
  }
}
```

**Use Cases**: Database snapshots, log archives, disaster recovery

### Logs Bucket

```hcl
buckets = {
  logs = {
    description = "Application and access logs"
    versioning = false
    encryption_key = module.kms.s3_key_id
    cors_enabled = false
  }
}
```

**Use Cases**: CloudTrail logs, S3 access logs, application logs

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_name` | string | - | Project identifier |
| `environment` | string | - | Environment (dev, staging, prod) |
| `buckets` | map | {} | Bucket configurations |
| `enable_versioning` | bool | true | Enable bucket versioning |
| `enable_mfa_delete` | bool | false | Require MFA for deletion |
| `enable_cors` | bool | false | Enable CORS |
| `encryption_type` | string | "sse-kms" | Encryption type (sse-s3 or sse-kms) |
| `enable_logging` | bool | true | Enable server access logging |
| `enable_replication` | bool | false | Enable cross-region replication |
| `lifecycle_rules` | map | {} | Lifecycle transition rules |
| `block_public_access` | bool | true | Block all public access |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_names` | Map of bucket names by key |
| `bucket_arns` | Map of bucket ARNs by key |
| `bucket_ids` | Map of bucket IDs by key |
| `replication_role_arn` | ARN of replication role |

## Data Storage Classes

### Available Classes

```
Cost per GB/month (January 2024):
├─ S3 Standard       $0.023
├─ S3 Intelligent    $0.0125 (variable)
├─ S3 Standard-IA    $0.0125 (74-day minimum)
├─ S3 Glacier Instant $0.004 (fast retrieval)
├─ S3 Glacier Flexible $0.0036 (12-hour retrieval)
└─ Deep Archive      $0.00099 (48-hour retrieval)
```

### Lifecycle Transition Strategy

```hcl
# Recommended transition timeline
lifecycle_rules = {
  data = {
    # Current data (0-30 days): S3 Standard
    # Warm archive (30-90 days): S3 Standard-IA or Intelligent
    transition_days = 30
    transition_storage_class = "STANDARD_IA"
    
    # Cold archive (90-2555 days): Glacier Flexible
    archive_days = 90
    archive_storage_class = "GLACIER_IR"
    
    # Deep archive (2555+ days): Deep Archive
    deep_archive_days = 2555
    deep_archive_storage_class = "DEEP_ARCHIVE"
    
    # Expiration: Delete after 7 years
    expiration_days = 2555
  }
}
```

## Encryption

### Server-Side Encryption (SSE-KMS)

```hcl
encryption_type = "sse-kms"
encryption_key_id = module.kms.s3_key_id

# All objects encrypted with KMS key
# Only users with kms:Decrypt permission can read
```

### Server-Side Encryption (SSE-S3)

```hcl
encryption_type = "sse-s3"

# AES-256 encryption managed by AWS
# Simpler but less control over keys
```

### Client-Side Encryption

```bash
# Encrypt before uploading to S3
openssl enc -aes-256-cbc -in file.json -out file.json.enc

# Upload encrypted file
aws s3 cp file.json.enc s3://myapp-data/

# Download and decrypt
aws s3 cp s3://myapp-data/file.json.enc .
openssl enc -aes-256-cbc -d -in file.json.enc -out file.json
```

## Versioning

### Enable Versioning

```hcl
buckets = {
  data = {
    versioning = true
  }
}
```

### Version Management

```bash
# List all versions
aws s3api list-object-versions \
  --bucket myapp-data \
  --prefix application-data/

# Retrieve previous version
aws s3api get-object \
  --bucket myapp-data \
  --key application-data/config.json \
  --version-id AAAABBBBCCCCDDDD \
  config-old.json

# Delete specific version (still takes storage)
aws s3api delete-object \
  --bucket myapp-data \
  --key application-data/config.json \
  --version-id AAAABBBBCCCCDDDD

# Delete all versions (requires delete marker)
aws s3api put-object-acl \
  --bucket myapp-data \
  --key application-data/config.json \
  --acl private
```

## Lifecycle Policies

### Archive Old Data

```hcl
lifecycle_rules = {
  backups = {
    enable = true
    # Move to standard-ia after 30 days
    transition_days = 30
    transition_storage_class = "STANDARD_IA"
    # Move to glacier after 90 days
    archive_days = 90
    archive_storage_class = "GLACIER_IR"
    # Delete after 7 years
    expiration_days = 2555
    # Delete incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload_days = 7
  }
}
```

### Clean Up Expired Objects

```bash
# See current lifecycle policy
aws s3api get-bucket-lifecycle-configuration \
  --bucket myapp-backups

# Perform early deletion
aws s3 rm s3://myapp-backups/ \
  --recursive \
  --query 'Contents[?LastModified<=`2023-01-01`]'
```

## Replication

### Cross-Region Replication (CRR)

```hcl
enable_replication = true
replication_destination_bucket = "myapp-backup"
replication_destination_region = "us-west-2"

# Replicates:
# - New objects
# - Object updates
# - Object deletions (if enabled)
# - Metadata changes

# Does NOT replicate:
# - Existing objects (use batch copy)
# - Objects deleted via lifecycle
```

### Enable Replication in Terraform

```bash
# Step 1: Create source bucket with versioning
resource "aws_s3_bucket" "source" {
  bucket = "myapp-data"
}

resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.source.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Step 2: Create destination bucket with versioning
resource "aws_s3_bucket" "destination" {
  bucket = "myapp-backup"
  region = "us-west-2"
}

resource "aws_s3_bucket_versioning" "destination" {
  bucket = aws_s3_bucket.destination.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Step 3: Create replication rule
resource "aws_s3_bucket_replication_configuration" "replication" {
  depends_on = [aws_s3_bucket_versioning.source]
  
  bucket = aws_s3_bucket.source.id
  role   = aws_iam_role.replication.arn

  rule {
    id       = "replicate-all"
    status   = "Enabled"
    priority = 1

    destination {
      bucket       = aws_s3_bucket.destination.arn
      storage_class = "STANDARD_IA"
      delete_marker_replication {
        status = "Enabled"
      }
    }
  }
}
```

## CORS Configuration

### Enable CORS for Web Apps

```hcl
buckets = {
  uploads = {
    cors_enabled = true
    cors_origins = ["https://myapp.com", "https://www.myapp.com"]
    cors_methods = ["GET", "PUT", "POST"]
    cors_headers = ["*"]
  }
}
```

### CORS Configuration Details

```bash
# Set CORS policy manually
aws s3api put-bucket-cors \
  --bucket myapp-uploads \
  --cors-configuration '{
    "CORSRules": [
      {
        "AllowedOrigins": ["https://myapp.com"],
        "AllowedMethods": ["GET", "PUT", "POST"],
        "AllowedHeaders": ["*"],
        "MaxAgeSeconds": 3000,
        "ExposeHeaders": ["ETag"]
      }
    ]
  }'

# Get CORS policy
aws s3api get-bucket-cors --bucket myapp-uploads
```

## Access Control

### Block All Public Access

```hcl
block_public_access = true

# Blocks:
# - s3:PutBucketPublicAccessBlock
# - s3:PutAccountPublicAccessBlock
# - Public ACLs
# - Bucket policies allowing public access
```

### Bucket Policy Example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::myapp-data/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "AllowECSReadAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT:role/myapp-task-role"
      },
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::myapp-data",
        "arn:aws:s3:::myapp-data/*"
      ]
    }
  ]
}
```

## Access Logging

### Enable S3 Access Logs

```bash
# Create logs bucket
aws s3api create-bucket --bucket myapp-logs

# Enable logging on main bucket
aws s3api put-bucket-logging \
  --bucket myapp-data \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "myapp-logs",
      "TargetPrefix": "s3-access-logs/"
    }
  }'

# Access logs stored in target bucket with format:
# bucket-owner-id bucket-name [timestamp] ip requester request-id operation key status error-code
```

## Environment-Specific Configuration

### Development

```hcl
buckets = {
  data = {
    versioning = false
    mfa_delete = false
    encryption_key = null  # Use default encryption
  }
}

lifecycle_rules = {
  data = {
    enable = false  # Don't transition
  }
}
```

**Monthly Cost**: ~$1-5

### Production

```hcl
buckets = {
  data = {
    versioning = true
    mfa_delete = true
    encryption_key = module.kms.s3_key_id
  }
  backups = {
    versioning = false
    replication = true
  }
}

lifecycle_rules = {
  data = {
    enable = true
    transition_days = 30
    archive_days = 90
    expiration_days = 2555
  }
}
```

**Monthly Cost**: $100+ (depending on data volume)

## Security Best Practices

### 1. Encryption by Default

❌ BAD:
```hcl
buckets = {
  data = {
    encryption_key = null
  }
}
```

✅ GOOD:
```hcl
buckets = {
  data = {
    encryption_key = module.kms.s3_key_id
  }
}
```

### 2. Version Everything Critical

❌ BAD:
```hcl
versioning = false  # Can't recover deleted files
```

✅ GOOD:
```hcl
versioning = true   # Keep all file versions
```

### 3. Block Public Access

❌ BAD:
```hcl
block_public_access = false
public_read_acl = true
```

✅ GOOD:
```hcl
block_public_access = true
public_read_acl = false
```

### 4. Disable MFA Delete for Non-Critical Buckets

❌ BAD:
```hcl
mfa_delete = false  # Anyone can permanently delete
```

✅ GOOD (Production):
```hcl
mfa_delete = true   # Requires MFA token to delete
```

## Troubleshooting

### Access Denied Errors

```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket myapp-data

# Check IAM permissions
aws iam get-user-policy --user-name username --policy-name policy-name

# Check if encryption key is accessible
aws kms describe-key --key-id arn:aws:kms:us-east-1:ACCOUNT:key/ID
```

### Slow Upload Speeds

```bash
# Use multipart upload for large files
aws s3 cp large-file.zip s3://myapp-data/ --sse aws:kms

# Or use S3 Transfer Acceleration
aws s3api put-bucket-accelerate-configuration \
  --bucket myapp-data \
  --accelerate-configuration Status=Enabled
```

### Storage Growing Unexpectedly

```bash
# Check bucket size
aws s3 ls s3://myapp-data/ --recursive --summarize

# List old versions
aws s3api list-object-versions \
  --bucket myapp-data \
  --query 'Versions[?IsLatest==`false`]' | jq '.[] | "\(.Key) - \(.Size) bytes"'
```

## Cost Optimization

### Use Intelligent-Tiering

```hcl
lifecycle_rules = {
  data = {
    transition_storage_class = "INTELLIGENT_TIERING"
    transition_days = 0  # Immediate
  }
}
```

**Benefit**: Automatic transitions between access tiers (saves up to 70%)

### Archive Old Data

```hcl
# Move to Glacier after 90 days
lifecycle_rules = {
  backups = {
    archive_days = 90
    archive_storage_class = "GLACIER_IR"
    expiration_days = 2555  # 7 years
  }
}
```

**Savings**: 82% cost reduction vs Standard storage

## Related Modules

- **kms**: S3 encryption keys
- **iam**: S3 access roles
- **vpc**: S3 endpoint configuration

## References

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [S3 Storage Classes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html)
- [S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [S3 Lifecycle Policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
