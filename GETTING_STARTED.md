# Getting Started Guide

Complete step-by-step guide to get up and running with this AWS infrastructure project.

## Prerequisites

Before you begin, ensure you have:

```bash
# Check Terraform version (needs >= 1.6.0)
terraform --version

# Check AWS CLI (if using real AWS)
aws --version

# Check Git
git --version

# Check Make (optional but recommended)
make --version
```

## Installation

### Option 1: AWS Account with Real Infrastructure

This is the recommended approach for production-like testing.

#### Step 1: AWS Credentials

```bash
# Configure AWS credentials
aws configure

# Verify configuration
aws sts get-caller-identity
```

**Output should show:**
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

#### Step 2: Clone Repository

```bash
# Clone the project
git clone https://github.com/your-org/aws-infra-project.git
cd aws-infra-project

# Verify structure
ls -la
# Should show: Makefile, Dockerfile, README.md, infra/, docs/, scripts/, etc.
```

#### Step 3: Install Development Tools

```bash
# Install pre-commit hooks for automated checks
./scripts/setup-pre-commit.sh

# Install Terraform > 1.6.0
brew install terraform  # macOS
# OR
choco install terraform  # Windows
# OR download from https://www.terraform.io/downloads

# Verify Terraform version
terraform -version
# Should be >= 1.6.0
```

#### Step 4: Deploy Development Environment

```bash
# Navigate to dev environment
cd infra/environments/dev

# Create a variables file (optional, uses defaults)
cat > terraform.tfvars << EOF
aws_region     = "us-east-1"
project_name   = "myapp"
container_image = "nginx:latest"
EOF

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy infrastructure
terraform apply

# Terraform will ask for confirmation - type 'yes'
# Deployment takes ~10-15 minutes
```

**First deployment takes time because:**
- VPC and subnets are being created
- Security groups are being configured
- ECS cluster is being set up
- RDS database is initializing
- NAT gateways are provisioning

#### Step 5: Verify Deployment

```bash
# Check infrastructure was created
aws ec2 describe-vpcs \
  --filters Name=tag:Environment,Values=dev \
  --query 'Vpcs[0].VpcId'

# Check ECS cluster
aws ecs list-clusters

# Check RDS instance
aws rds describe-db-instances \
  --query 'DBInstances[0].DBInstanceIdentifier'

# Get ALB DNS name
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[0].DNSName'
```

#### Step 6: Access Your Application

```bash
# Get the ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# Test the health check endpoint
curl http://$ALB_DNS/health

# Should return 200 OK (or application-specific response)
```

---

### Option 2: LocalStack (Local AWS Simulation)

Perfect for development without AWS credentials or costs.

#### Step 1: Install Docker

```bash
# macOS
brew install docker

# Windows
# Download Docker Desktop from https://www.docker.com/products/docker-desktop

# Linux
sudo apt-get install docker.io

# Verify Docker is running
docker --version
docker ps
```

#### Step 2: Start LocalStack

```bash
# Pull and start LocalStack
docker run \
  --rm \
  -d \
  --name localstack \
  -p 4566:4566 \
  -e SERVICES=ec2,s3,rds,ecs,iam \
  localstack/localstack

# Verify LocalStack is running
docker ps | grep localstack

# Check if services are ready
wget -O - http://localhost:4566/_localstack/health | jq
```

#### Step 3: Configure Terraform for LocalStack

```bash
# Clone and navigate
git clone https://github.com/your-org/aws-infra-project.git
cd aws-infra-project/infra/environments/dev

# Create terraform.tfvars for LocalStack
cat > terraform.tfvars << EOF
aws_region = "us-east-1"
project_name = "localstack-test"

# LocalStack endpoint
localstack_endpoint = "http://localhost:4566"
use_localstack = true
EOF

# Initialize with LocalStack
terraform init

# Plan (doesn't require AWS credentials)
terraform plan

# Apply locally
terraform apply -auto-approve
```

#### Step 4: Verify LocalStack Deployment

```bash
# Check S3 buckets created
aws s3 ls \
  --endpoint-url=http://localhost:4566 \
  --region us-east-1

# Check VPC created
aws ec2 describe-vpcs \
  --endpoint-url=http://localhost:4566 \
  --region us-east-1

# Stop LocalStack when done
docker stop localstack
```

---

## Using Make Commands

This project includes a Makefile for common operations:

```bash
# Show all available commands
make help

# Format Terraform code
make fmt

# Validate all environments
make validate-dev
make validate-hom
make validate-prod

# Or validate all at once
make check-all

# Plan changes
make plan-dev
make plan-hom
make plan-prod

# Deploy
make apply-dev
make apply-hom

# Destroy (dev only - production requires manual approval)
make destroy-dev
```

---

## Next Steps

### 1. Understand the Architecture

Read the [Architecture Documentation](./docs/ARCHITECTURE.md) to understand:
- VPC and networking design
- ECS container orchestration
- RDS database setup
- Security group configuration

### 2. Review Security Practices

Check [Security Documentation](./SECURITY.md) for:
- IAM policies
- Encryption configuration
- Network security
- Secrets management

### 3. Set Up Monitoring

Review [CloudWatch Guide](./docs/CLOUDWATCH.md) to:
- Access dashboards
- Configure alarms
- Set up notifications
- Monitor costs

### 4. Configure Your Application

Update [Terraform variables](./infra/environments/dev/variables.tf):

```hcl
variable "container_image" {
  description = "Docker image for your application"
  default     = "your-registry/your-app:latest"
}

variable "environment_variables" {
  description = "Environment variables for container"
  default = {
    LOG_LEVEL = "info"
    APP_ENV   = "dev"
  }
}
```

### 5. Set Up CI/CD

Review the [GitHub Actions Workflows](./.github/workflows):
- `terraform-validate.yml` - Validates Terraform code
- `terraform-security.yml` - Security scanning
- `ci-cd.yml` - Deployment pipeline

### 6. Read Important Documentation

Must-read guides:
- [Cost Estimation](./docs/COST_ESTIMATION.md) - Understand infrastructure costs
- [Operational Runbooks](./docs/RUNBOOKS.md) - How to operate in production
- [Branch Protection](./docs/BRANCH_PROTECTION.md) - Code review requirements
- [Docker Optimization](./docs/DOCKER_OPTIMIZATION.md) - Build efficient images
- [Version Pinning](./docs/VERSION_PINNING.md) - Manage dependencies

---

## Common Tasks

### Deploy a New Version of Your Application

```bash
# 1. Update the container image in variables.tfvars
echo 'container_image = "your-registry/your-app:v2.0"' >> terraform.tfvars

# 2. Plan the changes
terraform plan

# 3. Apply (for development)
terraform apply

# For production, use the standard PR + review process
```

### Scale the Application

```bash
# Increase number of running tasks
# Edit infra/environments/prod/main.tf:
# Change desired_count = 5  (from 3)

# Then apply
cd infra/environments/prod
erraform apply
```

### View Logs

```bash
# Stream application logs (requires CloudWatch log group)
aws logs tail /ecs/myapp-dev --follow

# View specific error logs
aws logs filter-log-events \
  --log-group-name /ecs/myapp-dev \
  --filter-pattern ERROR
```

### Check Deployment Status

```bash
# View ECS service status
aws ecs describe-services \
  --cluster dev \
  --services myapp-service \
  --query 'services[0].[serviceName,status,runningCount,desiredCount]' \
  --output table

# View recent deployments
aws ecs describe-services \
  --cluster dev \
  --services myapp-service \
  --query 'services[0].deployments' \
  --output table
```

### Destroy Infrastructure (Development Only)

```bash
# Only safe in development
cd infra/environments/dev

# See what will be destroyed
terraform plan -destroy

# Destroy
terraform destroy

# Type 'yes' to confirm
```

**NEVER run terraform destroy in production**. For prod cleanup, contact your infrastructure team.

---

## Troubleshooting

### Error: "Invalid or expired AWS credentials"

```bash
# Check if credentials are configured
aws sts get-caller-identity

# If not, configure them
aws configure

# Use temporary credentials if needed
export AWS_ACCESS_KEY_ID="xxx"
export AWS_SECRET_ACCESS_KEY="xxx"
export AWS_SESSION_TOKEN="xxx"
```

### Error: "Terraform version >= 1.6.0 required"

```bash
# Check your Terraform version
terraform -version

# Update Terraform (macOS)
brew upgrade terraform

# Or download specific version
https://www.terraform.io/downloads
```

### Error: "Insufficient permissions"

```bash
# Check what the error is
terraform apply 2>&1 | head -20

# Common causes:
# - Missing IAM permissions in AWS account
# - Using read-only IAM role
# - Session token expired

# Solution: Verify AWS credentials have required permissions
```

### Error: "Module source not found"

```bash
# Ensure you're in the correct directory
pwd
# Should be: aws-infra-project/infra/environments/{dev,hom,prod}

# Re-initialize Terraform
terraform init -upgrade

# If still failing, check modules exist
ls ../../modules/
# Should show: vpc/, ecs/, rds/, s3/, iam/, kms/, cloudwatch/, alb/, etc.
```

### Slow Deployment (> 30 minutes)

```bash
# Check what's taking time
aws cloudwatch list-metrics \
  --namespace AWS/RDS \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-dev

# Database initialization usually takes 5-10 minutes
# NAT gateway takes 5-10 minutes
# If stuck > 30 minutes, check:
aws cloudformation describe-stacks \
  --stack-name myapp-dev \
  --query 'Stacks[0].StackStatus'
```

---

## Getting Help

### Documentation

- [Architecture](./docs/ARCHITECTURE.md) - System design
- [Cost Analysis](./docs/COST_ESTIMATION.md) - Budget planning
- [Operational Runbooks](./docs/RUNBOOKS.md) - How to operate

### Troubleshooting

- [Terraform Docs](https://www.terraform.io/docs)
- [AWS CLI Docs](https://docs.aws.amazon.com/cli/)
- [GitHub Issues](../../issues) - Report bugs

### Team Support

- Slack: #infrastructure
- Email: infrastructure@company.com
- Standups: Tuesdays 10am

---

## Next Time You Log In

Quick reminder for next session:

```bash
# Navigate to project
cd aws-infra-project

# Ensure pre-commit hooks are installed
./scripts/setup-pre-commit.sh

# Check status of any environment
cd infra/environments/dev
terraform plan

# View recent changes
git log --oneline -n 5
```

---

Good luck! 🚀 Welcome to the infrastructure team!
