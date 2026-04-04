# Disaster Recovery Procedures

Comprehensive guide to backup, recovery, and failover strategies for the AWS infrastructure.

## Recovery Objectives

### RTO/RPO Targets by Environment

| Environment | RTO | RPO | Backup Frequency | Retention |
|------------|-----|-----|------------------|-----------|
| **dev** | > 1 hour | > 1 day | Manual | 3 days |
| **staging** | < 30 min | < 1 hour | Hourly | 7 days |
| **prod** | < 5 min | = 0 min | Every 15min | 30 days |

- **RTO (Recovery Time Objective)**: How long before system is back online
- **RPO (Recovery Point Objective)**: Maximum acceptable data loss

### Availability Targets

| Environment | SLA | Max Downtime/month |
|------------|-----|---|
| dev | None | Unlimited |
| staging | 95% | 36 hours |
| prod | 99.99% | 4 minutes |

## Backup Strategy

### What Gets Backed Up

1. **Database (RDS)**
   - Automated daily snapshots
   - Continuous binary logs (point-in-time recovery)
   - Read replicas for quick promotion
   - Cross-region replication

2. **Application Code**
   - Git repository (GitHub)
   - Container images (ECR)
   - Terraform state files
   - Configuration files

3. **Application Data**
   - S3 buckets with versioning
   - Versioning-enabled buckets
   - Lifecycle policies (archive older versions)
   - Cross-region replication

4. **Logs & Monitoring**
   - CloudWatch Logs (30-day retention)
   - CloudTrail audit logs (7 years)
   - Application logs in S3

### Backup Locations

```
AWS Account (Primary)
├── RDS Primary Database (us-east-1)
│   ├── Automated Snapshots
│   ├── Binary Logs (PITR backup)
│   └── Multi-AZ Standby
├── RDS Read Replicas (us-east-1, multi-AZ)
└── S3 Cross-Region Replication
    └── AWS Account Region 2 (us-west-2)

AWS Account (Backup)
├── RDS Cross-Region Replica (us-west-2)
├── S3 Replica Bucket (us-west-2)
├── EC2 Snapshots
└── DLM-Managed Backup Snapshots
```

## RDS (Database) Recovery

### Scenario 1: Database Server Failure

**Symptoms:**
- Application can't connect to database
- RDS status shows "failed" or "storage-full"
- High latency on read/write

**Recovery Steps:**

```bash
# Step 1: Verify the issue
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod \
  --query 'DBInstances[0].[DBInstanceStatus, Endpoint]'

# Status should be: available, backing-up, creating, modifying, or failed

# Step 2: Check CloudWatch for errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T02:00:00Z \
  --period 300 \
  --statistics Average

# Step 3: If Multi-AZ is enabled, failover happens automatically
# Wait 3-5 minutes for automatic failover

# Step 4: Verify recovery
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod \
  --query 'DBInstances[0].DBInstanceStatus'

# If manual action needed (non-Multi-AZ):
aws rds reboot-db-instance \
  --db-instance-identifier myapp-prod \
  --force  # Don't wait for backup completion

# Step 5: Monitor recovery
aws logs tail /rds/myapp-prod --follow
```

**Timeline:**
- Multi-AZ enabled: 1-3 minutes automatic failover
- Reboot: 5-15 minutes depending on size
- **Meets RTO < 5 minutes** ✅

### Scenario 2: Data Corruption / Accidental Deletion

**Symptoms:**
- Users report missing or corrupted data
- Data integrity checks show errors

**Recovery Steps (Point-in-Time Recovery):**

```bash
# Step 1: Identify the problem time
# When did the corruption happen? e.g., 2024-01-15 14:30:00 UTC

CORRUPTION_TIME="2024-01-15T14:30:00Z"
RECOVERY_TIME="2024-01-15T14:25:00Z"  # 5 minutes before

# Step 2: List available backup windows
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod \
  --query 'DBInstances[0].[LatestRestorableTime, EarliestRestorableTime]'

# Verify RECOVERY_TIME is within this window

# Step 3: Create new instance from PITR
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier myapp-prod \
  --target-db-instance-identifier myapp-prod-restored \
  --restore-time $RECOVERY_TIME \
  --db-instance-class db.r6g.large \
  --no-publicly-accessible \
  --db-subnet-group-name myapp-prod-subnet \
  --vpc-security-group-ids sg-xxxxx

# Step 4: Wait for restoration (10-30 minutes for large DB)
aws rds wait db-instance-available \
  --db-instance-identifier myapp-prod-restored

# Step 5: Verify data in restored instance
RESTORED_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier myapp-restored \
  --query 'DBInstances[0].Endpoint.Address' --output text)

psql -h $RESTORED_ENDPOINT -U postgres -d myapp_prod << EOF
SELECT COUNT(*) FROM users WHERE created_at > '2024-01-15 14:25:00';
-- Verify the data looks correct
EOF

# Step 6: Promote restored instance to primary
# Option A: Swap with DNS update (recommended)
aws route53 change-resource-record-sets \
  --hosted-zone-id ZXXXXXX \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "db.myapp.internal",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [{"Value": "'$RESTORED_ENDPOINT'"}]
      }
    }]
  }'

# Option B: Manual application configuration
# Update ECS task definition with new endpoint
aws ecs update-service \
  --cluster prod \
  --service myapp-service \
  --force-new-deployment

# Step 7: Verify application connections
curl https://prod.example.com/health
# Should return 200 OK

# Step 8: Cleanup old primary
aws rds delete-db-instance \
  --db-instance-identifier myapp-prod \
  --skip-final-snapshot

# Step 9: Rename restored instance
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod-restored \
  --new-db-instance-identifier myapp-prod \
  --apply-immediately
```

**Timeline:**
- PITR backup exists: Yes (continuous)
- Restore time: 10-30 minutes
- DNS/application update: 2-5 minutes
- **Total RTO: < 1 hour** ✅
- **RPO: 0 minutes** (all data recovered) ✅

### Scenario 3: Storage Full

**Symptoms:**
- Application queries slow down
- `Error: No space left on device`
- RDS performance degrades

**Recovery Steps:**

```bash
# Step 1: Check storage
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod \
  --query 'DBInstances[0].[AllocatedStorage, DBInstanceStatus]'

# Step 2: If using gp3 with autoscaling
# Verify autoscaling is enabled
aws rds describe-db-instances \
  --db-instance-identifier myapp-prod \
  --query 'DBInstances[0].MaxAllocatedStorage'

# If MaxAllocatedStorage is set, RDS auto-scales up

# Step 3: If manual scaling needed
aws rds modify-db-instance \
  --db-instance-identifier myapp-prod \
  --allocated-storage 200  # Increase to 200GB
  --apply-immediately

# Can increase while DB is running (for gp2/gp3)
# Will cause brief I/O pause (1-2 seconds)

# Step 4: Monitor growth
aws logs filter-log-events \
  --log-group-name /rds/myapp-prod \
  --filter-pattern "ERROR"

# Step 5: Cleanup strategy
# Delete old backups if not needed
aws rds delete-db-snapshot \
  --db-snapshot-identifier myapp-prod-snapshot-2024-01-01

# Delete unused log files
# (RDS manages automatically based on backup retention)
```

**Timeline:**
- Detection: Automatic alerts via CloudWatch
- Storage increase: Immediate (gp3)
- **Total RTO: < 5 minutes** ✅

### Scenario 4: Complete Region Failure

**Symptoms:**
- All resources in us-east-1 down
- AWS Status shows region impairment
- No recovery possible in primary region

**Recovery Steps (Multi-Region):**

```bash
# Step 1: Verify region is down
aws ec2 describe-instances \
  --region us-east-1 \
  --query 'Reservations[].Instances[].State.Name' 2>&1 | grep -i "error"

# Step 2: Promote read replica in secondary region
aws rds promote-read-replica \
  --db-instance-identifier myapp-prod-us-west-2 \
  --region us-west-2

# Wait for promotion (5-15 minutes)
aws rds wait db-instance-available \
  --db-instance-identifier myapp-prod-us-west-2 \
  --region us-west-2

# Step 3: Update application DNS to point to us-west-2
aws route53 change-resource-record-sets \
  --hosted-zone-id ZXXXXXX \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "myapp.example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z123456",
          "DNSName": "myapp-us-west-2-alb.example.com",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }'

# Step 4: Redeploy application to us-west-2
# Update Terraform backend state pointer
aws s3 cp \
  s3://myapp-prod-terraform-state/prod/terraform.tfstate \
  terraform/environments/prod/terraform.tfstate

# Switch to us-west-2 provider
aws --region us-west-2 ecs update-service \
  --cluster prod-us-west-2 \
  --service myapp-service \
  --force-new-deployment

# Step 5: Verify application in secondary region
curl https://myapp.example.com/health

# Should return 200 OK (now from us-west-2)

# Step 6: Restore in primary region
# When us-east-1 is back:
aws rds create-db-instance-read-replica \
  --db-instance-identifier myapp-prod-read \
  --source-db-instance-identifier myapp-prod-us-west-2 \
  --db-instance-class db.r6g.large \
  --region us-east-1
```

**Timeline:**
- Detection: Automatic via Route53 health checks
- Failover to read replica: 5-15 minutes
- DNS propagation: 5-15 minutes
- **Total RTO: < 30 minutes** ✅
- **RPO: Minutes** (very low data loss)

---

## S3 (Storage) Recovery

### Scenario: Accidentally Deleted File

```bash
# Step 1: Check versioning is enabled
aws s3api get-bucket-versioning \
  --bucket myapp-prod-data \
  --query 'Status'

# Should return: Enabled

# Step 2: List object versions (including deleted)
aws s3api list-object-versions \
  --bucket myapp-prod-data \
  --prefix important-file.txt \
  | jq '.Versions[] | {Key, VersionId, IsLatest}'

# Step 3: Restore from previous version
PREVIOUS_VERSION_ID="xyz123abc"

aws s3api copy-object \
  --copy-source myapp-prod-data/important-file.txt?versionId=$PREVIOUS_VERSION_ID \
  --bucket myapp-prod-data \
  --key important-file.txt

# Step 4: Verify restoration
aws s3 ls myapp-prod-data/important-file.txt --human-readable

# Step 5: If needed, check all versions
aws s3api list-object-versions \
  --bucket myapp-prod-data \
  --query 'Versions[].{Key: Key, VersionId: VersionId, LastModified: LastModified}'
```

### Scenario: Objects Accidentally Deleted with S3 Object Lock

If using S3 Object Lock (compliance mode):

```bash
# Step 1: Objects in compliance mode cannot be deleted
# Check lock status
aws s3api get-object-legal-hold \
  --bucket myapp-prod-data \
  --key important-file.txt

# Step 2: Check retention settings
aws s3api get-object-retention \
  --bucket myapp-prod-data \
  --key important-file.txt

# If object is retained, deletion is blocked (safe!)

# Step 3: If deletion was attempted, object still exists
# Revert to latest version
aws s3api delete-object \
  --bucket myapp-prod-data \
  --key important-file.txt \
  --version-id $(aws s3api list-object-versions \
    --bucket myapp-prod-data \
    --query 'Versions[0].VersionId' --output text)
```

---

## ECS Application Recovery

### Scenario: Task Failures

**Symptoms:**
- ECS tasks are stopping/restarting
- Service shows fewer running tasks than desired
- Application errors in logs

**Recovery Steps:**

```bash
# Step 1: Check service status
aws ecs describe-services \
  --cluster prod \
  --services myapp-service \
  --query 'services[0].[status, runningCount, desiredCount, events[0]]'

# Step 2: Check task status
aws ecs list-tasks \
  --cluster prod \
  --service-name myapp-service \
  --query 'taskArns'

aws ecs describe-tasks \
  --cluster prod \
  --tasks <task-arn> \
  --query 'tasks[0].[taskDefinitionArn, lastStatus, stoppedReason]'

# Step 3: Check logs for errors
aws logs tail /ecs/myapp-prod --follow

# Look for:
# - Out of memory (OOM)
# - Application crashes
# - Connection timeouts

# Step 4: Update task definition if code is bad
aws ecs register-task-definition \
  --family myapp-prod \
  --network-mode awsvpc \
  --cpu 1024 \
  --memory 2048 \
  --container-definitions file://containers.json \
  --execution-role-arn arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole \
  --task-role-arn arn:aws:iam::ACCOUNT:role/ecsTaskRole

# Step 5: Update service to use new task definition
aws ecs update-service \
  --cluster prod \
  --service myapp-service \
  --task-definition myapp-prod:LATEST \
  --force-new-deployment

# Step 6: Monitor new deployment
aws ecs describe-services \
  --cluster prod \
  --services myapp-service \
  --query 'services[0].deployments'

aws logs tail /ecs/myapp-prod --follow
```

---

## Infrastructure Recovery (Terraform)

### Scenario: Terraform State Corruption

**Symptoms:**
- Terraform plan shows all resources need recreation
- `Error: invalid state`
- Resource mismatch between Terraform and AWS

**Recovery Steps:**

```bash
# Step 1: Don't panic - check the state backup
ls -la terraform/environments/prod/

# Should have: terraform.tfstate AND terraform.tfstate.backup

# Step 2: Restore from backup if state is corrupted
cp terraform/environments/prod/terraform.tfstate \
   terraform/environments/prod/terraform.tfstate.corrupted

cp terraform/environments/prod/terraform.tfstate.backup \
   terraform/environments/prod/terraform.tfstate

# Step 3: Verify state looks correct
terraform state list | head -10

# Should show your resources (vpc, ecs, rds, etc.)

# Step 4: Test with plan (read-only)
terraform plan -out=recovery.plan

# Review the plan carefully
# Should show minimal or no changes

# Step 5: If plan is large, refresh state first
terraform refresh

# Step 6: Re-run plan
terraform plan -out=recovery.plan

# Step 7: If still large, pull actual AWS state
# Compare Terraform state with AWS Console
aws ec2 describe-vpcs --query 'Vpcs[?Tags[?Key==`app`]].VpcId'

# Step 8: If specific resources are wrong, skip them
terraform import aws_vpc.main vpc-xxxxx

# Or remove and re-import
terraform state rm aws_vpc.main
terraform import aws_vpc.main vpc-xxxxx
```

---

## Testing Disaster Recovery

### Monthly DR Test Checklist

Schedule this first Friday of each month:

```bash
#!/bin/bash
# dr-test.sh - Monthly disaster recovery test

echo "=== Monthly DR Test ==="
DT=$(date +%Y-%m-%d)

# 1. Test RDS Point-in-Time Recovery
echo "Testing PITR..."
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier myapp-prod \
  --target-db-instance-identifier myapp-prod-pitr-test-$DT \
  --restore-time $(date -d '1 hour ago' --rfc-3339=seconds) \
  --skip-final-snapshot

sleep 60  # Wait for restoration to start
aws rds wait db-instance-available --db-instance-identifier myapp-prod-pitr-test-$DT

# 2. Verify data integrity
psql -h $(aws rds describe-db-instances \
  --db-instance-identifier myapp-prod-pitr-test-$DT \
  --query 'DBInstances[0].Endpoint.Address' --output text) \
  -U postgres << 'EOF'
SELECT COUNT(*) as row_count FROM users;
SELECT MAX(created_at) as latest_record FROM users;
EOF

# 3. Cleanup test instance
aws rds delete-db-instance \
  --db-instance-identifier myapp-prod-pitr-test-$DT \
  --skip-final-snapshot

# 4. Test S3 restore from version
TEST_BUCKET="myapp-prod-data"
TEST_FILE="dr-test-$DT.txt"

echo "Test data" > /tmp/$TEST_FILE
aws s3 cp /tmp/$TEST_FILE s3://$TEST_BUCKET/$TEST_FILE

# Get version ID
VER=$(aws s3api list-object-versions \
  --bucket $TEST_BUCKET --prefix $TEST_FILE \
  --query 'Versions[0].VersionId' --output text)

# Delete the file
aws s3 rm s3://$TEST_BUCKET/$TEST_FILE

# Restore from version
aws s3api copy-object \
  --copy-source $TEST_BUCKET/$TEST_FILE?versionId=$VER \
  --bucket $TEST_BUCKET \
  --key $TEST_FILE

# Verify restoration
aws s3 cp s3://$TEST_BUCKET/$TEST_FILE /tmp/$TEST_FILE.restored

# 5. Test CloudWatch alarms
aws cloudwatch set-alarm-state \
  --alarm-name prod-high-cpu \
  --state-value ALARM \
  --state-reason "Manual test"

# Verify SNS notification (check email)
sleep 30

# Reset alarm
aws cloudwatch set-alarm-state \
  --alarm-name prod-high-cpu \
  --state-value OK \
  --state-reason "Test completed"

echo "=== DR Test Complete ==="
```

### Yearly Full Disaster Recovery Drill

Once per year, run a complete failover test:

```bash
# 1. Document current state
aws rds describe-db-instances --query 'DBInstances[0].Endpoint.Address'
aws elbv2 describe-load-balancers --query 'LoadBalancers[0].DNSName'

# 2. Fail over to read replica in secondary region
aws rds promote-read-replica \
  --db-instance-identifier myapp-prod-us-west-2-replica \
  --region us-west-2

# 3. Update application to point to secondary
# (This is a test, use separate DNS name)

# 4. Run full test suite
./tests/integration-test.sh

# 5. Measure recovery metrics
# - Time to failover
# - Data loss (if any)
# - Application availability

# 6. Document results
cat > docs/dr-drill-results-2024.md << EOF
# DR Drill Results - 2024

Date: $(date)
Scenario: Multi-region failover

## Metrics
- RTO: X minutes
- RPO: X minutes
- Data integrity: PASS/FAIL
- Application health: PASS/FAIL

## Issues Found
- Issue 1
- Issue 2

## Improvements Needed
- Action 1
- Action 2

EOF

# 7. Failback to primary
# (Reverse all changes)
```

---

## RPO/RTO Summary Table

| Component | RTO | RPO | Method |
|-----------|-----|-----|--------|
| **RDS Database** | < 5 min | 0 min | Multi-AZ failover + PITR |
| **ECS Application** | < 2 min | 0 min | Task auto-recovery + ALB health checks |
| **S3 Data** | < 1 hour | 0 min | Versioning + cross-region replication |
| **Entire Region** | < 30 min | < 5 min | Read replica promotion + DNS failover |
| **Application Secrets** | < 5 min | 0 min | Secrets Manager replication |
| **Terraform State** | < 10 min | 0 min | State backup + S3 versioning |

---

## Critical Controls Checklist

- [ ] RDS automated backups enabled (30+ days)
- [ ] RDS Multi-AZ deployed for HA
- [ ] RDS binary logs enabled (for point-in-time recovery)
- [ ] S3 versioning enabled on data buckets
- [ ] S3 cross-region replication configured
- [ ] CloudWatch alarms monitoring critical metrics
- [ ] Read replicas deployed in secondary region
- [ ] Terraform state locked and versioned
- [ ] Secrets rotated every 30 days
- [ ] DR procedures tested monthly
- [ ] Full DR drill conducted yearly
- [ ] Team trained on recovery procedures
- [ ] RTO/RPO targets documented and monitored

---

## Emergency Contacts

**When Disaster Happens:**

1. **Page on-call engineer**
   - Slack: @incident-response
   - Phone: [Emergency contact]
   
2. **Notify stakeholders**
   - #incidents channel
   - Status page: status.example.com
   
3. **Assess impact**
   - How many users affected?
   - How much data at risk?
   - How long can we tolerate downtime?

4. **Initiate recovery**
   - Follow procedures above
   - Document all actions
   - Keep stakeholders updated

5. **Post-incident**
   - Conduct blameless post-mortem
   - Update procedures based on learnings
   - Schedule follow-up training

---

## References

- [AWS RDS Backup & Restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_CommonTasks.BackupRestore.html)
- [RDS Point-in-Time Recovery](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html)
- [S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [S3 Cross-Region Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)
- [ECS Task Auto-Recovery](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service_update_failure_handling.html)
- [Terraform State Backup](https://www.terraform.io/language/state/backup)
