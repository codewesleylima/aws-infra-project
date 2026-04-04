# Infrastructure Cost Estimation & Optimization Guide

## Overview

This guide provides cost estimation methodology, breakdown by service, and optimization strategies for the AWS infrastructure.

## Quick Cost Estimates

| Environment | Minimum | Average | Maximum | Annual |
|------------|---------|---------|---------|--------|
| **Dev**    | $100    | $155    | $250    | $1,860 |
| **Staging**| $180    | $223    | $350    | $2,676 |
| **Prod**   | $500    | $850    | $1,500  | $10,200-18,000 |

**Total Monthly (All Environments): ~$1,228 - $2,128**

## Service Cost Breakdown

### 1. Compute - AWS ECS Fargate

**Pricing Model:** Pay-per-second for vCPU and memory

#### Dev Environment
- **Configuration:** 2 tasks × 0.25 vCPU × 512MB
- **Monthly Cost:** ~$15/month
- **Calculation:** 2 × 0.25 × 730 hours × $0.04582/vCPU-hour = $16.84/month

#### Staging Environment
- **Configuration:** 3 tasks × 0.5 vCPU × 1GB
- **Monthly Cost:** ~$35/month
- **Calculation:** 3 × 0.5 × 730 hours × $0.04582/vCPU-hour = $50.33/month

#### Production Environment
- **Configuration:** Min 3 × 1 vCPU × 2GB, Max 20 × 1 vCPU × 2GB
- **Monthly Cost:** $75-$500 depending on scaling
- **Baseline (3 tasks):** 3 × 1 × 730 × $0.04582 = $100/month
- **Peak (20 tasks):** 20 × 1 × 730 × $0.04582 = $668/month

**Optimization Strategies:**
1. **Capacity Discounts:** Fargate Spot instances save up to 70% (for non-critical tasks)
2. **Right-sizing:** Monitor CloudWatch metrics; adjust CPU/memory if under 30% utilization
3. **Scheduled Scaling:** Reduce task count during off-peak hours
4. **Commit Discounts:** 1-year committed use agreements save ~20%

### 2. Database - AWS RDS PostgreSQL

**Pricing Model:** By instance class + storage + backup

#### Dev Environment
- **Instance:** db.t3.micro (Multi-AZ)
- **Storage:** 20GB
- **Compute:** 744 hours × $0.108 = ~$80/month
- **Storage:** 20GB × $0.115/GB = $2.30/month
- **Backup Storage:** Included in multi-AZ
- **Total:** ~$85/month

#### Staging Environment
- **Instance:** db.t3.small (Multi-AZ)
- **Storage:** 30GB
- **Compute:** 744 hours × $0.217 = ~$162/month
- **Storage:** 30GB × $0.115/GB = $3.45/month
- **Total:** ~$165/month

#### Production Environment
- **Instance:** db.r6g.large (Multi-AZ, 2 replicas)
- **Storage:** 100GB with autoscaling to 500GB
- **Compute:** 744 × $0.693 = ~$516/month
- **Storage (100GB):** 100 × $0.115 = $11.50/month
- **Backup Retention (30 days):** ~$3-5/month
- **Enhanced Monitoring:** ~$5/month
- **Total:** ~$535-540/month

**Optimization Strategies:**
1. **Instance Sizing:** Use db.t3 (burstable) for non-critical envs, db.r6g (memory-optimized) for prod
2. **Graviton2 (r6g):** ~25% cheaper than Intel equivalent
3. **Storage Auto-scaling:** Set conservative max size
4. **Multi-AZ Savings Plan:** 1-3 year commitments save 30-50%
5. **Backup Retention:** Keep minimum necessary (7-30 days for dev/staging)

### 3. Load Balancing - AWS ALB

**Pricing Model:** Hourly charge + processed request fees

#### All Environments
- **ALB Hourly:** $0.0225/hour × 730 = ~$16/month
- **Processed Requests (1M/month):** 1M × $0.006 = $6/month
- **LCU Hours (Avg 10 capacity units):** 10 × 730 × $0.006 = $44/month
- **Total per ALB:** ~$66/month

**Note:** Production typically has slightly higher LCU usage

**Optimization Strategies:**
1. **Network Load Balancer:** For non-HTTP protocols, NLB can be 30% cheaper
2. **Request Consolidation:** Use keep-alive connections to reduce LCU consumption
3. **Scheduled Scaling:** ALB charges even when idle; consider disabling in off-hours

### 4. Networking - AWS VPC

**Pricing Model:** NAT Gateway, VPC Endpoints, Data Transfer

#### NAT Gateway Costs
- **Per NAT Gateway:** $0.045/hour (not including data processing)

##### Dev (1 NAT Gateway)
- **Hourly:** $0.045/hour × 730 = ~$33/month
- **Data Processing:** 10GB × $0.045/GB = ~$0.45/month
- **Total:** ~$35/month

##### Staging (1 NAT Gateway)
- **Total:** ~$35/month

##### Production (3 NAT Gateways for HA)
- **Hourly:** $0.045 × 3 × 730 = ~$99/month
- **Data Processing:** 50GB × $0.045 = ~$2.25/month
- **Total:** ~$101/month

#### VPC Endpoints (S3, ECR, CloudWatch)
- **Interface Endpoints:** $7.20/month per endpoint × 3 endpoints = $21.60/month
- **S3 Gateway Endpoint:** Free (recommended)
- **Hourly Queries:** 1000 queries/month × $0.01 = ~$10/month

**Optimization Strategies:**
1. **S3 Gateway Endpoint:** Use for S3 instead of NAT Gateway (saves ~50% on NAT data costs)
2. **Consolidate Endpoints:** One endpoint per service is sufficient
3. **Monitoring:** Use VPC Flow Logs to identify unnecessary traffic patterns

### 5. Storage - Amazon S3

**Pricing Model:** Storage, requests, data transfer

#### Dev/Staging
- **Standard Storage:** 50GB × $0.023 = ~$1.15/month
- **Requests (PUTs, GETs):** 10,000 × $0.005 = ~$0.05/month
- **Total:** ~$1.20/month per environment

#### Production
- **Standard Storage:** 500GB × $0.023 = ~$11.50/month
  - ALB Logs (30-day retention): 200GB
  - Application Data: 250GB
  - CloudTrail Logs: 50GB (90-day retention)
- **Intelligent-Tiering:** Transitions to cheaper classes automatically (~20% savings for infrequent access)
- **Glacier Transition (90+ days):** Saves 75% vs. Standard
- **Lifecycle Policies:** Archive logs to Glacier after 30-90 days

**S3 Cost Breakdown for Production:**
- **Standard (hot data, 30 days):** 200GB × $0.023 = $4.60
- **Intelligent-Tiering (warm data):** 150GB × $0.0125 = $1.88
- **Glacier (cold data, 90+ days):** 150GB × $0.004 = $0.60
- **Requests:** 50,000 × $0.005 = $0.25
- **Data Retrieval:** ~$2-5/month (Glacier retrieval)
- **Total:** ~$9-12/month

**Optimization Strategies:**
1. **Intelligent-Tiering:** Enable for ALB logs bucket automatically
2. **Lifecycle Rules:** Archive after 30 days, delete after 90-180 days
3. **Glacier Long-term:** Annual legal holds or compliance logs
4. **S3 Select:** Query specific files instead of downloading full objects

### 6. Logging & Monitoring - CloudTrail, KMS, CloudWatch

#### CloudTrail (Production)
- **Data Events:** $0.10 per 100k events
- **Typical Usage:** 1M events × $0.001 = ~$10/month
- **S3 Storage:** Included in bucket cost
- **Log Validation:** Free

#### KMS - Key Management
- **Key Storage:** $1/month per key
- **API Requests:** $0.03 per 10k requests
- **Production Usage:** 1 key + API calls = ~$2-3/month

#### CloudWatch Logs
- **Ingestion:** $0.50 per GB ingested
- **Production Logs:** 10GB/month × $0.50 = ~$5/month
- **Storage:** 30-day retention × $0.03/GB = ~$10/month
- **Log Insights:** ~$0.005 per GB scanned

#### CloudWatch Metrics & Dashboards
- **Standard Metrics:** Free (EC2, ECS, RDS, ALB)
- **Custom Metrics:** $0.30 per custom metric per month
- **Alarms:** Free

**Total CloudWatch/Logging (Prod): ~$30-40/month**

### 7. Data Transfer & Bandwidth

#### Intra-region (same AZ)
- **Free** between ECS tasks and RDS

#### Intra-AWS (cross-region)
- **Per GB:** $0.02 in, free out

#### Internet (Egress)
- **First 1GB:** Free
- **1-10TB:** $0.09/GB
- **10TB+:** $0.085/GB

**Production Estimate:**
- **Outbound (typical):** 50-100GB/month = $4.50-9/month
- **If significant API calls or downloads:** $20-100/month

## Environment-by-Environment Breakdown

### Development Environment ($155/month vs ~$1,860/year)

| Service | Quantity | Rate | Monthly |
|---------|----------|------|---------|
| ECS Fargate | 512MB × 2 tasks | $0.04582/vCPU | $15 |
| RDS db.t3.micro | Multi-AZ | $0.108/hr | $80 |
| NAT Gateway | 1 × 730hrs | $0.045/hr | $33 |
| VPC Endpoints | 2 endpoints | $7.20 | $14 |
| ALB | 1 × 730hrs | $0.0225/hr | $16 |
| S3 Storage | 50GB | $0.023/GB | $1 |
| CloudWatch | Logs & Metrics | - | $5 |
| **TOTAL** | | | **$164** |

**Optimization Potential:** ~20% ($30-40/month) through:
- Using NAT Gateway only during business hours
- Reducing RDS backup retention to 7 days
- Using spot instances for batch jobs

### Staging Environment ($223/month vs ~$2,676/year)

| Service | Quantity | Rate | Monthly |
|---------|----------|------|---------|
| ECS Fargate | 512MB × 3 tasks | $0.04582/vCPU | $35 |
| RDS db.t3.small | Multi-AZ | $0.217/hr | $162 |
| NAT Gateway | 1 × 730hrs | $0.045/hr | $33 |
| ALB | 1 × 730hrs | $0.0225/hr | $16 |
| VPC Endpoints | 2 endpoints | $7.20 | $14 |
| CloudTrail | 500k events | - | $5 |
| S3 & Logs | 70GB | $0.023/GB | $2 |
| CloudWatch | Logs & Metrics | - | $8 |
| **TOTAL** | | | **$275** |

**Optimization Potential:** ~25% ($50-75/month) through Reserved Instances

### Production Environment ($850/month vs ~$10,200/year)

| Service | Quantity | Rate | Monthly |
|---------|----------|------|---------|
| ECS Fargate | 1GB × 3-8 avg | $0.04582/vCPU | $150 |
| RDS db.r6g.large | Multi-AZ × 2 | $0.693/hr | $516 |
| NAT Gateways | 3 × 730hrs | $0.045/hr | $99 |
| Application Load Balancer | 1 × 730hrs | $0.0225/hr | $66 |
| VPC Endpoints | 3 endpoints | $7.20 | $22 |
| CloudTrail | 1M events | $0.10/100k | $10 |
| KMS Key + API | Storage + calls | - | $3 |
| S3 (Storage + Archive) | 500GB + archive | $0.023/GB | $15 |
| CloudWatch | Logs, metrics, alarms | - | $40 |
| Data Transfer | 50-100GB egress | $0.09/GB | $5-9 |
| **TOTAL** | | | **~$926** |

**Optimization Potential:** ~30-40% ($250-400/month) through:
- Reserved Instances (RDS: 30-50% savings)
- Fargate Spot for non-critical tasks (up to 70% savings)
- Scheduled scaling (10-30% reduction)
- S3 Intelligent-Tiering (15-20% savings on logs)

## Optimization Roadmap

### Immediate (< 1 week, 10-15% savings)
1. Enable S3 Intelligent-Tiering on ALB logs bucket
2. Set S3 lifecycle policy: Standard → Glacier after 30 days, delete after 90
3. Reduce CloudTrail log retention from 90 to 45 days
4. **Potential Savings:** $30-50/month

### Short-term (1-2 weeks, 20-30% savings)
1. Implement Fargate Spot for staging environment
2. Optimize ECS task CPU/memory based on CloudWatch metrics
3. Set up auto-scaling schedule (scale down 22:00-06:00 UTC)
4. **Potential Savings:** $80-120/month

### Medium-term (1-2 months, 30-40% savings)
1. Purchase 1-year Reserved Instances for RDS production ($200/month savings)
2. Set up AWS Budgets with cost anomaly detection
3. Implement cross-region replication only for critical data
4. **Potential Savings:** $200-250/month

### Long-term (Ongoing optimization)
1. Evaluate Graviton3 instances for ECS tasks (5-10% better price/performance)
2. Implement data compression for CloudTrail logs
3. Use Amazon ElastiCache for application caching (reduce RDS read load)
4. Consider Dedicated Hosts for long-term workloads (10-20% discount)
5. **Potential Savings:** $100-200/month cumulative

## Cost Monitoring & Alerts

### AWS Cost Explorer Setup

```bash
# View costs over the last 30 days
# by service, environment, and cost center
```

**Configure:**
1. **AWS Budgets:** Set monthly budget alerts at $500, $750, $1000
2. **Cost Anomaly Detection:** Automatic alerts if spending increases >15%
3. **Cost Explorer:** Weekly review of top 5 cost drivers
4. **CloudTrail:** Track all cost-impacting changes (RDS upsizing, NAT gateway additions)

### Dashboards & Reports

- **Monthly Cost Report:** Share with stakeholders on 1st of month
- **Environment Comparison:** Track dev vs staging vs prod cost ratio
- **Reserved Instance Utilization:** Ensure purchased plans are fully used
- **Chargeback Model:** Allocate costs to teams/projects

## Reserved Instance & Savings Plan Recommendations

### For Production RDS
- **Current:** db.r6g.large Multi-AZ = $516/month × 12 = $6,192/year
- **1-Year Savings Plan (36%):** $3,963/year savings
- **3-Year Reserved Instance (50%):** $3,096/year savings
- **Recommendation:** 3-year RDS Reserved Instance = **$3,096/year vs $6,192/year**

### For Production ECS
- **Current:** ~$150/month (average) = $1,800/year
- **1-Year Commitment:** 20% savings = $360/year
- **Recommendation:** Fargate Compute Savings Plan for baseline tasks

### Mixed Strategy
- **Core Services (RDS):** 3-year Reserved Instance (50% discount)
- **Baseline Compute (ECS):** 1-year Fargate Savings Plan (20% discount)
- **Overflow/Spike:** Spot instances (70% discount)
- **Total Annual Savings:** ~$1,500-2,000

## Cost Attribution & Chargeback

### By Environment
```
Dev:     $155/month = 13%
Staging: $223/month = 18%
Prod:    $850/month = 69%
```

### By Service
```
Compute (ECS):     35% - Most variable
Database (RDS):    45% - Baseline cost
Networking:        12% - NAT, ALB, VPC
Storage & Logs:    5% - S3, CloudTrail
Monitoring:        3% - CloudWatch, KMS
```

## Tools & Commands

### Estimate Costs (Infracost)
```bash
./scripts/estimate-costs.sh all              # All environments
./scripts/estimate-costs.sh prod             # Production only
./scripts/estimate-costs.sh prod json        # JSON format
./scripts/estimate-costs.sh dev html         # HTML report
```

### Make Shortcuts
```bash
make cost-estimate                           # Run cost estimation
```

### AWS CLI Queries
```bash
# Last 7 days costs by service
aws ce get-cost-and-usage \
  --time-period Start=2024-03-22,End=2024-03-29 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# RDS costs only
aws ce get-cost-and-usage \
  --time-period Start=2024-03-01,End=2024-03-29 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Relational Database Service"]}}'
```

## Frequently Asked Questions

### Q: Which service costs the most?
**A:** RDS (~45% of total) due to Multi-AZ and instance size. Optimize through Reserved Instances.

### Q: How can I reduce costs without affecting performance?
**A:** 
1. Enable S3 Intelligent-Tiering
2. Use Fargate Spot for non-critical tasks
3. Implement scheduled scaling
4. Right-size RDS instance (monitor CPU/memory)

### Q: What's the true cost of downtime?
**A:** Consider business impact, SLA penalties, customer trust. Often justifies higher uptime costs.

### Q: Should we use a single large RDS or multiple smaller instances?
**A:** Multi-AZ single instance (current setup) is cost-effective for traditional apps. Consider Aurora (PostgreSQL-compatible, cheaper) for serverless workloads.

### Q: How much would it cost to add a second region?
**A:** ~$800-1000/month for basic HA across regions. Evaluate RTO/RPO requirements.

## References

- [AWS Pricing Calculator](https://calculator.aws/)
- [Infracost Documentation](https://www.infracost.io/)
- [AWS Cost Optimization Hub](https://aws.amazon.com/aws-cost-management/)
- [Reserved Instance Pricing](https://aws.amazon.com/ec2/reservedinstances/)
- [Savings Plans](https://aws.amazon.com/savingsplans/)
