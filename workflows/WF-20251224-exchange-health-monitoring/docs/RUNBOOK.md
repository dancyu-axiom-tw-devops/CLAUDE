# Exchange Health Check - Runbook

## Daily Operations

### Check CronJob Status

```bash
# View CronJob
kubectl get cronjob exchange-health-check -n forex-prod

# View recent jobs
kubectl get jobs -n forex-prod -l app=exchange-health-check --sort-by=.metadata.creationTimestamp

# View job logs
kubectl logs -f job/<job-name> -n forex-prod
```

### View Latest Report

```bash
# Access PVC to read reports
kubectl run -it --rm view-reports --image=busybox --restart=Never \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "view",
        "image": "busybox",
        "stdin": true,
        "tty": true,
        "command": ["/bin/sh"],
        "volumeMounts": [{
          "name": "reports",
          "mountPath": "/reports"
        }]
      }],
      "volumes": [{
        "name": "reports",
        "persistentVolumeClaim": {"claimName": "health-check-reports"}
      }]
    }
  }' \
  -n forex-prod

# Inside pod:
# ls -lt /reports/ | head
# cat /reports/health-check-YYYYMMDD-HHMMSS.md
```

## Alert Response Playbook

### CRITICAL: OOMKilled Detected

**Symptoms**: Report shows OOMKilled events

**Immediate Actions**:
1. Check current memory usage:
   ```bash
   kubectl top pods -n forex-prod -l app=exchange-service
   ```

2. Review pod events:
   ```bash
   kubectl get events -n forex-prod --field-selector involvedObject.name=<pod-name>
   ```

3. Increase memory limit:
   ```bash
   kubectl edit deployment exchange-service -n forex-prod
   # Increase spec.template.spec.containers[].resources.limits.memory
   ```

**Root Cause Investigation**:
- Check for memory leaks in application logs
- Review recent deployments
- Analyze heap dumps if available

### HIGH: HPA at Maximum Replicas

**Symptoms**: HPA stuck at max replicas, high resource usage

**Immediate Actions**:
1. Check current load:
   ```bash
   kubectl get hpa exchange-service -n forex-prod
   kubectl top pods -n forex-prod -l app=exchange-service
   ```

2. Temporarily increase max replicas:
   ```bash
   kubectl edit hpa exchange-service -n forex-prod
   # Increase spec.maxReplicas
   ```

**Root Cause Investigation**:
- Check for traffic spikes
- Review application performance metrics
- Consider vertical scaling (increase per-pod resources)

### MEDIUM: Resource Over-Provisioning

**Symptoms**: Average usage < 50% of request

**Actions**:
1. Monitor for 3-7 days to establish baseline
2. If consistently low, reduce requests:
   ```bash
   kubectl edit deployment exchange-service -n forex-prod
   # Reduce spec.template.spec.containers[].resources.requests
   ```

3. Monitor after change to ensure no performance degradation

### WARNING: Memory Leak Detected

**Symptoms**: Consistent memory growth trend (slope > 10 MB/h, high R²)

**Immediate Actions**:
1. Verify trend with Grafana dashboards
2. Check application logs for errors
3. Plan restart during maintenance window

**Root Cause Investigation**:
- Enable heap dumps on OOM
- Profile application memory usage
- Review recent code changes

## Maintenance Tasks

### Manual Health Check

Run on-demand check:

```bash
kubectl create job --from=cronjob/exchange-health-check manual-$(date +%s) -n forex-prod
kubectl logs -f job/manual-$(date +%s) -n forex-prod
```

### Update Thresholds

1. Edit config file:
   ```bash
   vi config/thresholds.yaml
   ```

2. Rebuild and push image:
   ```bash
   docker build -t asia-east2-docker.pkg.dev/uu-prod/uu-prod/forex-infra/exchange-health-check:latest .
   docker push asia-east2-docker.pkg.dev/uu-prod/uu-prod/forex-infra/exchange-health-check:latest
   ```

3. Restart CronJob:
   ```bash
   kubectl rollout restart cronjob exchange-health-check -n forex-prod
   ```

### Archive Old Reports

```bash
# Access PVC
kubectl run -it --rm archive --image=busybox --restart=Never \
  --overrides='...' -n forex-prod

# Inside pod:
# tar czf /reports/archive-$(date +%Y%m).tar.gz /reports/*.json
# find /reports -name "*.json" -mtime +30 -delete
```

### Change Schedule

```bash
kubectl edit cronjob exchange-health-check -n forex-prod
# Modify .spec.schedule (cron syntax)
```

Common schedules:
- Daily 09:00 UTC+8: `0 1 * * *`
- Twice daily (09:00, 21:00 UTC+8): `0 1,13 * * *`
- Weekly Monday 09:00: `0 1 * * 1`

## Troubleshooting

### Job Fails with Timeout

**Symptoms**: Job exceeds activeDeadlineSeconds (1800s)

**Solutions**:
- Increase timeout in cronjob.yml
- Optimize PromQL queries (reduce data range or step size)
- Check Prometheus performance

### High False Positive Rate

**Symptoms**: Too many non-critical alerts

**Solutions**:
1. Review and adjust thresholds in `config/thresholds.yaml`
2. Increase tolerance ranges
3. Add minimum threshold durations

### Slack Notifications Not Received

**Check**:
1. Secret exists:
   ```bash
   kubectl get secret slack-credentials -n forex-prod
   ```

2. Job logs for errors:
   ```bash
   kubectl logs job/<job-name> -n forex-prod | grep -i slack
   ```

3. Test Slack webhook manually:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test message"}' \
     <webhook-url>
   ```

## Metrics and Dashboards

### Key Metrics to Monitor

- **Job Success Rate**: % of successful CronJob executions
- **Report Generation Time**: Duration of healthcheck.py execution
- **Issue Detection Rate**: Number of issues detected per week
- **False Positive Rate**: Issues that didn't result in incidents

### Grafana Dashboard

Create dashboard with:
- CronJob execution history
- Resource usage trends for exchange-service
- HPA replica count over time
- Memory/CPU usage percentiles

## Escalation

### When to Escalate

- **CRITICAL issues** not resolved within 1 hour
- **Repeated OOMKilled events** (> 3 in 24h)
- **HPA stuck at max** for > 2 hours during business hours
- **Health check job failures** for > 3 consecutive runs

### Escalation Path

1. **L1**: On-call SRE (#sre-oncall Slack channel)
2. **L2**: Application team lead
3. **L3**: Infrastructure architect

### Information to Provide

- Latest health check report (Markdown + JSON)
- Recent application logs
- Grafana dashboard screenshots
- Steps already taken

## Related Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment guide
- [THRESHOLDS.md](THRESHOLDS.md) - Threshold tuning guide
- [README.md](../README.md) - Project overview
