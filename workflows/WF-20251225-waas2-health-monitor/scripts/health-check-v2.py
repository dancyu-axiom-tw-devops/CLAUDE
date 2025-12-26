#!/usr/bin/env python3
"""
Waas2 Tenant Services Health Check (v2 with Prometheus)
按照 k8s-service-monitor.md 規則進行 8 項巡檢
"""

import json
import os
import sys
import subprocess
import base64
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import urllib.request
import urllib.parse
import urllib.error

NAMESPACE = "waas2-prod"
TIME_WINDOW_HOURS = 24

# Services to monitor
SERVICES = [
    "service-admin",
    "service-api",
    "service-eth",
    "service-exchange",
    "service-gateway",
    "service-notice",
    "service-pol",
    "service-search",
    "service-setting",
    "service-tron",
    "service-user",
]

# Prometheus configuration
PROMETHEUS_URL = os.getenv("PROMETHEUS_URL", "")
PROMETHEUS_USERNAME = os.getenv("PROMETHEUS_USERNAME", "")
PROMETHEUS_PASSWORD = os.getenv("PROMETHEUS_PASSWORD", "")


def run_kubectl(args: List[str]) -> str:
    """Execute kubectl command and return output"""
    cmd = ["kubectl"] + args
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        return ""
    except Exception as e:
        print(f"Error running kubectl: {e}", file=sys.stderr)
        return ""


def query_prometheus(query: str, time_range: Optional[Tuple[datetime, datetime]] = None) -> Dict:
    """Query Prometheus API with basic auth"""
    if not PROMETHEUS_URL:
        return {"status": "error", "error": "PROMETHEUS_URL not set"}

    try:
        # Build URL
        if time_range:
            # Range query
            start, end = time_range
            params = {
                "query": query,
                "start": int(start.timestamp()),
                "end": int(end.timestamp()),
                "step": "5m"
            }
            url = f"{PROMETHEUS_URL}/api/v1/query_range?{urllib.parse.urlencode(params)}"
        else:
            # Instant query
            params = {"query": query}
            url = f"{PROMETHEUS_URL}/api/v1/query?{urllib.parse.urlencode(params)}"

        # Create request with basic auth
        req = urllib.request.Request(url)
        if PROMETHEUS_USERNAME and PROMETHEUS_PASSWORD:
            credentials = f"{PROMETHEUS_USERNAME}:{PROMETHEUS_PASSWORD}"
            encoded_credentials = base64.b64encode(credentials.encode()).decode()
            req.add_header("Authorization", f"Basic {encoded_credentials}")

        # Execute request
        with urllib.request.urlopen(req, timeout=30) as response:
            data = json.loads(response.read().decode())
            return data

    except urllib.error.HTTPError as e:
        print(f"Prometheus HTTP error: {e.code} {e.reason}", file=sys.stderr)
        return {"status": "error", "error": f"HTTP {e.code}"}
    except urllib.error.URLError as e:
        print(f"Prometheus URL error: {e.reason}", file=sys.stderr)
        return {"status": "error", "error": str(e.reason)}
    except Exception as e:
        print(f"Prometheus query error: {e}", file=sys.stderr)
        return {"status": "error", "error": str(e)}


def get_deployment_info(service: str) -> Dict:
    """Get deployment information"""
    result = {
        "exists": False,
        "replicas": {"desired": 0, "ready": 0, "available": 0},
        "resources": {"memory_limit": 0, "memory_request": 0, "cpu_limit": 0, "cpu_request": 0}
    }

    check = run_kubectl(["get", "deployment", service, "-n", NAMESPACE, "-o", "json"])
    if not check:
        return result

    try:
        data = json.loads(check)
        result["exists"] = True
        spec = data.get("spec", {})
        status = data.get("status", {})

        result["replicas"]["desired"] = spec.get("replicas", 0)
        result["replicas"]["ready"] = status.get("readyReplicas", 0)
        result["replicas"]["available"] = status.get("availableReplicas", 0)

        # Extract resource limits/requests
        containers = spec.get("template", {}).get("spec", {}).get("containers", [])
        if containers:
            resources = containers[0].get("resources", {})
            limits = resources.get("limits", {})
            requests = resources.get("requests", {})

            # Parse memory (e.g., "512Mi" -> 512)
            if "memory" in limits:
                mem_str = limits["memory"]
                result["resources"]["memory_limit"] = parse_memory(mem_str)
            if "memory" in requests:
                mem_str = requests["memory"]
                result["resources"]["memory_request"] = parse_memory(mem_str)

            # Parse CPU (e.g., "200m" -> 0.2)
            if "cpu" in limits:
                cpu_str = limits["cpu"]
                result["resources"]["cpu_limit"] = parse_cpu(cpu_str)
            if "cpu" in requests:
                cpu_str = requests["cpu"]
                result["resources"]["cpu_request"] = parse_cpu(cpu_str)

    except json.JSONDecodeError:
        pass

    return result


def parse_memory(mem_str: str) -> int:
    """Parse memory string to MiB (e.g., '512Mi' -> 512, '1Gi' -> 1024)"""
    mem_str = mem_str.strip()
    if mem_str.endswith("Mi"):
        return int(mem_str[:-2])
    elif mem_str.endswith("Gi"):
        return int(mem_str[:-2]) * 1024
    elif mem_str.endswith("M"):
        return int(mem_str[:-1])
    elif mem_str.endswith("G"):
        return int(mem_str[:-1]) * 1024
    else:
        # Assume bytes
        return int(mem_str) // (1024 * 1024)


def parse_cpu(cpu_str: str) -> float:
    """Parse CPU string to cores (e.g., '200m' -> 0.2, '1' -> 1.0)"""
    cpu_str = cpu_str.strip()
    if cpu_str.endswith("m"):
        return int(cpu_str[:-1]) / 1000.0
    else:
        return float(cpu_str)


def get_pod_info(service: str) -> List[Dict]:
    """Get pod information for a service"""
    pods_json = run_kubectl([
        "get", "pods", "-n", NAMESPACE,
        "-l", f"app={service}",
        "-o", "json"
    ])

    pods = []
    try:
        data = json.loads(pods_json)
        for pod in data.get("items", []):
            pod_name = pod["metadata"]["name"]
            status = pod["status"]

            container_statuses = status.get("containerStatuses", [])
            restart_count = 0
            if container_statuses:
                restart_count = container_statuses[0].get("restartCount", 0)

            pods.append({
                "name": pod_name,
                "phase": status.get("phase", "Unknown"),
                "restarts": restart_count,
            })
    except json.JSONDecodeError:
        pass

    return pods


def get_events(service: str) -> Dict:
    """Get events for a service"""
    events_json = run_kubectl([
        "get", "events", "-n", NAMESPACE,
        "--field-selector", f"involvedObject.name={service}",
        "-o", "json"
    ])

    result = {"oom_killed": 0, "restarts": 0, "events": []}

    try:
        data = json.loads(events_json)
        for event in data.get("items", []):
            reason = event.get("reason", "")
            message = event.get("message", "")

            if "OOMKilled" in reason or "OOMKilled" in message:
                result["oom_killed"] += 1
            elif "BackOff" in reason or "CrashLoop" in reason:
                result["restarts"] += 1

            result["events"].append({
                "reason": reason,
                "message": message,
                "time": event.get("lastTimestamp") or event.get("eventTime")
            })
    except json.JSONDecodeError:
        pass

    return result


def get_memory_metrics(service: str) -> Dict:
    """Get memory metrics from Prometheus"""
    result = {
        "avg_mi": 0,
        "max_mi": 0,
        "p95_mi": 0,
        "available": False
    }

    if not PROMETHEUS_URL:
        return result

    # Query average memory over 24h
    query_avg = f'avg_over_time(container_memory_working_set_bytes{{namespace="{NAMESPACE}", pod=~"{service}-.*", container="{service}"}}[{TIME_WINDOW_HOURS}h])'
    data = query_prometheus(query_avg)

    if data.get("status") == "success" and data.get("data", {}).get("result"):
        results = data["data"]["result"]
        if results:
            # Get average across all pods
            values = [float(r["value"][1]) for r in results]
            result["avg_mi"] = int(sum(values) / len(values) / (1024 * 1024))
            result["available"] = True

    # Query max memory
    query_max = f'max_over_time(container_memory_working_set_bytes{{namespace="{NAMESPACE}", pod=~"{service}-.*", container="{service}"}}[{TIME_WINDOW_HOURS}h])'
    data = query_prometheus(query_max)

    if data.get("status") == "success" and data.get("data", {}).get("result"):
        results = data["data"]["result"]
        if results:
            values = [float(r["value"][1]) for r in results]
            result["max_mi"] = int(max(values) / (1024 * 1024))

    # Query P95
    query_p95 = f'quantile_over_time(0.95, container_memory_working_set_bytes{{namespace="{NAMESPACE}", pod=~"{service}-.*", container="{service}"}}[{TIME_WINDOW_HOURS}h])'
    data = query_prometheus(query_p95)

    if data.get("status") == "success" and data.get("data", {}).get("result"):
        results = data["data"]["result"]
        if results:
            values = [float(r["value"][1]) for r in results]
            result["p95_mi"] = int(sum(values) / len(values) / (1024 * 1024))

    return result


def get_cpu_metrics(service: str) -> Dict:
    """Get CPU metrics from Prometheus"""
    result = {
        "avg_cores": 0,
        "max_cores": 0,
        "available": False
    }

    if not PROMETHEUS_URL:
        return result

    # Query average CPU usage (rate over 5m, then average over 24h)
    query = f'avg_over_time(rate(container_cpu_usage_seconds_total{{namespace="{NAMESPACE}", pod=~"{service}-.*", container="{service}"}}[5m])[{TIME_WINDOW_HOURS}h:5m])'
    data = query_prometheus(query)

    if data.get("status") == "success" and data.get("data", {}).get("result"):
        results = data["data"]["result"]
        if results:
            values = [float(r["value"][1]) for r in results]
            result["avg_cores"] = sum(values) / len(values)
            result["max_cores"] = max(values)
            result["available"] = True

    return result


def check_availability(deployment: Dict) -> str:
    """1️⃣ 可用性檢查"""
    if not deployment["exists"]:
        return "🔴"

    ready = deployment["replicas"]["ready"]
    desired = deployment["replicas"]["desired"]

    if ready == desired and ready > 0:
        return "🟢"
    else:
        return "🔴"


def check_stability(pods: List[Dict], events: Dict) -> str:
    """2️⃣ 穩定性檢查"""
    if events["oom_killed"] > 0:
        return "🔴"

    total_restarts = sum(p["restarts"] for p in pods)
    if total_restarts == 0:
        return "🟢"
    else:
        return "🟡"


def check_memory_usage(memory_metrics: Dict, deployment: Dict) -> str:
    """3️⃣ 記憶體使用檢查"""
    if not memory_metrics["available"]:
        return "⚪"

    memory_limit = deployment["resources"]["memory_limit"]
    if memory_limit == 0:
        return "🔴"  # 無 limit 設定

    max_mi = memory_metrics["max_mi"]
    usage_pct = (max_mi / memory_limit) * 100

    if usage_pct < 70:
        return "🟢"
    elif usage_pct < 85:
        return "🟡"
    else:
        return "🔴"


def check_memory_trend(service: str) -> str:
    """4️⃣ 記憶體趨勢檢查（簡化版）"""
    if not PROMETHEUS_URL:
        return "⚪"

    # Query memory over time to check trend
    end = datetime.utcnow()
    start = end - timedelta(hours=TIME_WINDOW_HOURS)

    query = f'container_memory_working_set_bytes{{namespace="{NAMESPACE}", pod=~"{service}-.*", container="{service}"}}'
    data = query_prometheus(query, time_range=(start, end))

    if data.get("status") != "success" or not data.get("data", {}).get("result"):
        return "⚪"

    results = data["data"]["result"]
    if not results:
        return "⚪"

    # Simple trend check: compare last 4h avg vs first 4h avg
    try:
        values = results[0]["values"]
        if len(values) < 10:
            return "⚪"

        # Split into quarters
        quarter = len(values) // 4
        first_quarter = [float(v[1]) for v in values[:quarter]]
        last_quarter = [float(v[1]) for v in values[-quarter:]]

        avg_first = sum(first_quarter) / len(first_quarter)
        avg_last = sum(last_quarter) / len(last_quarter)

        growth_pct = ((avg_last - avg_first) / avg_first) * 100

        if growth_pct > 20:  # 成長超過 20%
            return "🔴"
        elif growth_pct > 10:  # 成長 10-20%
            return "🟡"
        else:
            return "🟢"
    except:
        return "⚪"


def check_cpu_usage(cpu_metrics: Dict, deployment: Dict) -> str:
    """5️⃣ CPU 使用檢查"""
    if not cpu_metrics["available"]:
        return "⚪"

    cpu_request = deployment["resources"]["cpu_request"]
    if cpu_request == 0:
        return "⚪"

    avg_cores = cpu_metrics["avg_cores"]
    usage_pct = (avg_cores / cpu_request) * 100

    if usage_pct < 80:
        return "🟢"
    elif usage_pct < 100:
        return "🟡"
    else:
        return "🔴"


def check_error_rate() -> str:
    """6️⃣ 錯誤率檢查 - 需應用 metrics"""
    return "⚪"


def check_latency() -> str:
    """7️⃣ 延遲檢查 - 需應用 metrics"""
    return "⚪"


def check_scaling(deployment: Dict, memory_metrics: Dict, cpu_metrics: Dict) -> str:
    """8️⃣ Pod 數量合理性檢查"""
    if not deployment["exists"]:
        return "🔴"

    replicas = deployment["replicas"]["ready"]
    if replicas == 0:
        return "🔴"

    # Check if over-provisioned (many pods but low usage)
    if memory_metrics["available"] and cpu_metrics["available"]:
        memory_limit = deployment["resources"]["memory_limit"]
        cpu_request = deployment["resources"]["cpu_request"]

        if memory_limit > 0 and cpu_request > 0:
            mem_usage_pct = (memory_metrics["avg_mi"] / memory_limit) * 100
            cpu_usage_pct = (cpu_metrics["avg_cores"] / cpu_request) * 100

            # Pod 多但使用率低
            if replicas >= 3 and mem_usage_pct < 30 and cpu_usage_pct < 30:
                return "🟡"

    return "🟢"


def determine_overall_status(checks: Dict) -> str:
    """根據 k8s-service-monitor.md 判定整體狀態"""
    values = list(checks.values())

    if "🔴" in values:
        return "🔴"

    if "🟡" in values:
        return "🟡"

    insufficient_count = values.count("⚪")
    if insufficient_count >= 3:
        return "🟡"

    return "🟢"


def check_service(service: str) -> Dict:
    """Perform complete health check for a service"""
    print(f"Checking {service}...", file=sys.stderr)

    deployment = get_deployment_info(service)
    pods = get_pod_info(service)
    events = get_events(service)
    memory_metrics = get_memory_metrics(service)
    cpu_metrics = get_cpu_metrics(service)

    checks = {
        "availability": check_availability(deployment),
        "stability": check_stability(pods, events),
        "memory_usage": check_memory_usage(memory_metrics, deployment),
        "memory_trend": check_memory_trend(service),
        "cpu_usage": check_cpu_usage(cpu_metrics, deployment),
        "error_rate": check_error_rate(),
        "latency": check_latency(),
        "scaling": check_scaling(deployment, memory_metrics, cpu_metrics),
    }

    status = determine_overall_status(checks)

    # Build notes
    notes = []
    if not deployment["exists"]:
        notes.append("Deployment not found")
    elif deployment["replicas"]["ready"] < deployment["replicas"]["desired"]:
        notes.append(f"Only {deployment['replicas']['ready']}/{deployment['replicas']['desired']} pods ready")

    total_restarts = sum(p["restarts"] for p in pods)
    if total_restarts > 0:
        notes.append(f"{total_restarts} restart(s) in {TIME_WINDOW_HOURS}h")

    if events["oom_killed"] > 0:
        notes.append(f"OOMKilled: {events['oom_killed']} time(s)")

    if memory_metrics["available"]:
        mem_limit = deployment["resources"]["memory_limit"]
        if mem_limit > 0:
            usage_pct = (memory_metrics["max_mi"] / mem_limit) * 100
            notes.append(f"Memory peak: {memory_metrics['max_mi']}Mi ({usage_pct:.1f}% of {mem_limit}Mi limit)")

    if cpu_metrics["available"]:
        cpu_req = deployment["resources"]["cpu_request"]
        if cpu_req > 0:
            usage_pct = (cpu_metrics["avg_cores"] / cpu_req) * 100
            notes.append(f"CPU avg: {cpu_metrics['avg_cores']:.2f} cores ({usage_pct:.1f}% of {cpu_req:.2f} request)")

    return {
        "service": service,
        "namespace": NAMESPACE,
        "status": status,
        "checks": checks,
        "notes": notes,
        "deployment": deployment,
        "pods": pods,
        "memory_metrics": memory_metrics,
        "cpu_metrics": cpu_metrics,
    }


def generate_report(results: List[Dict]) -> str:
    """Generate Markdown report"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    red_services = [r for r in results if r["status"] == "🔴"]
    yellow_services = [r for r in results if r["status"] == "🟡"]
    green_services = [r for r in results if r["status"] == "🟢"]

    report = f"""# Waas2 Tenant 服務健康檢查報告

**檢查時間**: {timestamp}
**檢查範圍**: 過去 {TIME_WINDOW_HOURS} 小時
**命名空間**: {NAMESPACE}
**Prometheus**: {"✅ 已連接" if PROMETHEUS_URL else "❌ 未配置"}

## 整體狀態

- 🔴 高風險服務: {len(red_services)} 個
- 🟡 需關注服務: {len(yellow_services)} 個
- 🟢 健康服務: {len(green_services)} 個
- **總計**: {len(results)} 個服務

---

"""

    if red_services:
        report += "## 🔴 高風險服務\n\n"
        for r in red_services:
            report += f"### {r['service']}\n\n"
            report += f"**整體狀態**: {r['status']}\n\n"
            report += "**檢查項目**:\n"
            for check_name, check_status in r['checks'].items():
                report += f"- {check_name}: {check_status}\n"
            report += "\n**問題說明**:\n"
            for note in r['notes']:
                report += f"- {note}\n"
            report += "\n---\n\n"

    if yellow_services:
        report += "## 🟡 需關注服務\n\n"
        for r in yellow_services:
            notes_str = ", ".join(r['notes']) if r['notes'] else "無"
            report += f"- **{r['service']}**: {notes_str}\n"
        report += "\n---\n\n"

    if green_services:
        report += "## 🟢 健康服務\n\n"
        service_names = [r['service'] for r in green_services]
        report += ", ".join(service_names) + "\n\n"
        report += "---\n\n"

    report += "## 詳細檢查結果\n\n"
    report += "| 服務 | 狀態 | 可用性 | 穩定性 | 記憶體 | 趨勢 | CPU | 擴展 |\n"
    report += "|------|------|--------|--------|--------|------|-----|------|\n"

    for r in results:
        c = r['checks']
        report += f"| {r['service']} | {r['status']} | {c['availability']} | {c['stability']} | {c['memory_usage']} | {c['memory_trend']} | {c['cpu_usage']} | {c['scaling']} |\n"

    report += "\n---\n\n"
    report += f"*檢查時間: {timestamp}*\n"
    report += "*根據 k8s-service-monitor.md 規則生成*\n"

    return report


def generate_slack_message(results: List[Dict]) -> Dict:
    """Generate Slack message"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    red_services = [r for r in results if r["status"] == "🔴"]
    yellow_count = len([r for r in results if r["status"] == "🟡"])

    issue_counts = {}
    for r in red_services + [r for r in results if r["status"] == "🟡"]:
        for note in r["notes"]:
            issue_counts[note] = issue_counts.get(note, 0) + 1

    top_issues = sorted(issue_counts.items(), key=lambda x: x[1], reverse=True)[:3]

    if red_services:
        color = "danger"
        title = f"🔴 Waas2 Tenant 服務健康警告 ({len(red_services)} 個高風險)"
    elif yellow_count > 0:
        color = "warning"
        title = f"🟡 Waas2 Tenant 服務狀態提醒 ({yellow_count} 個需關注)"
    else:
        color = "good"
        title = "🟢 Waas2 Tenant 服務全部健康"

    text = f"檢查時間: {timestamp}\n命名空間: {NAMESPACE}\n"

    if red_services:
        text += "\n*高風險服務*:\n"
        for r in red_services:
            notes_str = ", ".join(r['notes'][:2])
            text += f"• `{r['service']}`: {notes_str}\n"

    if yellow_count > 0:
        text += f"\n*需關注服務*: {yellow_count} 個\n"

    if top_issues:
        text += "\n*主要問題*:\n"
        for issue, count in top_issues:
            text += f"• {issue} ({count}次)\n"

    return {
        "attachments": [{
            "color": color,
            "title": title,
            "text": text,
            "footer": "Waas2 Health Monitor",
            "ts": int(datetime.now().timestamp())
        }]
    }


def send_to_slack(webhook_url: str, message: Dict):
    """Send message to Slack webhook"""
    data = json.dumps(message).encode('utf-8')
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={'Content-Type': 'application/json'}
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                print("Slack notification sent successfully", file=sys.stderr)
            else:
                print(f"Slack returned status {response.status}", file=sys.stderr)
    except Exception as e:
        print(f"Failed to send Slack notification: {e}", file=sys.stderr)


def main():
    print(f"Starting Waas2 Tenant Health Check at {datetime.now()}", file=sys.stderr)
    print(f"Namespace: {NAMESPACE}", file=sys.stderr)
    print(f"Time window: {TIME_WINDOW_HOURS} hours", file=sys.stderr)
    print(f"Prometheus: {PROMETHEUS_URL or 'Not configured'}", file=sys.stderr)
    print(f"Services: {len(SERVICES)}", file=sys.stderr)
    print("", file=sys.stderr)

    results = []
    for service in SERVICES:
        result = check_service(service)
        results.append(result)

    report = generate_report(results)
    print(report)

    report_dir = os.getenv("REPORT_DIR", "/reports")
    os.makedirs(report_dir, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    report_file = f"{report_dir}/health-check-{timestamp}.md"
    with open(report_file, "w") as f:
        f.write(report)
    print(f"\nReport saved to: {report_file}", file=sys.stderr)

    webhook_url = os.getenv("SLACK_WEBHOOK_URL")
    if webhook_url:
        slack_message = generate_slack_message(results)
        send_to_slack(webhook_url, slack_message)
    else:
        print("SLACK_WEBHOOK_URL not set, skipping Slack notification", file=sys.stderr)

    red_count = len([r for r in results if r["status"] == "🔴"])
    sys.exit(1 if red_count > 0 else 0)


if __name__ == "__main__":
    main()
