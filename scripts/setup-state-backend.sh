#!/bin/bash
# ==============================================
# Terraform State Backend Setup Script
# ==============================================
# This script creates the S3 bucket and DynamoDB table
# required for Terraform state management with locking.
#
# Usage: ./setup-state-backend.sh <bucket-name> <region>
# Example: ./setup-state-backend.sh my-terraform-state us-east-1

set -e

BUCKET_NAME="${1:-terraform-state-$(date +%s)}"
REGION="${2:-us-east-1}"
DYNAMODB_TABLE="terraform-state-lock"

echo "================================"
echo "Terraform State Backend Setup"
echo "================================"
echo "Bucket Name: $BUCKET_NAME"
echo "Region: $REGION"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo ""

# Check prerequisites
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed"
    exit 1
fi

# Create S3 Bucket
echo "[1/4] Creating S3 bucket for Terraform state..."
aws s3 mb "s3://$BUCKET_NAME" --region "$REGION" || \
    echo "Note: Bucket may already exist"

# Enable Versioning
echo "[2/4] Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$REGION"

# Block Public Access
echo "[3/4] Blocking public access to S3 bucket..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "$REGION"

# Enable Encryption
echo "[4/4] Enabling server-side encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }' \
    --region "$REGION"

# Create DynamoDB Table  
echo "[5/5] Creating DynamoDB table for state locking..."
aws dynamodb create-table \
    --table-name "$DYNAMODB_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" 2>/dev/null || \
    echo "Note: DynamoDB table may already exist"

# Enable Point-in-Time Recovery
echo "[6/6] Enabling point-in-time recovery on DynamoDB table..."
sleep 2  # Wait for table to be created
aws dynamodb update-continuous-backups \
    --table-name "$DYNAMODB_TABLE" \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
    --region "$REGION" 2>/dev/null || \
    echo "Note: Could not enable PITR (table may still be creating)"

echo ""
echo "✓ State backend setup complete!"
echo ""
echo "Next steps:"
echo "1. Update backend.*.tfbackend files with the bucket name:"
echo "   bucket = \"$BUCKET_NAME\""
echo ""
echo "2. Initialize Terraform with backend configuration:"
echo "   cd infra/environments/dev"
echo "   terraform init -backend-config=../../backends/backend.dev.tfbackend"
echo ""
echo "3. Repeat for hom and prod environments"
echo ""
