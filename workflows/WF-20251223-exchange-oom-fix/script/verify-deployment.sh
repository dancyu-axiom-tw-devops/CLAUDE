#!/bin/bash
# verify-deployment.sh
# Automated deployment verification for exchange-service OOM fix

set -e

NAMESPACE="forex-prod"
APP="exchange-service"
HPA_NAME="exchange-service-hpa"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

print_header() {
  echo "======================================"
  echo "$1"
  echo "======================================"
}

check_pass() {
  echo -e "${GREEN}✅ PASS${NC}: $1"
  ((PASSED++))
}

check_fail() {
  echo -e "${RED}❌ FAIL${NC}: $1"
  ((FAILED++))
}

check_warn() {
  echo -e "${YELLOW}⚠️  WARN${NC}: $1"
  ((WARNINGS++))
}

print_header "Exchange Service OOM Fix - Deployment Verification"
echo "Timestamp: $(date)"
echo ""

# Check 1: Pod Count and Status
print_header "Check 1: Pod Status"
PODS=$(kubectl get pods -n $NAMESPACE -l app=$APP --no-headers 2>/dev/null || echo "")

if [ -z "$PODS" ]; then
  check_fail "No pods found for app=$APP"
else
  POD_COUNT=$(echo "$PODS" | wc -l | xargs)
  RUNNING_COUNT=$(echo "$PODS" | grep -c "Running" || echo "0")

  echo "Pod Count: $POD_COUNT"
  echo "Running: $RUNNING_COUNT"
  echo ""
  kubectl get pods -n $NAMESPACE -l app=$APP

  if [ "$POD_COUNT" -ge 2 ]; then
    check_pass "Pod count >= 2 (found: $POD_COUNT)"
  else
    check_fail "Pod count < 2 (found: $POD_COUNT)"
  fi

  if [ "$RUNNING_COUNT" -eq "$POD_COUNT" ]; then
    check_pass "All pods are Running"
  else
    check_fail "Not all pods are Running ($RUNNING_COUNT/$POD_COUNT)"
  fi

  # Check RESTARTS
  MAX_RESTARTS=$(kubectl get pods -n $NAMESPACE -l app=$APP -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | sort -n | tail -1)
  if [ "$MAX_RESTARTS" -eq 0 ] 2>/dev/null; then
    check_pass "No pod restarts (RESTARTS=0)"
  elif [ "$MAX_RESTARTS" -lt 3 ] 2>/dev/null; then
    check_warn "Some pods restarted (max: $MAX_RESTARTS)"
  else
    check_fail "High restart count (max: $MAX_RESTARTS)"
  fi
fi
echo ""

# Check 2: Deployment Status
print_header "Check 2: Deployment Status"
DEPLOYMENT=$(kubectl get deployment $APP -n $NAMESPACE --no-headers 2>/dev/null || echo "")

if [ -z "$DEPLOYMENT" ]; then
  check_fail "Deployment not found"
else
  kubectl get deployment $APP -n $NAMESPACE
  echo ""

  READY=$(echo "$DEPLOYMENT" | awk '{print $2}')
  UP_TO_DATE=$(echo "$DEPLOYMENT" | awk '{print $3}')
  AVAILABLE=$(echo "$DEPLOYMENT" | awk '{print $4}')

  if [ "$READY" = "2/2" ]; then
    check_pass "Deployment ready (2/2)"
  else
    check_warn "Deployment not fully ready ($READY)"
  fi

  # Check RollingUpdate strategy
  STRATEGY=$(kubectl get deployment $APP -n $NAMESPACE -o jsonpath='{.spec.strategy.type}')
  if [ "$STRATEGY" = "RollingUpdate" ]; then
    check_pass "Strategy is RollingUpdate"

    MAX_SURGE=$(kubectl get deployment $APP -n $NAMESPACE -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}')
    MAX_UNAVAILABLE=$(kubectl get deployment $APP -n $NAMESPACE -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}')

    if [ "$MAX_SURGE" = "1" ] && [ "$MAX_UNAVAILABLE" = "0" ]; then
      check_pass "RollingUpdate strategy correct (maxSurge:1, maxUnavailable:0)"
    else
      check_warn "RollingUpdate strategy not optimal (maxSurge:$MAX_SURGE, maxUnavailable:$MAX_UNAVAILABLE)"
    fi
  else
    check_warn "Strategy is not RollingUpdate (found: $STRATEGY)"
  fi
fi
echo ""

# Check 3: HPA Status
print_header "Check 3: HPA Status"
HPA=$(kubectl get hpa $HPA_NAME -n $NAMESPACE --no-headers 2>/dev/null || echo "")

if [ -z "$HPA" ]; then
  check_fail "HPA not found"
else
  kubectl get hpa $HPA_NAME -n $NAMESPACE
  echo ""

  MIN_REPLICAS=$(kubectl get hpa $HPA_NAME -n $NAMESPACE -o jsonpath='{.spec.minReplicas}')
  MAX_REPLICAS=$(kubectl get hpa $HPA_NAME -n $NAMESPACE -o jsonpath='{.spec.maxReplicas}')
  CURRENT_REPLICAS=$(kubectl get hpa $HPA_NAME -n $NAMESPACE -o jsonpath='{.status.currentReplicas}')

  if [ "$MIN_REPLICAS" = "2" ]; then
    check_pass "HPA minReplicas = 2"
  else
    check_fail "HPA minReplicas != 2 (found: $MIN_REPLICAS)"
  fi

  if [ "$MAX_REPLICAS" = "10" ]; then
    check_pass "HPA maxReplicas = 10"
  else
    check_warn "HPA maxReplicas != 10 (found: $MAX_REPLICAS)"
  fi

  if [ "$CURRENT_REPLICAS" -ge 2 ]; then
    check_pass "HPA current replicas >= 2 (found: $CURRENT_REPLICAS)"
  else
    check_fail "HPA current replicas < 2 (found: $CURRENT_REPLICAS)"
  fi

  # Check if metrics are available
  TARGETS=$(kubectl get hpa $HPA_NAME -n $NAMESPACE -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>/dev/null || echo "")
  if [ ! -z "$TARGETS" ]; then
    check_pass "HPA metrics available (CPU utilization: ${TARGETS}%)"
  else
    check_warn "HPA metrics not available (Metrics Server may not be running)"
  fi
fi
echo ""

# Check 4: JVM Parameters
print_header "Check 4: JVM Parameters"
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$APP -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$POD_NAME" ]; then
  check_fail "No pod found to verify JVM parameters"
else
  echo "Checking JVM parameters in pod: $POD_NAME"

  JVM_ARGS=$(kubectl exec -n $NAMESPACE $POD_NAME -- env 2>/dev/null | grep "ARGS1" || echo "")

  if [ -z "$JVM_ARGS" ]; then
    check_fail "ARGS1 environment variable not found"
  else
    echo "ARGS1: $JVM_ARGS"
    echo ""

    # Check individual parameters
    if echo "$JVM_ARGS" | grep -q "Xms3072m"; then
      check_pass "Xms3072m found"
    else
      check_fail "Xms3072m not found"
    fi

    if echo "$JVM_ARGS" | grep -q "Xmx4096m"; then
      check_pass "Xmx4096m found"
    else
      check_fail "Xmx4096m not found"
    fi

    if echo "$JVM_ARGS" | grep -q "\+UseG1GC"; then
      check_pass "UseG1GC enabled"
    else
      check_fail "UseG1GC not enabled"
    fi

    if echo "$JVM_ARGS" | grep -q "MaxGCPauseMillis=200"; then
      check_pass "MaxGCPauseMillis=200 found"
    else
      check_warn "MaxGCPauseMillis=200 not found"
    fi

    if echo "$JVM_ARGS" | grep -q "\+HeapDumpOnOutOfMemoryError"; then
      check_pass "HeapDumpOnOutOfMemoryError enabled"
    else
      check_fail "HeapDumpOnOutOfMemoryError not enabled"
    fi

    if echo "$JVM_ARGS" | grep -q "Xloggc"; then
      check_pass "GC logging enabled"
    else
      check_fail "GC logging not enabled"
    fi
  fi
fi
echo ""

# Check 5: Memory Usage
print_header "Check 5: Memory Usage"
MEMORY_OUTPUT=$(kubectl top pods -n $NAMESPACE -l app=$APP --no-headers 2>&1 || echo "")

if echo "$MEMORY_OUTPUT" | grep -q "error\|Metrics"; then
  check_warn "Cannot get memory metrics (Metrics Server may not be available)"
  echo "$MEMORY_OUTPUT"
else
  kubectl top pods -n $NAMESPACE -l app=$APP
  echo ""

  TOTAL_MEMORY=0
  while read -r line; do
    MEMORY=$(echo "$line" | awk '{print $3}' | sed 's/Mi//')
    if [ ! -z "$MEMORY" ]; then
      TOTAL_MEMORY=$((TOTAL_MEMORY + MEMORY))
    fi
  done <<< "$MEMORY_OUTPUT"

  echo "Total Memory Usage: ${TOTAL_MEMORY}Mi"

  if [ $TOTAL_MEMORY -lt 5000 ]; then
    check_pass "Memory usage < 5000Mi (found: ${TOTAL_MEMORY}Mi)"
  elif [ $TOTAL_MEMORY -lt 5500 ]; then
    check_warn "Memory usage 5000-5500Mi (found: ${TOTAL_MEMORY}Mi)"
  else
    check_fail "Memory usage >= 5500Mi (found: ${TOTAL_MEMORY}Mi, limit: 6144Mi)"
  fi
fi
echo ""

# Check 6: OOM Events
print_header "Check 6: OOM Events"
OOM_EVENTS=$(kubectl get events -n $NAMESPACE --field-selector reason=OOMKilling --sort-by='.lastTimestamp' 2>/dev/null | grep $APP | tail -5 || echo "")

if [ -z "$OOM_EVENTS" ]; then
  check_pass "No OOMKilled events found"
else
  echo "Recent OOM events:"
  echo "$OOM_EVENTS"
  echo ""
  check_fail "OOMKilled events detected"
fi
echo ""

# Check 7: GC Log
print_header "Check 7: GC Log Setup"
if [ ! -z "$POD_NAME" ]; then
  GC_LOG_CHECK=$(kubectl exec -n $NAMESPACE $POD_NAME -- ls -lh /forex/log/exchange-service/gc.log 2>/dev/null || echo "NOT_FOUND")

  if [ "$GC_LOG_CHECK" = "NOT_FOUND" ]; then
    check_warn "GC log file not found (may not have started yet)"
  else
    echo "GC log file:"
    echo "$GC_LOG_CHECK"
    check_pass "GC log file exists and writable"
  fi
else
  check_warn "Cannot check GC log (no pod available)"
fi
echo ""

# Summary
print_header "Verification Summary"
echo -e "${GREEN}Passed${NC}: $PASSED"
echo -e "${YELLOW}Warnings${NC}: $WARNINGS"
echo -e "${RED}Failed${NC}: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ Deployment verification PASSED${NC}"
  if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Note: There are $WARNINGS warning(s) that should be reviewed${NC}"
  fi
  exit 0
else
  echo -e "${RED}❌ Deployment verification FAILED with $FAILED error(s)${NC}"
  echo "Please review the failed checks above and take corrective action."
  exit 1
fi
