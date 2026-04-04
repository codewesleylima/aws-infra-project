# Performance Optimization Guide

Comprehensive strategies to optimize application and infrastructure performance, balancing speed with costs.

## Table of Contents

1. [Application Layer](#application-layer)
2. [Database Layer](#database-layer)
3. [Caching Strategy](#caching-strategy)
4. [Infrastructure Tuning](#infrastructure-tuning)
5. [Network Optimization](#network-optimization)
6. [Monitoring & Profiling](#monitoring--profiling)
7. [Cost vs Performance Trade-offs](#cost-vs-performance-trade-offs)
8. [Performance Targets](#performance-targets)

---

## Application Layer

### ECS Task Optimization

#### CPU & Memory Right-Sizing

```bash
# Current configuration (dev)
ecs_task_cpu = "256"      # 0.25 vCPU
ecs_task_memory = "512"   # 512 MB

# How to choose optimal values:
# 1. Monitor actual usage for 1-2 weeks
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=myapp-service Name=ClusterName,Value=prod \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-08T00:00:00Z \
  --period 3600 \
  --statistics Average,Maximum

# 2. Look at P99 (99th percentile) for peak sizing
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=myapp-service Name=ClusterName,Value=prod \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-08T00:00:00Z \
  --period 3600 \
  --statistics Average,Maximum

# 3. Choose next tier up from P99
# CPU Tiers: 256, 512, 1024, 2048, 4096 millicpus
# Memory Tiers: 512MB, 1GB, 2GB, 3GB, 4GB, 5GB, 6GB, 7GB, 8GB, etc.

# Example findings:
# - Average CPU: 80 millicpus (31% of 256)
# - P99 CPU: 180 millicpus (70% of 256) ← fits well
# - Average Memory: 180 MB
# - P99 Memory: 380 MB
# Recommendation: Keep 256/512 (good fit)

# If P99 CPU > 240 millicpus → upgrade to 512
# If P99 Memory > 480 MB → upgrade to 1GB
```

#### Valid CPU/Memory Combinations

```hcl
# CPU 256 supports: 512MB - 2GB
# CPU 512 supports: 1GB - 4GB
# CPU 1024 supports: 2GB - 8GB
# CPU 2048 supports: 4GB - 16GB
# CPU 4096 supports: 8GB - 30GB

# Dev recommendation: 256/512
ecs_task_cpu     = "256"
ecs_task_memory  = "512"

# Staging recommendation: 512/1024
ecs_task_cpu     = "512"
ecs_task_memory  = "1024"

# Prod recommendation: 1024/2048
ecs_task_cpu     = "1024"
ecs_task_memory  = "2048"
```

### Container Performance

#### Multi-stage Docker Build

```dockerfile
# Good: Multi-stage build reduces image size by 80%
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
CMD ["python", "app.py"]

# Build: ~8-15 seconds (with layer caching)
# Image size: 85MB (vs 450MB unoptimized)
# Startup time: 2-3 seconds
```

**Performance gains:**
- 80% smaller image (faster pull, faster start)
- Cache reuse (rebuild only changed layers)
- Fewer vulnerabilities (smaller base image)

#### Health Check Tuning

```dockerfile
# Fast health checks reduce deployment time
HEALTHCHECK --interval=10s --timeout=2s --retries=3 --start-period=10s \
  CMD curl -f http://localhost:8080/health || exit 1

# Tuning parameters:
# interval=10s: Check every 10 seconds (balance cost vs latency)
# timeout=2s: Consider unhealthy if not responding in 2s
# retries=3: Unhealthy after 3 failed checks (30s total wait)
# start-period=10s: Grace period before starting checks

# For slow-starting apps (start-period is critical):
# Java: start-period=60s (JVM startup + warmup)
# Node: start-period=30s (require() module loading)
# Python: start-period=15s (import overhead)
```

#### Graceful Shutdown

```python
# Application should handle SIGTERM for fast deploys
import signal
import time

def graceful_shutdown(signum, frame):
    print("Shutting down gracefully...")
    # Close database connections
    db.close()
    # Wait for in-flight requests (max 15s)
    time.sleep(1)
    exit(0)

signal.signal(signal.SIGTERM, graceful_shutdown)

# Result: Deployment downtime < 5 seconds
# Instead of: 30+ seconds (task killed after timeout)
```

---

## Database Layer

### Query Optimization

#### Identify Slow Queries

```bash
# Enable slow query log (100ms threshold)
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod \
  --enable-cloudwatch-logs-exports postgresql

# Query PostgreSQL slow log
aws logs tail /rds/myapp-prod --follow

# Look for queries taking > 100ms
# Pattern: [LOG] duration: 250.000 ms
```

#### Index Strategy

```sql
-- BEFORE: Full table scan
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 123;
-- Result: Seq Scan on orders (cost=0.00..35000.00 rows=100000)

-- After adding index
CREATE INDEX idx_orders_user_id ON orders(user_id);

-- AFTER: Index scan (100x faster)
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 123;
-- Result: Index Scan using idx_orders_user_id (cost=0.29..15.55 rows=10)

-- Performance: 35000ms → 15ms = 2,333x faster!
```

**Index creation strategy:**

```bash
# 1. Monitor slow queries for 1 week
# 2. Identify most expensive queries
# 3. Create indexes on filter/join columns
# 4. Test index impact (EXPLAIN ANALYZE)
# 5. Monitor query execution time after deployment

# Production index creation (non-blocking):
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

# This allows queries to continue while index builds
# Standard CREATE INDEX locks the table
```

#### Connection Pooling

```bash
# Without pooling: Each ECS task = 5-10 database connections
# Problem: 3 tasks = 15 connections, but DB max is 45 (limit reached quickly)

# Solution: Use connection pooler (pgBouncer, PgBouncey)
docker run -d \
  --name pgbouncer \
  -p 6432:6432 \
  pgbouncer/pgbouncer \
  -c "
    [databases]
    myapp = host=myapp-rds.example.com port=5432 dbname=myapp
    
    [pgbouncer]
    pool_mode = transaction
    max_client_conn = 1000
    default_pool_size = 25
  "

# Result: 1 pooler connection per task vs 5-10 individual
# Total connections: 3 tasks × 1 = 3 connections (vs 15)
# Allows scaling to 10+ tasks without hitting connection limit
```

#### Prepared Statements

```python
# BAD: SQL injection risk, no query plan caching
query = f"SELECT * FROM users WHERE id = {user_id}"
cursor.execute(query)

# GOOD: Safe and cached query plans
query = "SELECT * FROM users WHERE id = %s"
cursor.execute(query, (user_id,))

# Performance: Second execution uses cached plan (+10x faster)
```

### Database Instance Right-Sizing

#### Understanding Instance Classes

| Class | vCPU | RAM | Cost/mo | Use Case |
|-------|------|-----|---------|----------|
| `db.t3.micro` | 1 | 1GB | $25 | Test, dev (free tier) |
| `db.t3.small` | 1 | 2GB | $50 | Light staging |
| `db.t3.medium` | 2 | 4GB | $100 | Heavy staging |
| `db.m6g.large` | 2 | 8GB | $200 | General production |
| `db.r6g.large` | 2 | 16GB | $400 | Memory-heavy production |
| `db.r6g.xlarge` | 4 | 32GB | $800 | High-concurrency production |

```bash
# Right-sizing query (current usage)
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod \
  --query 'DBInstances[0].[DBInstanceClass, AllocatedStorage]'

# Monitor actual usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-prod \
  --statistics Maximum,Average \
  --period 3600

# If max connections often near limit → need upgrade
# If CPU > 80% for extended periods → need upgrade
# If free memory < 1GB → need upgrade
```

---

## Caching Strategy

### Layer 1: Application Cache (ElastiCache Redis)

```python
from redis import Redis

redis = Redis(host='prod.12345.ng.0001.use1.cache.amazonaws.com', port=6379)

# Cache user data for 1 hour
def get_user(user_id):
    cache_key = f"user:{user_id}"
    
    # Try cache first
    cached = redis.get(cache_key)
    if cached:
        return json.loads(cached)  # Hit (milliseconds)
    
    # Miss - fetch from DB
    user = db.query("SELECT * FROM users WHERE id = %s", (user_id,))
    
    # Store in cache for 3600 seconds
    redis.setex(cache_key, 3600, json.dumps(user))
    
    return user

# Result:
# - Cache hit: 5ms response (vs 50ms from DB)
# - Cache miss: 50ms (full DB query)
# - 90% hit rate = average 9.5ms (5× faster)
```

**When to use Redis:**

```
✅ Session data (frequently accessed, short lived)
✅ User preferences (accessed on every request)
✅ Leaderboards (frequently updated)
✅ Rate limiting counters
✅ Cache-aside pattern (check cache before DB)

❌ Long-term storage (use RDS)
❌ Complex queries (use RDS)
❌ Data requiring ACID transactions
```

### Layer 2: Database Query Cache

```sql
-- PostgreSQL query results caching
-- Using materialized views for complex aggregations

-- Without cache: 45 seconds
SELECT COUNT(*) as total_orders,
       SUM(amount) as total_revenue,
       MAX(created_at) as latest_order
FROM orders
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at);

-- With materialized view: 50ms (first query), < 1ms (subsequent queries)
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT DATE(created_at) as day,
       COUNT(*) as total_orders,
       SUM(amount) as total_revenue
FROM orders
GROUP BY DATE(created_at);

-- Query the materialized view
SELECT * FROM daily_revenue
WHERE day > NOW() - INTERVAL '30 days'
ORDER BY day DESC;

-- Refresh on schedule (e.g., every hour)
REFRESH MATERIALIZED VIEW CONCURRENTLY daily_revenue;
```

### Layer 3: HTTP Caching (CloudFront CDN)

```hcl
# CloudFront distribution for static assets

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id   = "myAssets"
  }

  enabled = true
  
  # Cache behavior for static assets
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "myAssets"
    
    # Cache for 24 hours (static assets rarely change)
    default_ttl = 86400
    max_ttl     = 31536000
    
    viewer_protocol_policy = "redirect-to-https"
    
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  
  # Cache behavior for API (shorter TTL)
  cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "myAssets"
    
    default_ttl = 0               # No caching for API
    max_ttl     = 0
    
    viewer_protocol_policy = "https-only"
  }
}

# Result:
# - Static assets: 300× faster (CDN edge vs S3 direct)
# - API requests: No cache (always fresh)
# - Bandwidth savings: 80% (cached at CDN edge)
```

---

## Infrastructure Tuning

### ECS Deployment Optimization

#### Canary Deployments

```hcl
# Deploy new version to 10% of tasks first

resource "aws_ecs_service" "myapp" {
  name            = "myapp-service"
  cluster         = aws_ecs_cluster.prod.id
  task_definition = aws_ecs_task_definition.myapp.arn
  desired_count   = 10

  deployment_circuit_breaker {
    enable   = true
    rollback = true  # Auto-rollback if > 50% fail
  }

  deployment_configuration {
    minimum_healthy_percent = 90  # Keep 9 tasks running
    maximum_percent         = 110  # Start 1 new task
  }
}

# Timeline:
# - Start: 10 old tasks, deploy 1 new task
# - Check: Health checks on new task
# - Success: Stop 1 old task
# - Repeat: Gradually replace all tasks (10 minutes total)
# - Rollback: If > 50% fail, automatically revert
```

**Performance benefit:**
- Zero downtime (ALB health checks continue)
- Automatic rollback (if something breaks)
- Slow rollout (catch issues early)

#### Connection Draining

```hcl
# Graceful deregistration from load balancer

resource "aws_lb_target_group" "myapp" {
  name             = "myapp-tg"
  port             = 8080
  protocol         = "HTTP"
  vpc_id           = aws_vpc.main.id
  
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }
  
  deregistration_delay = 30  # Wait 30s before killing connections

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }
}

# Timeline during deployment:
# - New connections: Sent to new task
# - Existing connections: Left alone for up to 30s
# - After 30s: Connections forcefully closed
# - Result: No request errors during rollout
```

---

## Network Optimization

### VPC Endpoint Optimization

```bash
# Without VPC Endpoint:
# Request → NAT Gateway → Internet → AWS API → Response
# Cost: 0.045/GB = $0.045 per GB transferred
# Latency: 100-200ms (internet routing)

# With VPC Endpoint:
# Request → Endpoint → AWS API → Response (direct, no internet)
# Cost: $0.01/hour + $0.01/GB = 80% cheaper
# Latency: 10-20ms (direct, low-latency)

# Setup VPC Endpoints for common services:
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-xxxxx \
  --vpc-endpoint-type Interface \
  --service-name com.amazonaws.us-east-1.s3 \
  --subnet-ids subnet-xxxxx subnet-yyyyy
```

**Cost comparison (1 TB/month S3 access):**
- Without endpoint: 1,000 GB × $0.045 = $45/month
- With endpoint: Fixed $7.20 + (1,000 × $0.01) = $17.20/month
- **Savings: $27.80/month (62%)**

---

## Monitoring & Profiling

### Setting Up CloudWatch Dashboards

```bash
# Create custom metric for application response time
aws cloudwatch put-metric-data \
  --metric-name ApplicationResponseTime \
  --namespace MyApp \
  --value 125 \
  --unit Milliseconds \
  --dimensions Environment=prod Service=api

# Set up alarm on P99 response time
aws cloudwatch put-metric-alarm \
  --alarm-name high-response-time \
  --metric-name ApplicationResponseTime \
  --namespace MyApp \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 1000 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:xxxx:alerts
```

### Application Profiling

```python
# Example: Profile slow endpoint

import time
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/api/users/<user_id>')
def get_user(user_id):
    start = time.time()
    
    # Database query
    user = db.query("SELECT * FROM users WHERE id = %s", (user_id,))
    log_time("db_query", time.time() - start)
    
    # Format response
    response = format_user(user)
    log_time("format", time.time() - start)
    
    # Cache update
    cache.set(f"user:{user_id}", user)
    log_time("cache_update", time.time() - start)
    
    total = time.time() - start
    log_time("total_request", total)
    
    return jsonify(response)

def log_time(step, duration):
    print(f"{step}: {duration*1000:.1f}ms")

# Output:
# db_query: 45.2ms
# format: 5.1ms
# cache_update: 2.3ms
# total_request: 52.6ms
```

**Example profiling results:**
- Database: 45ms (86%)
- Formatting: 5ms (10%)
- Caching: 2ms (4%)
- **Optimization target: Database queries (46% of time)**

---

## Cost vs Performance Trade-offs

### Decision Matrix

| Optimization | Cost Impact | Performance Impact | Effort | ROI |
|--------------|-----------|-------------------|---------|-----|
| Add Redis cache | +$100/mo | 5× faster (+400ms) | 2 days | EXCELLENT |
| Read replicas (2×) | +$200/mo | Scale reads 2× | 1 day | EXCELLENT |
| Upgrade DB class | +$200/mo | 2× query speed | 0.5 days | GOOD |
| CDN for assets | +$20/mo | 10× faster assets | 3 days | EXCELLENT |
| Reserved instances | -30% | Same speed | 0 days | EXCELLENT |
| Spot instances | -80% | Same speed | 2 days | EXCELLENT (non-prod) |
| Query optimization | $0 | 10× faster | 3 days | EXCELLENT |

### Production Optimization Path

```
Week 1: Profiling & Bottleneck ID
├─ Monitor slow queries (1 week)
├─ Identify application bottlenecks
└─ Prioritize improvements

Week 2-3: Quick Wins (free/cheap)
├─ Add database indexes
├─ Implement Redis cache
├─ Enable CloudFront CDN
└─ Optimize Docker image

Week 4-6: Infrastructure Improvements
├─ Scale read replicas (if needed)
├─ Upgrade DB instance class (if needed)
├─ Use Reserved Instances (save 30%)
└─ Implement SQS queues (for async work)

Measure Results:
├─ Response time: Before 500ms → After 200ms (2.5× faster)
├─ Cost change: Before $1,200 → After $1,350 (+12%, but way faster)
└─ User experience: Improved adoption, better conversion
```

---

## Performance Targets

### Response Time SLAs

```
User-facing endpoints:
├─ P50: < 100ms
├─ P95: < 500ms
├─ P99: < 1000ms
└─ Max: < 5000ms

API endpoints (internal):
├─ P50: < 50ms
├─ P99: < 200ms
└─ Max: < 1000ms

Background jobs:
├─ Acceptable: < 10 minutes
└─ Error: > 30 minutes
```

### Monitoring Alert Thresholds

```hcl
# High response time alert
aws cloudwatch put-metric-alarm \
  --alarm-name prod-high-response-time \
  --metric-name TargetResponseTime \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 1 \                    # 1 second (Prod SLA)
  --comparison-operator GreaterThanThreshold

# High error rate alert
aws cloudwatch put-metric-alarm \
  --alarm-name prod-high-error-rate \
  --metric-name HTTPCode_Target_5XX \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 60 \
  --threshold 10 \                   # 10 errors per minute
  --comparison-operator GreaterThanThreshold
```

---

## Quick Reference: Top 10 Optimizations

| # | Optimization | Performance Gain | Cost Change | Effort |
|---|--------------|-----------------|-------------|--------|
| 1 | Database indexing | 10-100× query speed | $0 | Low |
| 2 | Redis cache | 5-10× response time | +$100/mo | Mid |
| 3 | Connection pooling | 3× throughput | $0 | Mid |
| 4 | CloudFront CDN | 300× asset speed | +$20/mo | Low |
| 5 | Reserved instances | 30% cost savings | -$360/yr | None |
| 6 | Query optimization | 10-50× query speed | $0 | High |
| 7 | Read replicas | 2× read throughput | +$200/mo | Low |
| 8 | Docker layer caching | 80% faster builds | $0 | Low |
| 9 | Canary deployments | Zero-downtime deploys | $0 | Mid |
| 10 | VPC endpoints | 80% data cost savings | -$27/mo each | Low |

---

## References

- [AWS RDS Performance Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [ECS Container Optimization](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/container_agent_options.html)
- [ElastiCache Best Practices](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/BestPractices.html)
- [CloudFront Optimization](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/GeneralOptimizations.html)
- [PostgreSQL Query Optimization](https://www.postgresql.org/docs/current/sql-explain.html)
