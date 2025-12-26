# JC-Refactor Services Error Log Check Guide

**Date**: 2025-12-23
**Purpose**: Guide for checking error logs across all 37 services in jc-refactor

## Overview

The jc-refactor directory contains 37 microservices (7 API + 30 APP) deployed in the `jc-prod` namespace. This guide provides tools and procedures for checking error logs across all services.

## Services Inventory

### API Services (7)

| Service Name | Deployment | Port |
|--------------|------------|------|
| JuanWorld API | juanworld-api | 25000 |
| JuanWorld Admin API | juanworld-admin-api | 18000 |
| JuanCash Open API | juancash-open-api | 6543 |
| JuanCash Bank API | juancash-bank-api | 6554 |
| JuanCash Applet API | juancash-applet-api | 1300 |
| JuanCash Client API | juancash-clicent-api | 1234 |
| JuanWord Shop Manager API | juanword-api-shopmanager | 6030 |

### APP Services (30)

**Admin Services (9)**:
- juanworld-admin-settlement
- juanworld-admin-txorder
- juancash-admin-bank
- juancash-admin-finance
- juancash-admin-mgmt
- juancash-admin-pay
- juancash-admin-system
- juancash-admin-txorder
- juancash-admin-withdrawal

**Scheduler Services (4)**:
- juancash-scheduler-bank
- juancash-scheduler-pay
- juancash-scheduler-system
- juancash-scheduler-txorder

**App Services (10)**:
- juancash-app-bank
- juancash-app-pay
- juancash-app-system
- juancash-app-txorder
- juancash-app-withdrawal
- juancash-app-merchant
- juanworld-app-merchant
- juanworld-app-settlement
- juanworld-riskcontrolservice
- (others)

**Open Services (4)**:
- juancash-open-bank
- juancash-open-pay
- juancash-open-system
- juancash-open-txorder

**Socket Services (2)**:
- juancash-socket-app
- juancash-socket-merchant

**Client Services (4)**:
- juancash-client-finance
- juancash-client-merchant
- juancash-client-settlement
- juancash-client-withdrawal

## Automated Error Check Script

### Script: check-error-logs.sh

**Location**: `/Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/jc-refactor/check-error-logs.sh`

**Usage**:
```bash
cd /Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/jc-refactor

# Check last 200 lines, last 1 hour (default)
./check-error-logs.sh

# Check last 500 lines, last 30 minutes
./check-error-logs.sh 500 30m

# Check last 1000 lines, last 3 hours
./check-error-logs.sh 1000 3h

# Check last 2000 lines, last 24 hours
./check-error-logs.sh 2000 24h
```

**Features**:
- Checks all 37 services automatically
- Shows running pod count for each service
- Filters for common error patterns:
  - error, exception, fatal, fail, panic
  - timeout, refused, cannot
- Excludes debug/trace/info level messages
- Shows first 20 errors per service
- Color-coded output (✅ no errors, ⚠️ errors found)

**Output Example**:
```
=== JuanWorld API ===
✅ 2 pod(s) running
⚠️  Found 5 potential error(s):
────────────────────────────────────────
2025-12-23 10:15:32 ERROR [pool-1-thread-1] Connection timeout to database
2025-12-23 10:16:45 WARN  [http-nio-25000-exec-5] Failed to connect to Redis
...
────────────────────────────────────────
```

## Manual Error Checking

### Check Single Service

```bash
# Get recent logs with errors
kubectl logs -n jc-prod -l app=juanworld-api --tail=500 --since=1h | \
  grep -iE "(error|exception|fatal|fail)"

# Get all logs from a specific pod
POD_NAME=$(kubectl get pods -n jc-prod -l app=juanworld-api -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n jc-prod $POD_NAME --tail=1000

# Follow logs in real-time
kubectl logs -n jc-prod -l app=juanworld-api --follow

# Export logs to file
kubectl logs -n jc-prod -l app=juanworld-api --tail=5000 > juanworld-api.log
```

### Check Multiple Pods

```bash
# If service has multiple replicas
kubectl logs -n jc-prod -l app=juanworld-api --all-containers=true --tail=200
```

### Check Previous Container (if pod crashed)

```bash
kubectl logs -n jc-prod $POD_NAME --previous
```

## Common Error Patterns to Look For

### 1. Connection Errors

```bash
kubectl logs -n jc-prod -l app=<service-name> --tail=500 | \
  grep -iE "(connection.*timeout|connection.*refused|cannot connect)"
```

**Common causes**:
- Database connection timeout
- Redis connection refused
- Downstream service unavailable
- Network issues

### 2. Database Errors

```bash
kubectl logs -n jc-prod -l app=<service-name> --tail=500 | \
  grep -iE "(sql.*error|database.*error|deadlock|duplicate key)"
```

**Common causes**:
- SQL syntax errors
- Duplicate key violations
- Deadlock detected
- Table lock timeout

### 3. NullPointerException / NPE

```bash
kubectl logs -n jc-prod -l app=<service-name> --tail=500 | \
  grep -i "NullPointerException"
```

**Common causes**:
- Missing configuration
- Null object access
- Uninitialized variables

### 4. OutOfMemoryError

```bash
kubectl logs -n jc-prod -l app=<service-name> --tail=500 | \
  grep -i "OutOfMemoryError"
```

**Common causes**:
- Heap space exhausted
- Too many threads
- Memory leak

### 5. Timeout Errors

```bash
kubectl logs -n jc-prod -l app=<service-name> --tail=500 | \
  grep -iE "(timeout|timed out|deadline exceeded)"
```

**Common causes**:
- Slow database queries
- Downstream service slow response
- Network latency

### 6. HTTP Errors (4xx, 5xx)

```bash
kubectl logs -n jc-prod -l app=<service-name> --tail=500 | \
  grep -E "HTTP/[0-9.]+ [45][0-9]{2}"
```

**Common causes**:
- 400: Bad request
- 401: Unauthorized
- 403: Forbidden
- 404: Not found
- 500: Internal server error
- 502: Bad gateway
- 503: Service unavailable
- 504: Gateway timeout

## Error Log Analysis Workflow

### Step 1: Run Automated Check

```bash
cd /Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/jc-refactor
./check-error-logs.sh 500 1h > error-check-$(date +%Y%m%d_%H%M%S).txt
```

### Step 2: Review Output

- Services with ✅ (no errors): OK
- Services with ⚠️ (errors found): Need investigation

### Step 3: Deep Dive into Problematic Services

```bash
# Export full logs for analysis
kubectl logs -n jc-prod -l app=<service-name> --tail=5000 > <service-name>-full.log

# Count error types
grep -i "error" <service-name>-full.log | awk '{print $3, $4}' | sort | uniq -c | sort -rn

# Find timestamp of first error
grep -i "error" <service-name>-full.log | head -1
```

### Step 4: Correlate with Events

```bash
# Check pod events
kubectl get events -n jc-prod --field-selector involvedObject.name=<pod-name> --sort-by='.lastTimestamp'

# Check deployment events
kubectl describe deployment <deployment-name> -n jc-prod | tail -20
```

### Step 5: Check Resource Usage

```bash
# Memory and CPU usage
kubectl top pods -n jc-prod -l app=<service-name>

# Check if pod was OOMKilled
kubectl get events -n jc-prod --field-selector reason=OOMKilling | grep <service-name>
```

## Generating Error Summary Report

### Script: generate-error-report.sh

Create a comprehensive error report:

```bash
#!/bin/bash
# generate-error-report.sh

REPORT_FILE="error-report-$(date +%Y%m%d_%H%M%S).md"
NAMESPACE="jc-prod"

cat > $REPORT_FILE <<EOF
# JC-Refactor Error Log Report
**Generated**: $(date)
**Namespace**: $NAMESPACE

## Summary

EOF

# Count services with errors
SERVICES_WITH_ERRORS=0
TOTAL_SERVICES=0

for service in juanworld-api juanworld-admin-api juancash-open-api juancash-bank-api juancash-applet-api juancash-clicent-api juanword-api-shopmanager; do
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
    ERROR_COUNT=$(kubectl logs -n $NAMESPACE -l app=$service --tail=200 --since=1h 2>/dev/null | \
        grep -ciE "(error|exception|fatal)" || echo "0")

    if [ "$ERROR_COUNT" -gt 0 ]; then
        SERVICES_WITH_ERRORS=$((SERVICES_WITH_ERRORS + 1))
        echo "- **$service**: $ERROR_COUNT errors in last hour" >> $REPORT_FILE
    fi
done

echo "" >> $REPORT_FILE
echo "**Total**: $SERVICES_WITH_ERRORS / $TOTAL_SERVICES services with errors" >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo "Report generated: $REPORT_FILE"
```

## Best Practices

### 1. Regular Monitoring

- Run error check script daily
- Set up alerts for critical errors
- Monitor error trends over time

### 2. Log Retention

```bash
# Check log retention settings
kubectl get pods -n jc-prod -o jsonpath='{.items[0].spec.containers[0].volumeMounts}' | grep log

# Logs are typically stored in NAS: /juancash/logs/<service-name>
```

### 3. Centralized Logging (if available)

If using ELK/Loki/CloudWatch:
- Use log aggregation for easier searching
- Set up dashboards for error rates
- Create alerts for specific error patterns

### 4. Error Categories

Classify errors by severity:
- **CRITICAL**: OOM, service crash, data corruption
- **HIGH**: Connection failures, frequent 5xx errors
- **MEDIUM**: Occasional timeouts, 4xx errors
- **LOW**: Debug messages, expected errors (e.g., invalid input)

## Troubleshooting Common Issues

### Issue 1: "Error from server (NotFound): deployments.apps not found"

**Cause**: Deployment name mismatch or service not deployed

**Solution**:
```bash
# List all deployments in namespace
kubectl get deployments -n jc-prod

# Check actual deployment name
ls -1 /Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/jc-refactor/api-service/
```

### Issue 2: "Unable to retrieve container logs"

**Cause**: Pod not running or crashed

**Solution**:
```bash
# Check pod status
kubectl get pods -n jc-prod -l app=<service-name>

# Describe pod for details
kubectl describe pod <pod-name> -n jc-prod

# Check previous logs if pod restarted
kubectl logs <pod-name> -n jc-prod --previous
```

### Issue 3: Too many logs, hard to filter

**Solution**:
```bash
# Use more specific grep patterns
kubectl logs -n jc-prod -l app=<service-name> --tail=500 | \
  grep -E "ERROR|FATAL" | \
  grep -v "Expected error" | \
  grep -v "null value" | \
  tail -20

# Export and use text editor
kubectl logs -n jc-prod -l app=<service-name> --tail=5000 > service.log
# Then open in editor and search
```

## Integration with Monitoring Tools

### Prometheus Metrics (if available)

```promql
# Error rate
rate(http_requests_total{status=~"5.."}[5m])

# Application errors logged
rate(log_messages_total{level="error"}[5m])
```

### Grafana Dashboard

Create panels for:
- Error count per service (last 1h, 24h, 7d)
- Top 10 services with most errors
- Error rate trend over time
- Alert status

## Contact & Support

**Script Location**: `/Users/user/JUANCASH-project/github/juancash-prod-k8s-deploy/jc-refactor/check-error-logs.sh`

**Documentation**: This file

**Maintainer**: DevOps Team

---

**Last Updated**: 2025-12-23
