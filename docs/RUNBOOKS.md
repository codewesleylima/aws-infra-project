# Operational Runbooks

Complete step-by-step guides for common operational tasks.

## Quick Navigation

- [Deployment Runbook](#deployment-runbook) - How to deploy to each environment
- [Rollback Runbook](#rollback-runbook) - How to undo a deployment
- [Scaling Runbook](#scaling-runbook) - How to scale infrastructure
- [Incident Response](#incident-response) - How to handle outages
- [Database Operations](#database-operations) - RDS maintenance and recovery
- [Backup & Recovery](#backup-recovery) - Backup and restore procedures
- [Monitoring & Alerting](#monitoring-alerts) - Alert response procedures

---

## Deployment Runbook

### Pre-deployment Checklist

- [ ] All tests passing in CI/CD
- [ ] Code reviewed and approved by 2+ team members (prod)
- [ ] Feature branch is up to date with main/hom
- [ ] No open security vulnerabilities
- [ ] Terraform plan reviewed (no unexpected deletions)
- [ ] Database migrations prepared (if applicable)
- [ ] Rollback plan documented
- [ ] Stakeholders notified of deployment window
- [ ] Monitoring dashboards open and watched

### Dev Environment Deployment

**Duration:** 5-10 minutes

```bash
# 1. Ensure you're on the latest develop branch
git checkout develop
git pull origin develop

# 2. Plan the infrastructure changes
cd infra/environments/dev
terraform plan -out=tfplan

# 3. Review the plan - should only show expected changes
# Look for any "destroy" operations that shouldn't happen

# 4. Apply the changes
terraform apply tfplan

# 5. Deploy application
# (Push to dev branch triggers CI/CD)
git push origin develop

# 6. Verify deployment
# - Check CloudWatch logs in AWS console
# - Run smoke tests: make check-dev
# - Verify ALB health check: curl http://dev-alb-xxx.elb.amazonaws.com/health
```

### Hom Environment Deployment

**Duration:** 15-20 minutes

```bash
# 1. Create release branch from develop
git checkout develop
git pull origin develop
git checkout -b release/v$(date +%Y%m%d-%H%M%S)

# 2. Update version files
# - Update VERSION file
# - Update CHANGELOG.md with release notes
git add VERSION CHANGELOG.md
git commit -m "chore(release): version bump for hom release"

# 3. Push to GitHub
git push origin release/v*

# 4. Open pull request from release/* to hom
# - Title: "Release: v1.2.3"
# - Description: Link to tickets, list of changes
# - Wait for 1+ approval

# 5. Plan hom infrastructure
cd infra/environments/hom
terraform plan -out=tfplan

# 6. Merge to hom
# (GitHub status checks will run automatically)
git merge --no-ff release/v*

# 7. Verify hom deployment
# - Check ALB health: curl https://hom-alb-xxx.elb.amazonaws.com/health
# - Run smoke tests: ./scripts/smoke-tests.sh hom
# - Check logs: aws logs tail /ecs/myapp-hom --follow
# - Monitor metrics for 10 minutes

# 8. Clean up release branch
git branch -d release/v*
```

### Production Environment Deployment

**Duration:** 30-45 minutes (with verification)

```bash
# 1. Verify hom is healthy
# (If not, halt deployment and investigate)
./scripts/smoke-tests.sh hom
# All tests must pass

# 2. Create pull request from hom to main
git checkout main
git pull origin main
git merge hom --no-ff
# OR use GitHub UI:
# - Go to Pull Requests
# - Click "New Pull Request"
# - Base: main, Compare: hom

# 3. Deployment requires minimum 2 approvals
# Wait for:
# - Code owners to review
# - All CI/CD checks to pass
# - Security scan to pass (no critical issues)

# 4. Obtain explicit approval from team lead
# For breaking changes or major deployments:
# - Slack: @devops-leads
# - Email: devops@company.com
# - Get written approval before proceeding

# 5. Merge to main
# GitHub will trigger production deployment automatically

# 6. Monitor deployment closely
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name DesiredTaskCount \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average

# 7. Run comprehensive smoke tests
./scripts/smoke-tests.sh prod

# 8. Monitor for 30 minutes
# - Watch CloudWatch dashboards
# - Monitor error rates
# - Check application logs
# - Monitor database connections

# 9. Post-deployment
# - Notify stakeholders of successful deployment
# - Update release notes
# - Document any issues encountered
# - Close related GitHub issues marked as "shipped"
```

### Monitoring Deployment Progress

```bash
# Watch ECS task rollout
watch -n 5 'aws ecs describe-services \
  --cluster prod \
  --services myapp-service \
  --query "services[0].{RunningCount:runningCount,DesiredCount:desiredCount,Pending:pendingCount}" \
  --output table'

# Expected progression:
# Time  Running  Desired  Pending  Status
# 0s    3        3        3        (new tasks starting)
# 30s   3        3        2        (1 new task running)
# 60s   2        3        1        (old tasks stopping)
# 90s   3        3        0        ✅ Ready (new version stable)

# If > 2 minutes for rollout, investigate:
# - Check task logs: aws logs tail /ecs/myapp-prod --follow
# - Check ALB target health
# - Check container metrics (CPU, memory)

# If > 5 minutes without progress → ROLLBACK (see Rollback Runbook)
```

---

## Rollback Runbook

**When to Rollback:**
- Error rate increases >50% after deployment
- P99 latency increases >200ms after deployment
- Database errors increase significantly
- Critical functionality broken
- Security issue discovered in deployed code

### Quick Rollback (< 5 minutes)

```bash
# 1. Alert team immediately
# Slack: @oncall
# Message: "Rolling back production due to [reason]"

# 2. Revert the last commit on main
git checkout main
git pull origin main
git reset --hard HEAD~1
git push origin main --force

# ALTERNATIVE: Use GitHub UI
# - Go to Code → Commits
# - Right-click on the bad commit
# - Select "Revert" → Creates new commit that undoes changes
# - This is preferred (creates audit trail)

# 3. Monitor rollback
watch -n 5 'aws ecs describe-services \
  --cluster prod \
  --services myapp-service \
  --query "services[0].{Running:runningCount,Desired:desiredCount}" \
  --output table'

# Wait for tasks to stabilize (usually 2-3 minutes)

# 4. Verify rollback worked
curl https://prod-alb.example.com/health
./scripts/smoke-tests.sh prod

# 5. Confirm metrics recovered
# - Error rate back to baseline
# - Latency normal
# - Database connections normal
# - All health checks passing

# 6. Post-mortém (within 24 hours)
# - Document what went wrong
# - Root cause analysis
# - Preventive measures
# - Update runbooks if needed
```

### Terraform Rollback

If infrastructure change caused the issue:

```bash
# 1. Identify the bad commit
git log --oneline infra/environments/prod/main.tf | head -5

# 2. Revert the specific change
git revert <commit-hash> --no-edit

# 3. Push the revert commit
git push origin main

# 4. Plan and apply revert
cd infra/environments/prod
terraform plan -out=tfplan
terraform apply tfplan

# 5. Verify infrastructure reverted
# - Check resources in AWS console
# - Verify no data loss
# - Run application tests
```

---

## Scaling Runbook

### Scale Up ECS Tasks (increase running tasks)

```bash
# 1. Check current state
aws ecs describe-services \
  --cluster prod \
  --services myapp-service \
  --query 'services[0].{Desired:desiredCount,Running:runningCount}'

# 2. Increase desired count
# Option A: AWS Console
# - ECS → Clusters → prod → myapp-service
# - Update Service → Number of tasks: 10 (change from 3)

# Option B: CLI
aws ecs update-service \
  --cluster prod \
  --service myapp-service \
  --desired-count 10

# Option C: Terraform
# Modify infra/environments/prod/main.tf
# Change: desired_count = 10
# Then: terraform apply

# 3. Monitor scaling
watch -n 5 'aws ecs describe-services \
  --cluster prod \
  --services myapp-service \
  --query "services[0].{Running:runningCount,Desired:desiredCount}" \
  --output table'

# 4. Verify health
curl https://prod-alb.example.com/health
# Should show healthy instances across AZs

# 5. Monitor resource usage
# CloudWatch > Dashboards > ECS
# - CPU usage should remain < 60%
# - Memory usage should remain < 70%
# - Check RDS connections (shouldn't exceed max_connections)
```

### Scale Down ECS Tasks

```bash
# 1. Drain connections gracefully
# Most load balancers wait 30s before removing unhealthy instances

# 2. Update desired count
aws ecs update-service \
  --cluster prod \
  --service myapp-service \
  --desired-count 3

# 3. Monitor scale down
watch -n 5 'aws ecs describe-services \
  --cluster prod \
  --services myapp-service \
  --query "services[0].{Running:runningCount,Desired:desiredCount}" \
  --output table'

# Expected: Running count decreases as tasks stop gracefully
```

### Scale RDS (change instance class)

**WARNING: Downtime required (2-5 minutes)**

```bash
# 1. Notify stakeholders
# "Scheduled database maintenance: db.t3.large → db.r6g.large"
# "Expect 2-3 minute downtime at 02:00 UTC"

# 2. Create snapshot before maintenance
aws rds create-db-snapshot \
  --db-instance-identifier myapp-prod \
  --db-snapshot-identifier myapp-prod-before-upgrade-$(date +%s)

# 3. Schedule maintenance window
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod \
  --db-instance-class db.r6g.large \
  --multi-az \
  --apply-immediately

# Or schedule for specific time:
# --preferred-maintenance-window "sun:02:00-sun:03:00"

# 4. Monitor upgrade progress
watch -n 10 'aws rds describe-db-instances \
  --db-instance-identifier myapp-prod \
  --query "DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}"'

# Expected states:
# 1. "available" (current)
# 2. "modifying" (2-5 minutes)
# 3. "available" (new size)

# 5. Verify after upgrade
# - Application still running
# - Database responding to queries
# - Connections normal
# - Performance improved (check CloudWatch)

# 6. Delete old snapshot if successful (after 7 days)
aws rds delete-db-snapshot \
  --db-snapshot-identifier myapp-prod-before-upgrade-xxxxx
```

---

## Incident Response

### P1 Incident: Service Completely Down

```bash
# 1. DECLARE INCIDENT (0s)
# Slack: #incidents (or #pagerduty)
# Message: "P1: Production myapp service down"
# Start: incident call/bridge

# 2. IMMEDIATE TRIAGE (30s)
# Check:
# - Is ALB responding?
#   curl -I https://prod-alb.example.com
# - Are ECS tasks running?
#   aws ecs describe-services --cluster prod --services myapp-service
# - Are databases responding?
#   aws rds describe-db-instances --db-instance-identifier myapp-prod

# 3. ASSESS BLAST RADIUS (1min)
# - How many users affected? 100% or 10%?
# - Is it all regions or specific region?
# - Check recent deployments:
#   git log --oneline -n 5

# 4. IMPLEMENT QUICK FIX (2-5min)
# Option A: Scale up if under capacity
#   aws ecs update-service --cluster prod --service myapp-service --desired-count 15
# Option B: Rollback recent deployment (see Rollback section)
# Option C: Restart ECS tasks
#   aws ecs update-service --cluster prod --service myapp-service --force-new-deployment

# 5. MONITOR RECOVERY (5min)
# Watch metrics until service stabilizes
# - Request rate recovering
# - Error rate returning to baseline
# - Latency normal

# 6. POST-INCIDENT (24-48 hours)
# - Write post-mortem
# - Root cause analysis
# - Preventive measures
# - Update docs/runbooks
```

### P2 Incident: Elevated Error Rate

```bash
# 1. Determine source
# Check application logs:
aws logs filter-log-events \
  --log-group-name /ecs/myapp-prod \
  --filter-pattern ERROR \
  --start-time $(($(date +%s - 600) * 1000)) \
  | head -20

# Or check database logs:
aws rds describe-db-log-files \
  --db-instance-identifier myapp-prod

# 2. If recent deployment is cause
# Rollback (see Rollback section)

# 3. If database is cause
# Check connections/queries:
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=myapp-prod

# 4. If caused by external service (e.g., payment gateway)
# - Notify users
# - Implement fallback/retry logic
# - Monitor for recovery

# 5. Scale if caused by traffic spike
# See Scaling section above
```

---

## Database Operations

### Create RDS Snapshot (Backup)

```bash
aws rds create-db-snapshot \
  --db-instance-identifier myapp-prod \
  --db-snapshot-identifier myapp-prod-manual-$(date +%Y%m%d-%H%M%S)

# Verify snapshot created
aws rds describe-db-snapshots \
  --filters Name=db-instance-id,Values=myapp-prod \
  --query 'DBSnapshots[-1].{Id:DBSnapshotIdentifier,Status:Status,Time:SnapshotCreateTime}'
```

### Restore from RDS Snapshot

**WARNING: Creates new database instance**

```bash
# 1. List available snapshots
aws rds describe-db-snapshots \
  --filters Name=db-instance-id,Values=myapp-prod \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime]'

# 2. Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier myapp-prod-restored \
  --db-snapshot-identifier myapp-prod-manual-20240101-000000 \
  --db-instance-class db.r6g.large \
  --publicly-accessible false \
  --multi-az

# 3. Monitor restoration
watch -n 5 'aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-restored \
  --query "DBInstances[0].{Status:DBInstanceStatus,Time:InstanceCreateTime}"'

# 4. Verify data integrity
# - Connect to restored database
# - Run validation queries
# - Check row counts match

# 5. Update application to use new database
# OR delete old database if verified

aws rds delete-db-instance \
  --db-instance-identifier myapp-prod \
  --final-db-snapshot-identifier myapp-prod-final-backup-$(date +%s) \
  --skip-final-snapshot  # Don't create final snapshot
```

### Enable Enhanced Monitoring

```bash
# 1. Create IAM role (if not exists)
aws iam create-role \
  --role-name rds-enhanced-monitoring \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "monitoring.rds.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# 2. Attach policy
aws iam attach-role-policy \
  --role-name rds-enhanced-monitoring \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole

# 3. Enable on instance
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod \
  --monitoring-interval 60 \
  --monitoring-role-arn arn:aws:iam::ACCOUNT:role/rds-enhanced-monitoring \
  --apply-immediately

# 4. View metrics in CloudWatch
# RDS > Enhanced Monitoring > myapp-prod
```

---

## Backup & Recovery

### Automated Backups Status

```bash
# Check automated backup configuration
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod \
  --query 'DBInstances[0].{BackupRetention:BackupRetentionPeriod,Window:PreferredBackupWindow}'

# View recent automated backups
aws rds describe-db-snapshots \
  --filters Name=db-instance-id,Values=myapp-prod,Name=snapshot-type,Values=automated \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,DBSnapshotStatus]' \
  | tail -5
```

### Point-in-Time Recovery (PITR)

```bash
# Restore to specific point in time
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier myapp-prod \
  --target-db-instance-identifier myapp-prod-pitr \
  --restore-time 2024-01-15T14:30:00Z

# Monitor
watch 'aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-pitr \
  --query "DBInstances[0].DBInstanceStatus"'
```

---

## Monitoring & Alerts

### Understand CloudWatch Alarms

```bash
# List all alarms
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[*].[AlarmName,StateValue]'

# Check specific alarm
aws cloudwatch describe-alarms \
  --alarm-names "myapp-high-error-rate" \
  --query 'MetricAlarms[0]'
```

### Common Alert Responses

**Alert: High CPU (ECS)**
1. Check current workload
2. Check for memory pressure (might trigger swapping)
3. Scale up if sustained > 5 minutes
4. Profile application if new issue

**Alert: High Error Rate**
1. Check logs immediately
2. Identify error type (4xx vs 5xx)
3. Rollback if caused by deployment
4. Check external dependencies

**Alert: Database Connection Errors**
1. Check connection count
2. If at max_connections: scale RDS
3. Check for connection leaks in application
4. Implement connection pooling

---

## References & Additional Resources

- [AWS CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)
- [ECS Operational Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-best-practices.html)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/BestPractices.html)
- [Incident Response Templates](https://www.pagerduty.com/incident-response/)
