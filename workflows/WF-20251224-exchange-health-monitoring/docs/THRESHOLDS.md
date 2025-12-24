# Threshold Tuning Guide

## Overview

This document explains how to tune thresholds in [config/thresholds.yaml](../config/thresholds.yaml) to reduce false positives and improve detection accuracy.

## Threshold Categories

### Memory Thresholds

#### Usage Thresholds (% of limit)

```yaml
memory:
  usage_warning: 75      # Warning at 75% of limit
  usage_critical: 85     # Critical at 85% of limit
```

**When to adjust**:
- **Too sensitive**: Decrease values (e.g., 70%, 80%)
- **Too lenient**: Increase values (e.g., 80%, 90%)

**Recommendation**: Start conservative (75%, 85%), adjust based on 1-week observation

#### Memory Leak Detection

```yaml
memory:
  leak_slope_threshold: 10      # MB/hour
  leak_r_squared_threshold: 0.7  # Correlation strength
  leak_p_value_threshold: 0.05   # Statistical significance
```

**How it works**: All three conditions must be met simultaneously
- `slope > 10 MB/h`: Memory growing faster than 10 MB/hour
- `R² > 0.7`: Strong linear correlation (70%+)
- `p < 0.05`: Statistically significant (95% confidence)

**When to adjust**:
- **Too many false positives**: Increase `leak_slope_threshold` to 20-30 MB/h
- **Missing real leaks**: Decrease `leak_r_squared_threshold` to 0.6 or `leak_slope_threshold` to 5 MB/h

#### Resource Allocation

```yaml
memory:
  over_provision_ratio: 0.5   # Alert if avg < 50% request
  under_provision_ratio: 0.85 # Alert if p95 > 85% limit
```

**When to adjust**:
- **Over-provision alerts too frequent**: Lower to 0.3-0.4
- **Want more aggressive rightsizing**: Increase to 0.6-0.7

### CPU Thresholds

Similar structure to memory, but with different defaults:

```yaml
cpu:
  usage_warning: 70
  usage_critical: 85
  over_provision_ratio: 0.4   # CPUs often have lower utilization
```

### HPA Thresholds

```yaml
hpa:
  over_scaling_min_replicas: 5        # Check if ≥5 replicas
  over_scaling_cpu_threshold: 0.5     # ...but avg CPU < 0.5 cores
  under_scaling_max_replicas: 2       # Check if ≤2 replicas
  under_scaling_cpu_threshold: 2.0    # ...but avg CPU > 2.0 cores
```

**Tuning strategy**:
1. Observe typical replica count range for 1 week
2. Set `over_scaling_min_replicas` to 75th percentile
3. Set `under_scaling_max_replicas` to 25th percentile

### Event Thresholds

```yaml
events:
  oom_critical_count: 1      # Any OOMKilled is critical
  restart_warning_count: 3   # 3+ restarts = warning
  restart_critical_count: 10 # 10+ restarts = critical
```

**OOM threshold**: Should always be 1 (any OOM is serious)

**Restart thresholds**:
- For stable services: Keep at 3/10
- For frequently-deployed services: Increase to 5/15

## Tuning Workflow

### Step 1: Baseline Collection (Week 1)

1. Deploy with default thresholds
2. Run daily for 7 days
3. Collect all reports (no action needed)

### Step 2: Analysis (Week 2)

Review reports and categorize issues:

```bash
# Count issues by category
grep "severity" /reports/*.json | \
  jq -r '.issues[].category' | \
  sort | uniq -c | sort -rn
```

**Questions to ask**:
- Are memory leak alerts accurate?
- Are over-provision alerts actionable?
- Are HPA alerts meaningful?

### Step 3: Adjustment (Week 2-3)

Based on analysis:

1. Edit [config/thresholds.yaml](../config/thresholds.yaml)
2. Rebuild Docker image:
   ```bash
   docker build -t asia-east2-docker.pkg.dev/uu-prod/uu-prod/forex-infra/exchange-health-check:latest .
   docker push ...
   ```
3. Restart CronJob:
   ```bash
   kubectl rollout restart cronjob exchange-health-check -n forex-prod
   ```

### Step 4: Validation (Week 4)

- Monitor for another week
- Verify false positive rate decreased
- Ensure no real issues missed

## Common Tuning Scenarios

### Scenario 1: Too Many Memory Leak Alerts

**Symptom**: Daily leak alerts but no actual OOM events

**Solution**: Increase `leak_slope_threshold` from 10 to 20 MB/h

```yaml
memory:
  leak_slope_threshold: 20  # More tolerant
```

### Scenario 2: Missing CPU Over-Provisioning

**Symptom**: CPU usage consistently < 20% but no alerts

**Solution**: Increase `over_provision_ratio` from 0.4 to 0.6

```yaml
cpu:
  over_provision_ratio: 0.6  # More aggressive rightsizing
```

### Scenario 3: HPA False Alarms

**Symptom**: "Over-scaling" alerts during legitimate traffic spikes

**Solution**: Adjust `over_scaling_min_replicas` threshold

```yaml
hpa:
  over_scaling_min_replicas: 8  # Only alert if ≥8 replicas (was 5)
```

### Scenario 4: Restart Alerts During Deployments

**Symptom**: Warning alerts every deployment due to pod recreations

**Solution**: Increase `restart_warning_count`

```yaml
events:
  restart_warning_count: 5   # Tolerate deployment restarts
  restart_critical_count: 15
```

## Service-Specific Overrides

For services with different characteristics, consider creating separate threshold configs:

```bash
# Create service-specific config
cp config/thresholds.yaml config/thresholds-balance-service.yaml

# Edit balance-service specific values
vi config/thresholds-balance-service.yaml

# Deploy separate CronJob
kubectl apply -f deployment/cronjob-balance-service.yml
```

## Monitoring Threshold Effectiveness

### Key Metrics

1. **False Positive Rate**: Issues detected but no real problem
   - Target: < 20%
   - Calculate: (False positives / Total issues) × 100

2. **Detection Rate**: Real problems caught by health check
   - Target: > 80%
   - Track manually: Did we catch the last OOM/incident?

3. **Actionability Rate**: Issues that led to actual changes
   - Target: > 50%
   - Calculate: (Actions taken / Total issues) × 100

### Weekly Review Template

```markdown
## Week of YYYY-MM-DD

### Alerts Summary
- Total issues detected: X
- CRITICAL: Y
- WARNING/HIGH: Z

### False Positives
- Memory leak: 2 (traffic spike, not leak)
- Over-scaling: 1 (expected load increase)

### Actions Taken
- Increased exchange-service memory limit (alert was correct)
- None (2 alerts were false positives)

### Threshold Adjustments
- Increased leak_slope_threshold: 10 → 15 MB/h
```

## Advanced Tuning

### Dynamic Thresholds (Future Enhancement)

Consider implementing time-of-day or day-of-week adjustments:

```yaml
# Future feature
hpa:
  over_scaling_min_replicas:
    business_hours: 8   # Higher during work hours
    off_hours: 5        # Lower at night
```

### Percentile-Based Thresholds (Future Enhancement)

Instead of fixed values, use historical percentiles:

```yaml
# Future feature
memory:
  usage_warning: p75   # 75th percentile of historical usage
  usage_critical: p90  # 90th percentile
```

## Related Documentation

- [README.md](../README.md) - Project overview
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment guide
- [RUNBOOK.md](RUNBOOK.md) - Operational procedures
