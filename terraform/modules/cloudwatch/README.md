# CloudWatch Monitoring Module

Comprehensive monitoring configuration including dashboards, alarms, log groups, and metric filters.

## Overview

This module provides:
- **Dashboard**: Unified view of infrastructure and application metrics
- **Alarms**: Critical alerts for performance, errors, and resource utilization
- **Log Groups**: Centralized logging with configurable retention
- **Metric Filters**: Extract custom metrics from log data

## Features

### CloudWatch Dashboard

- **ALB Metrics**: Response time, request count, error rates
- **ECS Metrics**: Running/desired task count, pending tasks
- **RDS Metrics**: CPU, memory, storage, connections
- **Network Metrics**: NAT gateway traffic and errors
- **Application Logs**: Recent errors and anomalies

### CloudWatch Alarms

| Alarm | Metric | Threshold | Action |
|-------|--------|-----------|--------|
| ALB Response Time | TargetResponseTime | > 1s | SNS notification |
| ECS Task Failures | HTTPCode_Target_5XX | > 10/min | SNS notification |
| RDS High CPU | CPUUtilization | > 80% | SNS notification |
| RDS Low Memory | FreeableMemory | < 256MB | SNS notification |
| RDS Low Storage | FreeStorageSpace | < 10GB | SNS notification |
| ECS Low Task Count | RunningCount < Desired | 2 failures | SNS notification |
| NAT Port Allocation | ErrorPortAllocation | > 5 | SNS notification |

### Log Groups

- `/ecs/{project_name}-{environment}`: Application logs
- `/rds/{project_name}-{environment}`: RDS logs
- Configurable retention (1-3653 days)

### Metric Filters

- **Application Errors**: Count of ERROR level logs
- **High Latency**: Count of requests with latency > 1000ms

## Usage

```hcl
module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name  = "myapp"
  environment   = "prod"
  cluster_name  = "prod-cluster"
  service_name  = "myapp-service"
  db_instance_id = "myapp-prod"
  
  log_retention_days = 30
  sns_topic_arn     = aws_sns_topic.alerts.arn

  tags = {
    Team      = "platform"
    CostCenter = "engineering"
  }
}
```

## Accessing the Dashboard

### Via AWS Console

```
CloudWatch → Dashboards → myapp-prod-overview
```

### Via CLI

```bash
# Get dashboard URL
aws cloudwatch describe-dashboards \
  --dashboard-name myapp-prod-overview \
  --query 'DashboardSummaries[0].DashboardName'

# View dashboard (opens in browser)
aws cloudwatch get-dashboard --dashboard-name myapp-prod-overview
```

### Terraform Output

```bash
# Get dashboard URL from Terraform
terraform output cloudwatch_dashboard_url
```

## Setting Up Notifications

### SNS Topic for Alarms

```hcl
resource "aws_sns_topic" "monitoring_alerts" {
  name = "${var.project_name}-monitoring-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol  = "email"
  endpoint  = "ops-team@company.com"
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol  = "https"
  # Use AWS Lambda to route SNS to Slack webhook
  endpoint  = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
}

# Pass to CloudWatch module
module "cloudwatch" {
  # ...
  sns_topic_arn = aws_sns_topic.monitoring_alerts.arn
}
```

## Common Queries

### Find Errors in Last Hour

```bash
aws logs filter-log-events \
  --log-group-name "/ecs/myapp-prod" \
  --filter-pattern ERROR \
  --start-time $(($(date +%s) - 3600) * 1000) \
  --end-time $(date +%s * 1000)
```

### Get Application Metric Data

```bash
aws cloudwatch get-metric-statistics \
  --namespace "CustomMetrics/myapp" \
  --metric-name "ApplicationErrorCount" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Check Alarm Status

```bash
# List all alarms
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[*].[AlarmName,StateValue]'

# Get specific alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name "myapp-prod-high-response-time" \
  --max-records 10
```

## Log Insights Queries

### Find Slow Requests

```
fields @timestamp, @duration
| filter @duration > 1000
| stats count() as SlowRequests by bin(@duration)
```

### Error Distribution

```
fields @timestamp, @level, @message
| filter @level = "ERROR"
| stats count() as ErrorCount by @level
```

### Track User Activity

```
fields @timestamp, @user_id, @action
| stats count() as ActionCount by @user_id
```

### Database Query Performance

```
fields @timestamp, @query, @duration
| filter @duration > 5000
| sort @duration desc
| head 20
```

## Alarms Best Practices

1. **Avoid Alert Fatigue**: Set thresholds based on baseline metrics
2. **Escalation**: Use SNS for email/SMS, Lambda for complex routing
3. **Testing**: Regularly test alarm notifications
4. **Documentation**: Document alarm meaning and manual response steps
5. **Review Frequency**: Monthly review of alarm trigger rates
6. **Auto-remediation**: Use EventBridge to auto-scale on alarms

## Cost Optimization

### Log Retention

- **Development**: 7-14 days
- **Staging**: 14-30 days
- **Production**: 30-90 days
- **Archive**: Long-term retention in S3 Glacier

### Dashboard Updates

- Dashboards have no direct cost
- Only pay for metrics and logs queried

### Alarm Costs

- 10 alarms: ~$1/month
- 100 alarms: ~$10/month
- Custom metrics: $0.30/month per metric

## Troubleshooting

### Alarms Not Triggering

1. Check alarm state: `StateValue` should not be `INSUFFICIENT_DATA`
2. Verify metrics are being published
3. Check SNS topic permissions
4. Review alarm threshold is correct

### Missing Log Data

1. Verify log group exists and has data
2. Check log retention hasn't expired
3. Confirm application is writing logs
4. Review CloudWatch Logs permissions in IAM

### High Dashboard Load Time

1. Reduce number of metrics displayed
2. Increase time range (less detailed)
3. Use Insights queries instead of full logs
4. Archive old logs to S3

## Advanced Dashboard Customization

### Add Custom Widget

```json
{
  "type": "metric",
  "properties": {
    "metrics": [
      ["AWS/ApplicationELB", "RequestCount"]
    ],
    "period": 300,
    "stat": "Sum",
    "region": "us-east-1",
    "title": "ALB Request Count"
  }
}
```

### Add Log Insights Widget

```json
{
  "type": "log",
  "properties": {
    "query": "fields @timestamp, @message | filter @level = 'ERROR'",
    "region": "us-east-1",
    "title": "Recent Errors"
  }
}
```

## References

- [AWS CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)
- [CloudWatch Dashboard Widgets](https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/API_Dashboard.html)
- [Log Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
