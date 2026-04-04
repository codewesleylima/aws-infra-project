# RDS Module

This module creates and manages AWS Relational Database Service (RDS) instances with high availability, automated backups, and security best practices.

## Overview

The RDS module provides:

- **PostgreSQL/MySQL Databases**: Managed relational databases
- **Multi-AZ Deployment**: Automatic failover for high availability
- **Automated Backups**: Daily backups with configurable retention
- **Read Replicas**: Scaling read capacity across regions
- **Encryption**: KMS encryption for data at rest and in transit
- **Performance Insights**: Database performance monitoring
- **Enhanced Monitoring**: CloudWatch and custom metrics
- **Automatic Patching**: OS and database version management

## Features

- **High Availability**: Multi-AZ with automatic failover (RTO < 2 minutes)
- **Backup Strategy**: Automated daily backups + manual snapshots
- **Encryption**: Default KMS encryption for all databases
- **Security Groups**: Network isolation and access control
- **Parameter Groups**: Database tuning and optimization
- **Event Notifications**: SNS alerts for database events
- **Performance Monitoring**: Enhanced monitoring and slow query logs
- **Backup Windows**: Configurable backup and maintenance windows
- **Storage Auto-Scaling**: Automatic storage expansion

## Usage

```hcl
module "rds" {
  source = "./modules/rds"

  project_name = "myapp"
  environment  = "prod"

  # Database configuration
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = "db.t3.medium"
  allocated_storage    = 100
  max_allocated_storage = 500

  # High availability
  multi_az         = true
  publicly_accessible = false

  # Database
  database_name = "myappdb"
  username      = "postgres"
  password      = random_password.db_password.result

  # Backups
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  copy_tags_to_snapshot  = true

  # Subnet and security
  db_subnet_group_name            = module.vpc.db_subnet_group_name
  vpc_security_group_ids          = [module.security_groups.rds_sg_id]
  enable_iam_database_authentication = true

  # Encryption
  kms_key_id = module.kms.db_key_id
  storage_encrypted = true

  # Enhanced monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 60
  monitoring_role_arn            = module.iam.rds_monitoring_role_arn

  # Performance Insights
  performance_insights_enabled = true
  performance_insights_retention_period = 7

  tags = {
    Team = "data"
  }
}

# Retrieve password from output
output "database_host" {
  value = module.rds.address
}

output "database_name" {
  value = module.rds.database_name
}
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Production RDS Database         │
├─────────────────────────────────────────┤
│                                         │
│  Primary Instance (us-east-1a)          │
│  ├─ PostgreSQL 15.4                    │
│  ├─ db.t3.medium (4GB RAM, 2 vCPU)    │
│  └─ 100GB SSD (Auto-scaling to 500GB)  │
│                                         │
│  ↓ Synchronous Replication             │
│                                         │
│  Standby Instance (us-east-1b)          │
│  └─ Automatic Failover (< 2 min RTO)   │
│                                         │
├─ Daily Backups (30-day retention)      │
├─ Read Replica (for analytics)           │
├─ Performance Insights (7-day retention) │
├─ Enhanced Monitoring (60-sec intervals) │
└─ Encryption (AWS KMS)                  │
```

## Instance Classes

### Development (Cost-Optimized)

```hcl
instance_class       = "db.t3.small"
allocated_storage    = 20
max_allocated_storage = 100
multi_az             = false
backup_retention_period = 7
```

**Cost**: ~$35/month

### Staging (Medium)

```hcl
instance_class       = "db.t3.medium"
allocated_storage    = 50
max_allocated_storage = 200
multi_az             = true
backup_retention_period = 14
```

**Cost**: ~$140/month + backup storage

### Production (High Availability)

```hcl
instance_class       = "db.t3.large"
allocated_storage    = 200
max_allocated_storage = 1000
multi_az             = true
backup_retention_period = 30
```

**Cost**: ~$280/month + backup storage + read replica

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project_name` | string | - | Project identifier |
| `environment` | string | - | Environment (dev, staging, prod) |
| `engine` | string | "postgres" | Database engine (postgres, mysql, mariadb) |
| `engine_version` | string | "15.4" | Engine version |
| `instance_class` | string | "db.t3.micro" | Instance type |
| `allocated_storage` | number | 20 | Storage in GB |
| `max_allocated_storage` | number | 100 | Maximum auto-scaling storage |
| `multi_az` | bool | false | Enable Multi-AZ deployment |
| `database_name` | string | - | Initial database name |
| `username` | string | "postgres" | Master username |
| `password` | string | - | Master password |
| `backup_retention_period` | number | 7 | Backup retention in days |
| `publicly_accessible` | bool | false | Allow public access |
| `performance_insights_enabled` | bool | true | Enable Performance Insights |
| `enabled_cloudwatch_logs_exports` | list(string) | [] | CloudWatch log groups |

## Outputs

| Name | Description |
|------|-------------|
| `address` | Database endpoint address |
| `port` | Database port (default 5432 for PostgreSQL) |
| `database_name` | Initial database name |
| `resource_id` | RDS resource ID |
| `engine` | Database engine |
| `engine_version` | Engine version |
| `arn` | RDS instance ARN |

## Multi-AZ High Availability

### How It Works

```
Primary (Synchronous)          Standby (Hot Standby)
├─ Receives writes            ├─ Passive replica
├─ Replicates to standby      ├─ No public endpoint
├─ Public endpoint available  ├─ Never accessed directly
└─ Public IP for connections  └─ Takes over if primary fails

Automatic Failover Trigger:
├─ Primary failure
├─ Loss of network connectivity
├─ Standby promotion (< 2 min)
└─ DNS updated automatically
```

### Failover Behavior

When primary fails:

1. **Detection**: RDS detects failure (< 30 seconds)
2. **Promotion**: Standby promoted to primary (30-60 seconds)
3. **Service Resume**: Applications reconnect (< 2 minutes total RTO)
4. **Data Loss**: None (synchronous replication)

### Monitoring During Failover

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier myapp-db \
  --query 'DBInstances[0].[DBInstanceStatus, MultiAZ]'

# Output should show:
# - DBInstanceStatus: "available" or "backing-up"
# - MultiAZ: true
```

## Backup Strategy

### Automated Backups

```hcl
backup_retention_period = 30  # Keep 30 days of backups
backup_window = "03:00-04:00" # Backup between 3-4 AM UTC
copy_tags_to_snapshot = true  # Snapshots inherit tags
```

### Manual Snapshots

```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier myapp-db \
  --db-snapshot-identifier myapp-db-backup-2024-01-15

# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier myapp-db

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier myapp-db-restored \
  --db-snapshot-identifier myapp-db-backup-2024-01-15
```

### Backup Timeline

```
Day 1    Day 2    Day 3    Day 4    Day 31
|        |        |        |        |
Full     Incremental Builds
|--------|--------|--------|--------|
                    Current backups
                    (30-day retention)

Deleted after 30 days
```

## Encryption

### Data at Rest (KMS)

```hcl
storage_encrypted = true
kms_key_id = module.kms.db_key_id

# All I/O is encrypted before writing to storage
# Backups are encrypted with the same key
# Read replicas inherit encryption
```

### Data in Transit (SSL)

```bash
# Connect with SSL
psql -h myapp-db.xyz.us-east-1.rds.amazonaws.com \
     -U postgres \
     -d myappdb \
     --set=sslmode=require
```

## Read Replicas

### Create Read Replica

```bash
aws rds create-db-instance-read-replica \
  --db-instance-identifier myapp-db-read-replica \
  --source-db-instance-identifier myapp-db \
  --db-instance-class db.t3.medium
```

### Use Cases

- **Analytics**: Heavy queries don't impact production
- **Reporting**: Separate read-only connection
- **Scaling**: Multiple read endpoints
- **Regional**: Read replicas in other regions for DR

### Replication Lag

```bash
# Check replica lag
aws rds describe-db-instances \
  --db-instance-identifier myapp-db-read-replica \
  --query 'DBInstances[0].StatusInfos'
```

## Monitoring

### Enhanced Monitoring

```hcl
enabled_cloudwatch_logs_exports = ["postgresql"]
monitoring_interval = 60  # Every 60 seconds
monitoring_role_arn = module.iam.rds_monitoring_role_arn
```

### Available Metrics

- CPU utilization
- Database connections
- Read/Write latency
- I/O throughput
- Storage space usage
- Memory usage
- Swap usage

### CloudWatch Logs

```bash
# View PostgreSQL logs
aws logs tail /aws/rds/instance/myapp-db/postgresql

# Filter for errors
aws logs tail /aws/rds/instance/myapp-db/postgresql \
  --filter-pattern "ERROR"
```

## Performance Tuning

### Parameter Groups

```hcl
# Create custom parameter group
resource "aws_db_parameter_group" "postgres" {
  name   = "myapp-postgres-15"
  family = "postgres15"

  parameter {
    name  = "max_connections"
    value = "500"
  }

  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/32768}"
  }

  parameter {
    name  = "effective_cache_size"
    value = "{DBInstanceClassMemory/2048}"
  }
}
```

### Query Optimization

```sql
-- Enable query logging
SET log_min_duration_statement = 1000;  -- Queries > 1 second

-- Run EXPLAIN to see execution plans
EXPLAIN ANALYZE SELECT * FROM users WHERE id = 1;

-- Create indexes
CREATE INDEX idx_users_email ON users(email);
```

## Environment-Specific Configuration

### Development

```hcl
instance_class       = "db.t3.micro"
allocated_storage    = 20
multi_az             = false
backup_retention_period = 7
publicly_accessible  = true  # For local development
```

### Staging

```hcl
instance_class       = "db.t3.small"
allocated_storage    = 50
multi_az             = true
backup_retention_period = 14
publicly_accessible  = false
```

### Production

```hcl
instance_class       = "db.t3.large"
allocated_storage    = 200
multi_az             = true
backup_retention_period = 30
publicly_accessible  = false
performance_insights_enabled = true
```

## Security Best Practices

### 1. Subnet Configuration

```hcl
# Only place in private subnets
db_subnet_group_name = module.vpc.db_subnet_group_name

# Never in public subnets
```

### 2. Security Group Rules

```hcl
vpc_security_group_ids = [aws_security_group.rds.id]

# Allow only from ECS security group
resource "aws_security_group_rule" "rds_ingress" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  source_security_group_id = aws_security_group.ecs.id
}
```

### 3. Root Password Management

```hcl
# Never hardcode password
password = random_password.db_password.result

# Store in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "myapp/rds-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id      = aws_secretsmanager_secret.db_password.id
  secret_string  = random_password.db_password.result
}
```

### 4. IAM Database Authentication

```hcl
enable_iam_database_authentication = true

# Allows database access via IAM roles instead of passwords
```

## Troubleshooting

### Connected Connections Won't Timeout

```sql
-- Set statement timeout
SET statement_timeout = '30s';

-- View current connections
SELECT pid, usename, application_name, state 
FROM pg_stat_activity;

-- Kill long-running query
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE duration > interval '1 hour';
```

### Slow Queries

```sql
-- Enable slow query log
SET log_min_duration_statement = 1000;  -- Log queries > 1 second

-- Find slow queries
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Create index to speed up
CREATE INDEX idx_table_column ON table(column);
```

### Storage Growing Too Fast

```bash
# Check backup storage usage
aws rds describe-db-instances \
  --db-instance-identifier myapp-db \
  --query 'DBInstances[0].AllocatedStorage'

# Reduce backup retention
resource "aws_db_instance" "myapp" {
  backup_retention_period = 14  # Reduced from 30
}
```

### Connection Pool Exhaustion

```hcl
# Increase max connections
resource "aws_db_parameter_group" "postgres" {
  parameter {
    name  = "max_connections"
    value = "1000"
  }
}

# Or use connection pooling (PgBouncer)
```

## Related Modules

- **vpc**: Database subnet group and network
- **security_groups**: RDS security group
- **iam**: RDS monitoring role
- **kms**: Database encryption key

## References

- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/)
- [PostgreSQL Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [RDS Performance Tuning](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Performance.html)
- [RDS High Availability](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
