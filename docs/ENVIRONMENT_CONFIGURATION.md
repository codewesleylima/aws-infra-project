# Environment-Specific Configuration Guide

Complete guide to configuring Terraform variables for different environments (dev, staging, prod).

## Quick Reference

| Variable | Dev | Staging | Prod | Description |
|----------|-----|---------|------|-------------|
| `aws_region` | `us-east-1` | `us-east-1` | `us-east-1` | AWS region for deployment |
| `project_name` | `myapp` | `myapp` | `myapp` | Project identifier (lowercase) |
| `container_image` | `nginx:latest` | `myapp:staging` | `myapp:1.2.3` | Exact container version |
| `ecs_desired_count` | `1` | `2` | `3` | Running tasks |
| `ecs_task_cpu` | `256` | `512` | `1024` | CPU units per task |
| `enable_monitoring` | `false` | `true` | `true` | Detailed CloudWatch metrics |
| `cost_allocation_tags` | `cost-dev` | `cost-staging` | `cost-prod` | Cost tracking |

## Development Environment (`dev`)

Optimized for rapid development and testing.

### Goals
- ✅ Minimal costs
- ✅ Fast deployments
- ✅ Easy debugging
- ✅ Destructible (safe to destroy)

### terraform.tfvars

Create `terraform/environments/dev/terraform.tfvars`:

```hcl
# Core Configuration
aws_region   = "us-east-1"
project_name = "myapp"
environment  = "dev"

# Container Configuration
container_image = "nginx:latest"
container_port  = 8080

# ECS Configuration
ecs_desired_count        = 1              # Single task
ecs_task_cpu            = "256"           # Minimal CPU
ecs_task_memory         = "512"           # Minimal memory
ecs_container_port      = 8080

# Database Configuration
rds_instance_class      = "db.t3.micro"  # Free tier eligible
rds_allocated_storage   = 20              # GB
rds_backup_retention    = 3               # days (minimal)
rds_multi_az           = false            # Single AZ OK for dev

# Networking
enable_nat_gateway     = true             # Still needed for egress
single_nat_gateway     = true             # Share NAT across AZs

# Storage
s3_versioning_enabled  = false
s3_lifecycle_enabled   = false

# Monitoring
enable_monitoring      = false            # Don't pay for detailed monitoring
cloudwatch_log_retention_days = 3

# Backup & DR
backup_enabled         = false            # Manual backups only
enable_read_replica    = false

# Cost Allocation
cost_allocation_tags = {
  CostCenter  = "engineering"
  Environment = "dev"
  Managed     = "terraform"
}

# Security
allow_public_database_access = true       # OK for dev, helps debugging
alb_ingress_cidr_blocks      = ["0.0.0.0/0"]  # Open to world (for testing)
```

### Environment Variables (if needed)

```bash
export TF_VAR_container_image="nginx:latest"
export TF_VAR_ecs_desired_count=1
export TF_VAR_rds_allocated_storage=20

# Then run
terraform apply
```

### Usage

```bash
cd terraform/environments/dev

# Use the tfvars file
terraform init
terraform plan
terraform apply

# Or override specific vars
terraform apply -var="ecs_desired_count=2"
```

### Costs

**Estimated monthly cost: ~$155-200**

```
VPC           = $0        (free tier)
ECS Fargate   = $50-60   (1×0.25vCPU)
RDS t3.micro  = $20-30   (single AZ)
ALB           = $18      (fixed)
NAT Gateway   = $35      (1× shared)
Data Transfer = $10-20   (typical)
Monitoring    = $5-10    (logs + basic)
-----------
Total         = $155-200/month
```

### Tips for Development

1. **Share resources**: Multiple dev branches can share the same infrastructure
2. **Destroy often**: Safe to destroy and recreate, costs nothing to redeploy
3. **Use latest tags**: Keep container images on `latest` for dev
4. **Monitor costs**: Even dev can accumulate if left running
5. **One data volume**: Don't replicate production data, use small sample

---

## Staging Environment (`staging`)

Bridge between development and production. Tests everything before prod.

### Goals
- ✅ Mirrors production config (mostly)
- ✅ Safe testing ground
- ✅ Realistic performance metrics
- ✅ Cost-effective but not minimal

### terraform.tfvars

Create `terraform/environments/staging/terraform.tfvars`:

```hcl
# Core Configuration
aws_region   = "us-east-1"
project_name = "myapp"
environment  = "staging"

# Container Configuration - Use SPECIFIC tags, not latest
container_image = "myapp:v1.2.3-staging"  # Specific version
container_port  = 8080

# ECS Configuration - Closer to production
ecs_desired_count        = 2              # Multi-task for testing
ecs_task_cpu            = "512"           # Moderate CPU  
ecs_task_memory         = "1024"          # 1GB memory
ecs_container_port      = 8080

# Enable autoscaling testing
enable_autoscaling      = true
autoscale_min_count     = 2
autoscale_max_count     = 5
autoscale_target_cpu    = 70

# Database Configuration
rds_instance_class      = "db.t3.small"   # More realistic
rds_allocated_storage   = 50              # GB
rds_backup_retention    = 7               # days (weekly backups)
rds_multi_az           = true             # Test multi-AZ failover
rds_publicly_accessible = false           # Like production

# Enable read replica for testing
enable_read_replica     = false           # Can test separately
read_replica_class      = "db.t3.small"

# Networking
enable_nat_gateway     = true
nat_gateway_count      = 1               # Single NAT (cost)
enable_vpn             = false           # Not needed for staging

# Storage
s3_versioning_enabled  = true            # Test versioning
s3_lifecycle_enabled   = true            # Test lifecycle rules
s3_lifecycle_days      = 30

# Monitoring - More detailed than dev
enable_monitoring      = true
enable_detailed_monitoring = true        # Enhanced CloudWatch
cloudwatch_log_retention_days = 14

# Backup & DR
backup_enabled         = true            # Daily snapshots
backup_window          = "03:00-04:00"   # UTC (adjust to your TZ)
backup_retention_days  = 7

enable_point_in_time_recovery = true
pitr_retention_days    = 5

# Performance Testing
enable_performance_insights = true
enable_enhanced_monitoring  = true

# Distributed tracing (optional)
enable_xray            = false           # Enable to test

# Cost Allocation
cost_allocation_tags = {
  CostCenter  = "engineering"
  Environment = "staging"
  Managed     = "terraform"
}

# Security - Stricter than dev
allow_public_database_access = false     # Like production
alb_ingress_cidr_blocks      = [
  "10.0.0.0/8",              # Internal networks
  "203.0.113.0/24"           # Your office (example)
]

# Enable some security features for testing
require_secure_transport = true          # HTTPS only
```

### Environment Variables

```bash
export TF_VAR_container_image="myapp:v1.2.3-staging"
export TF_VAR_ecs_desired_count=2
export TF_VAR_rds_instance_class="db.t3.small"

terraform apply
```

### Usage

```bash
cd terraform/environments/staging

terraform init
terraform plan
terraform apply

# Test with realistic load
ab -n 1000 -c 20 http://staging-alb.example.com/

# Monitor metrics in CloudWatch
```

### Costs

**Estimated monthly cost: ~$280-350**

```
VPC           = $0        (free tier)
ECS Fargate   = $80-100  (2×0.5vCPU)
RDS t3.small  = $60-80   (multi-AZ - 2× cost)
ALB           = $18      (fixed)
NAT Gateway   = $35      (1× gateway)
Enhanced Mon. = $15-20   (detailed metrics)
Data Transfer = $15-30   (testing load)
Backup        = $10-15   (snapshots)
-----------
Total         = $280-350/month
```

### Features Enabled for Testing

✅ **Autoscaling** - Test scale-up/scale-down
✅ **Multi-AZ database** - Test failover
✅ **Enhanced monitoring** - Detailed metrics
✅ **Automated backups** - Test restore procedures
✅ **Read replica** (optional) - Test read scaling
✅ **Point-in-time recovery** - Test PITR
✅ **Security hardening** - Test like production

---

## Production Environment (`prod`)

Maximum reliability, security, and performance. No cost shortcuts.

### Goals
- ✅ High availability
- ✅ Maximum security
- ✅ Disaster recovery ready
- ✅ Cost-optimized (not minimal)
- ✅ Fully monitored

### terraform.tfvars

Create `terraform/environments/prod/terraform.tfvars`:

```hcl
# Core Configuration
aws_region   = "us-east-1"
project_name = "myapp"
environment  = "prod"

# Container Configuration - ALWAYS use specific versions
container_image = "myapp:v1.2.3"         # Exact version, never latest
container_port  = 8080

# ECS Configuration - Optimized for scale
ecs_desired_count        = 3              # Minimum for availability
ecs_task_cpu            = "1024"          # 1 vCPU per task
ecs_task_memory         = "2048"          # 2GB memory
ecs_container_port      = 8080

# Aggressive autoscaling in production
enable_autoscaling      = true
autoscale_min_count     = 3               # Never below 3
autoscale_max_count     = 20              # Can scale high for traffic
autoscale_target_cpu    = 70              # Conservative threshold
autoscale_target_memory = 75

# Scale-in protection (prevent sudden terminations)
scale_in_protected      = true
termination_policies    = ["OldestInstance", "ClosestToNextInstanceHour"]

# Database Configuration - Maximum redundancy
rds_instance_class      = "db.r6g.large" # Dedicated RAM (production)
rds_allocated_storage   = 100             # GB (production volume)
rds_max_allocated_storage = 500           # Enable autoscaling
rds_backup_retention    = 30              # days (monthly retention)
rds_multi_az           = true             # Critical for HA
rds_publicly_accessible = false           # Never expose publicly

# Read replicas for read scaling
enable_read_replica     = true
read_replica_count      = 2               # 2 read replicas for scaling
read_replica_class      = "db.r6g.large"
read_replica_multi_az   = false           # Replicas can be single-AZ

# Enhanced durability
enhanced_monitoring_interval = 60         # 1-minute granularity
performance_insights_enabled = true
deletion_protection     = true            # Prevent accidental deletes

# Storage Configuration
rds_storage_type        = "gp3"           # Latest generation
rds_iops                = 3000            # Baseline for production
rds_throughput          = 125             # MB/s baseline

# Networking - Optimized for HA
enable_nat_gateway     = true
nat_gateway_count      = 3                # One per AZ (redundancy)
enable_nat_instance    = false
nat_instance_type      = ""

# VPC Endpoints for AWS services (reduce data costs)
enable_vpc_endpoints   = true
vpc_endpoints = [
  "s3",
  "dynamodb",
  "ecr.api",
  "ecr.dkr",
  "logs",
  "monitoring"
]

# Storage Configuration
s3_versioning_enabled  = true             # Always versioning
s3_lifecycle_enabled   = true             # Cost optimization
s3_lifecycle_transitions = {
  STANDARD_IA = 30                        # 30 days to IA
  INTELLIGENT_TIERING = 0                 # Immediate
  GLACIER = 365                           # 1 year
  DEEP_ARCHIVE = 2555                     # 7 years
}

# Replication for disaster recovery
s3_replication_enabled = true
s3_replication_role_arn = "arn:aws:iam::ACCOUNT:role/s3-replication"
s3_destination_bucket = "myapp-prod-backup-REGION2"  # Different region

# Monitoring - Everything enabled
enable_monitoring      = true
enable_detailed_monitoring = true
enable_xray           = true              # Distributed tracing
enable_container_insights = true          # ECS insights
cloudwatch_log_retention_days = 30        # Month retention

# Alarms - All critical metrics
enable_all_alarms      = true
alarm_actions         = "arn:aws:sns:us-east-1:ACCOUNT:prod-alerts"
ok_actions            = "arn:aws:sns:us-east-1:ACCOUNT:prod-ok"

# Backup & Disaster Recovery - Maximum
backup_enabled         = true
backup_window          = "02:00-03:00"    # Off-peak (UTC)
backup_retention_days  = 30               # 30 days retention
backup_copy_to_region  = "us-west-2"      # Cross-region copies

# PITR enabled for point-in-time recovery
enable_point_in_time_recovery = true
pitr_retention_days    = 30               # 30 days of recovery window

# Automated failover
enable_automatic_failover = true
failover_priority      = true

# Replication to other regions for DR
enable_global_database = true             # Optional for multi-region
replicate_to_regions   = ["us-west-2"]    # Secondary regions

# Performance & Caching
enable_elasticache     = true             # Redis for caching
elasticache_engine_version = "7.0"
elasticache_node_type  = "cache.r6g.large"  # Memory optimized
elasticache_num_cache_nodes = 3           # 3-node cluster
elasticache_automatic_failover = true

# CDN for static content
enable_cloudfront      = true
cloudfront_ttl_default = 3600              # 1 hour
cloudfront_ttl_max     = 86400             # 24 hours
cloudfront_compress    = true
cloudfront_http2       = true

# Security - Maximum hardening
require_secure_transport = true           # HTTPS/TLS only
alb_ingress_cidr_blocks = [
  "203.0.113.0/24",      # Your office
  "198.51.100.0/24"      # VPN gateway
]

# WAF for protection
enable_waf             = true
waf_rate_limit         = 2000             # Requests per 5 min

# Certificate settings
certificate_validation_method = "DNS"
auto_renew_certificate = true

# Database encryption
database_encryption_enabled = true
database_encryption_kms_key_id = "arn:aws:kms:us-east-1:ACCOUNT:key/UUID"

# Secrets manager for sensitive data
enable_secrets_manager = true
rotate_secrets_enabled = true
rotation_days          = 30

# Cost Allocation - Detailed tracking
cost_allocation_tags = {
  CostCenter   = "business-unit"
  Environment  = "production"
  Managed      = "terraform"
  Application  = "myapp"
  Owner        = "platform-team"
  BackupPolicy = "30-days"
  CompliantWith = "sox"
}

# Reserved Instance configuration (save 30-50%)
use_reserved_instances = true
reserved_instance_term = "1-year"         # 1-year reservation
reserved_instance_payment = "partial-upfront"

# Spot instances for flexible workloads (optional)
enable_spot_instances = false             # Conservative for prod
spot_max_price        = "0.05"

# Maintenance & Updates
preferred_maintenance_window = "sun:03:00-sun:04:00"  # UTC
apply_immediately      = false            # Queue updates

# Compliance & Audit
enable_cloudtrail      = true             # Audit logs
trail_retention_days   = 2555             # 7 years

# Data residency requirements
restrict_to_region     = "us-east-1"
disable_cross_region   = false            # Can replicate
```

### Usage & Deployment

```bash
cd terraform/environments/prod

# CAREFUL: Production deployments require extra steps
terraform init

# Always plan first and review output
terraform plan > prod-plan.txt
cat prod-plan.txt
# Review all changes carefully!

# Apply with auto-approve only if changes look correct
terraform apply

# Better: Require manual approval
terraform apply --auto-approve=false
# Type 'yes' when ready
```

### Change Control Process for Production

**REQUIRED for any production change:**

```bash
# Step 1: Create branch
git checkout -b change/prod-update-container

# Step 2: Update variables
vi terraform/environments/prod/terraform.tfvars

# Step 3: Test in staging first
make plan-staging
make apply-staging

# Step 4: Verify staging works
curl https://staging.example.com/health

# Step 5: Commit changes
git add -A
git commit -m "feat(prod): update container to v2.0.0"

# Step 6: Push and create PR
git push origin change/prod-update-container

# Step 7: Wait for 2+ approvals and all checks to pass
# Step 8: Merge PR

# Step 9: Monitor prod deployment
aws logs tail /ecs/myapp-prod --follow

# Step 10: Verify with health checks
curl https://prod.example.com/health
```

### Emergency Production Updates

**For true emergencies only:**

```bash
# Contact ops team for approval
# Update variable with explicit reason
vi terraform/environments/prod/terraform.tfvars

# Emergency flag
EMERGENCY=true terraform apply
```

### Costs

**Estimated monthly cost: $850-1,200**

```
VPC + Networking   = $0        (free tier)
ECS Fargate        = $250-300  (3×1vCPU sustained)
RDS r6g.large      = $400-450  (Multi-AZ + backups)
Read replicas (2×) = $100-150  (Additional capacity)
ALB                = $18       (fixed)
NAT Gateways (3×)  = $105      (3× @ $35 each)
Backup storage     = $20-30    (30-day retention)
Enhanced Mon.      = $30-50    (detailed metrics)
CloudFront         = $20-40    (CDN for assets)
ElastiCache        = $100-150  (Redis cluster)
Data Transfer      = $30-50    (normal traffic)
-----------
Total              = $1,100-1,450/month (~$13K-17K/year)
```

### High Availability Features

✅ **Multi-AZ Database** - Automatic failover
✅ **NAT per AZ** - No single point of failure
✅ **3+ ECS Tasks** - Distributed across AZs
✅ **Auto-recovery** - Terminated tasks restart
✅ **Read replicas** - Read scaling + failover option
✅ **RTO < 5 minutes** - Fast failover
✅ **RPO = 0** - No data loss (with multi-region)

---

## Variable Validation Rules

### Container Images

```hcl
# ❌ WRONG
container_image = "nginx"           # No tag
container_image = "nginx:latest"    # latest tag
container_image = "nginx:master"    # Branch names

# ✅ CORRECT
container_image = "nginx:1.25.3"               # Specific version
container_image = "myapp:v1.2.3"               # Semantic version
container_image = "registry.io/myapp:sha-123"  # Git SHA
```

### Database Instance Classes

| Environment | Class | vCPU | RAM | Max Connections |
|------------|-------|------|-----|-----------------|
| dev | `db.t3.micro` | 1 | 1GB | 45 |
| staging | `db.t3.small` | 1 | 2GB | 45 |
| prod | `db.r6g.large` | 2 | 16GB | 400+ |

### Cost Allocation Tags

All resources must have these tags:

```hcl
cost_allocation_tags = {
  Environment  = "dev|staging|prod"
  CostCenter   = "engineering"    # Your team
  Project      = "myapp"          # Project name
  ManagedBy    = "terraform"      # IaC tool
  Owner        = "team@company"   # Contact
}
```

### Regional Considerations

```hcl
# Single region (us-east-1)
aws_region = "us-east-1"

# Multi-region replication
aws_primary_region   = "us-east-1"
aws_secondary_region = "us-west-2"
cross_region_enabled = true
```

---

## Environment Promotion Workflow

```
dev (1 task)
    ↓
    Test locally for 1-2 weeks
    ↓
staging (2+ tasks)
    ↓
    Validate for 1-2 weeks
    ↓
prod (3+ tasks)
    ↓
    Monitor in production
```

### Promotion Checklist

- [ ] Code reviewed and merged
- [ ] Tested in staging
- [ ] Performance tests passed
- [ ] Security scan passed
- [ ] Cost estimated
- [ ] Runbooks updated
- [ ] Team notified
- [ ] Deployment window scheduled
- [ ] Rollback plan documented
- [ ] Monitoring configured
- [ ] Health checks verified

---

## Quick Updates

### Change Container Image

```bash
# Development
vi terraform/environments/dev/terraform.tfvars
# container_image = "myapp:test-feature"
terraform apply

# Production (requires PR + review)
vi terraform/environments/prod/terraform.tfvars
# container_image = "myapp:v1.2.4"
git add -A && git commit -m "chore(prod): update container to v1.2.4"
git push origin change/container-update
# Create PR, wait for approvals
```

### Scale Up/Down

```bash
# Staging: Scale to handle load test
vi terraform/environments/staging/terraform.tfvars
# ecs_desired_count = 5
terraform apply

# Production: Scale for traffic spike
vi terraform/environments/prod/terraform.tfvars
# ecs_desired_count = 8
terraform apply  # Or use AWS Console autoscaling
```

### Change Database Class

```bash
# Staging: Test with more RAM
vi terraform/environments/staging/terraform.tfvars
# rds_instance_class = "db.t3.medium"
terraform apply

# Downtime expected: ~5-15 minutes
# RDS will reboot to apply changes
# Use maintenance window to minimize impact
```

---

## Troubleshooting Configuration Issues

### Error: "Invalid instance class for environment"

Check that the instance class matches your environment:

```bash
# Dev should use small/micro
# Staging should use small/medium
# Prod should use large/xlarge+ (RAM-optimized)

# Fix: terraform/environments/prod/terraform.tfvars
rds_instance_class = "db.r6g.large"  # Correct for prod
```

### Error: "Insufficient capacity in AZ"

Sometimes AWS doesn't have capacity for specific instance types:

```bash
# Option 1: Switch to different instance class
rds_instance_class = "db.t3.medium"  # Try t3 instead of r6g

# Option 2: Wait and try again
sleep 60 && terraform apply

# Option 3: Request capacity increase
aws service-quotas request-service-quota-increase \
  --service-code rds \
  --quota-code L-29B6F2FD
```

### Error: "Invalid CIDR block"

Invalid CIDR blocks in security group rules:

```bash
# ❌ WRONG
alb_ingress_cidr_blocks = ["192.168.1.0"]  # Missing /32

# ✅ CORRECT
alb_ingress_cidr_blocks = ["192.168.1.0/32"]  # Host
alb_ingress_cidr_blocks = ["192.168.0.0/24"]  # Subnet
alb_ingress_cidr_blocks = ["0.0.0.0/0"]      # Internet
```

---

## Environment Parity

Keep environments as similar as possible:

```hcl
# ALWAYS use same configuration for:
- rds_engine_version = "14.8"     # All environments
- container_port = 8080           # All environments
- ecs_container_port = 8080       # All environments
- backup_window = "03:00-04:00"   # Same buffer

# DIFFERENT between environments:
- ecs_desired_count       # 1, 2, 3
- ecs_task_cpu           # 256, 512, 1024
- rds_instance_class     # micro, small, large
- rds_multi_az           # false, true, true
- enable_monitoring      # false, true, true
```

---

## References

- [Terraform AWS RDS Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)
- [AWS RDS Instance Classes](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html)
- [ECS Task Definition Parameters](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [Cost Optimization Best Practices](https://aws.amazon.com/architecture/cost-optimization/)
