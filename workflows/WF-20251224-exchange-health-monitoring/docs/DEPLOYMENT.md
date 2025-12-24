# Exchange Health Check - Deployment Guide

## Prerequisites

### Required

- Kubernetes cluster access with `forex-prod` namespace
- kubectl configured for target cluster
- Prometheus server accessible at `http://prometheus-operated.monitoring.svc.cluster.local:9090`
- Metrics Server enabled (`kubectl top` commands work)
- Docker registry access: `asia-east2-docker.pkg.dev/uu-prod/uu-prod/forex-infra/`

### Optional but Recommended

- Slack Bot Token or Webhook URL for notifications
- Persistent storage for report archival

## Deployment Steps

### Step 1: Build and Push Docker Image

```bash
cd /Users/user/CLAUDE/workflows/WF-20251224-exchange-health-monitoring

# Build image
docker build -t asia-east2-docker.pkg.dev/uu-prod/uu-prod/forex-infra/exchange-health-check:latest \
  -f deployment/docker/Dockerfile .

# Push to registry
docker push asia-east2-docker.pkg.dev/uu-prod/uu-prod/forex-infra/exchange-health-check:latest
```

### Step 2: Create Slack Secret

**Option A: Using Bot Token** (Recommended)

```bash
kubectl create secret generic slack-credentials \
  --from-literal=bot-token=xoxb-your-slack-bot-token \
  -n forex-prod
```

**Option B: Using Webhook**

```bash
kubectl create secret generic slack-credentials \
  --from-literal=webhook-url=https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -n forex-prod
```

### Step 3: Deploy RBAC

```bash
kubectl apply -f deployment/rbac.yml
```

Verify:
```bash
kubectl get serviceaccount exchange-health-check -n forex-prod
kubectl get role exchange-health-check -n forex-prod
kubectl get rolebinding exchange-health-check -n forex-prod
```

### Step 4: Deploy ConfigMap

```bash
kubectl apply -f deployment/configmap.yml
```

Verify:
```bash
kubectl get configmap exchange-health-check-config -n forex-prod
```

### Step 5: Deploy CronJob and PVC

```bash
kubectl apply -f deployment/cronjob.yml
```

Verify:
```bash
kubectl get cronjob exchange-health-check -n forex-prod
kubectl get pvc health-check-reports -n forex-prod
```

### Step 6: Manual Test Run

Create a test job from the CronJob:

```bash
kubectl create job --from=cronjob/exchange-health-check manual-test-$(date +%s) -n forex-prod
```

Watch the job:

```bash
# Get job name
JOB_NAME=$(kubectl get jobs -n forex-prod -l app=exchange-health-check --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

# Follow logs
kubectl logs -f job/$JOB_NAME -n forex-prod
```

Expected output:
```
=== Exchange Service Health Check Started ===
Loading configuration...
Initializing clients...
Collecting metrics...
Analyzing metrics...
Generating report...
Saving reports...
Sending Slack notification...
=== Health Check Completed: HEALTHY ===
```

### Step 7: Verify Outputs

**Check Slack notification** - Should receive message in configured channel

**Check reports in PVC**:

```bash
# Create debug pod to access PVC
kubectl run -it --rm debug --image=busybox --restart=Never \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "debug",
      "image": "busybox",
      "stdin": true,
      "tty": true,
      "volumeMounts": [{
        "name": "reports",
        "mountPath": "/reports"
      }]
    }],
    "volumes": [{
      "name": "reports",
      "persistentVolumeClaim": {
        "claimName": "health-check-reports"
      }
    }]
  }
}' \
  -n forex-prod \
  -- ls -lh /reports/
```

## Post-Deployment

### Verify CronJob Schedule

```bash
kubectl get cronjob exchange-health-check -n forex-prod -o yaml | grep schedule
```

Should show: `schedule: "0 1 * * *"` (01:00 UTC = 09:00 UTC+8)

### Monitor First Automated Run

Wait for the next scheduled execution or manually trigger:

```bash
kubectl create job --from=cronjob/exchange-health-check auto-test-$(date +%s) -n forex-prod
```

## Troubleshooting

### Issue: Job fails with "Permission denied"

**Solution**: Check RBAC permissions

```bash
kubectl auth can-i get pods --as=system:serviceaccount:forex-prod:exchange-health-check -n forex-prod
kubectl auth can-i get deployments --as=system:serviceaccount:forex-prod:exchange-health-check -n forex-prod
```

### Issue: "Failed to connect to Prometheus"

**Solution**: Verify Prometheus accessibility

```bash
kubectl run -it --rm test --image=curlimages/curl --restart=Never -n forex-prod -- \
  curl -v http://prometheus-operated.monitoring.svc.cluster.local:9090/api/v1/status/config
```

### Issue: Slack notification not sent

**Solution**: Check secret

```bash
kubectl get secret slack-credentials -n forex-prod -o jsonpath='{.data.bot-token}' | base64 -d
```

Verify token starts with `xoxb-`

### Issue: Out of memory

**Solution**: Increase memory limit in cronjob.yml:

```yaml
resources:
  limits:
    memory: 1Gi  # Increased from 512Mi
```

## Configuration Changes

### Change Schedule

Edit CronJob schedule:

```bash
kubectl edit cronjob exchange-health-check -n forex-prod
```

Modify `.spec.schedule` (cron format)

### Change Thresholds

Update ConfigMap or rebuild image with modified `config/thresholds.yaml`

### Change Target Service

Update ConfigMap:

```bash
kubectl edit configmap exchange-health-check-config -n forex-prod
```

Modify `SERVICE_NAME`, `DEPLOYMENT_NAME`, `HPA_NAME`

## Cleanup

To remove all resources:

```bash
kubectl delete cronjob exchange-health-check -n forex-prod
kubectl delete pvc health-check-reports -n forex-prod
kubectl delete configmap exchange-health-check-config -n forex-prod
kubectl delete secret slack-credentials -n forex-prod
kubectl delete -f deployment/rbac.yml
```
