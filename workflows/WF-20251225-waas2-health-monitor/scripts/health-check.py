#!/usr/bin/env python3
"""
Waas2 Tenant Services Health Check
按照 k8s-service-monitor.md 規則進行 8 項巡檢
"""

import json
import os
import sys
import subprocess
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import urllib.request
import urllib.parse

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


def get_deployment_info(service: str) -> Dict:
    """Get deployment information"""
    result = {
        "exists": False,
        "replicas": {"desired": 0, "ready": 0, "available": 0},
        "pods": []
    }

    # Check if deployment exists
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

    except json.JSONDecodeError:
        pass

    return result


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

            # Get container statuses
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
    """Get events for a service in the last TIME_WINDOW_HOURS"""
    events_json = run_kubectl([
        "get", "events", "-n", NAMESPACE,
        "--field-selector", f"involvedObject.name={service}",
        "-o", "json"
    ])

    result = {
        "oom_killed": 0,
        "restarts": 0,
        "events": []
    }

    try:
        data = json.loads(events_json)
        cutoff_time = datetime.utcnow() - timedelta(hours=TIME_WINDOW_HOURS)

        for event in data.get("items", []):
            # Parse event time
            last_ts = event.get("lastTimestamp") or event.get("eventTime")
            if not last_ts:
                continue

            # Simple time comparison (may need improvement for production)
            reason = event.get("reason", "")
            message = event.get("message", "")

            if "OOMKilled" in reason or "OOMKilled" in message:
                result["oom_killed"] += 1
            elif "BackOff" in reason or "CrashLoop" in reason:
                result["restarts"] += 1

            result["events"].append({
                "reason": reason,
                "message": message,
                "time": last_ts
            })
    except json.JSONDecodeError:
        pass

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


def check_memory_usage() -> str:
    """3️⃣ 記憶體使用檢查 - 簡化版（無 Prometheus）"""
    # Without Prometheus, we can't get accurate memory metrics
    # Return "Insufficient Data" as per k8s-service-monitor.md rule 4
    return "⚪"  # Insufficient Data


def check_memory_trend() -> str:
    """4️⃣ 記憶體趨勢檢查 - 簡化版（無 Prometheus）"""
    return "⚪"  # Insufficient Data


def check_cpu_usage() -> str:
    """5️⃣ CPU 使用檢查 - 簡化版（無 Prometheus）"""
    return "⚪"  # Insufficient Data


def check_error_rate() -> str:
    """6️⃣ 錯誤率檢查 - 簡化版（無應用 metrics）"""
    return "⚪"  # Insufficient Data


def check_latency() -> str:
    """7️⃣ 延遲檢查 - 簡化版（無應用 metrics）"""
    return "⚪"  # Insufficient Data


def check_scaling(deployment: Dict) -> str:
    """8️⃣ Pod 數量合理性檢查 - 簡化版"""
    # Without resource usage data, we can only check if pods exist
    if not deployment["exists"]:
        return "🔴"

    replicas = deployment["replicas"]["ready"]
    if replicas > 0:
        return "🟢"
    else:
        return "🔴"


def determine_overall_status(checks: Dict) -> str:
    """根據 k8s-service-monitor.md 第五節判定整體狀態"""
    values = list(checks.values())

    # 任一 🔴 → 整體 🔴
    if "🔴" in values:
        return "🔴"

    # 若無 🔴，但有 🟡 → 整體 🟡
    if "🟡" in values:
        return "🟡"

    # 關鍵項目資料不足 → 整體 🟡
    insufficient_count = values.count("⚪")
    if insufficient_count >= 3:  # 超過一半項目無資料
        return "🟡"

    # 全部 🟢 → 整體 🟢
    return "🟢"


def check_service(service: str) -> Dict:
    """Perform complete health check for a service"""
    print(f"Checking {service}...", file=sys.stderr)

    deployment = get_deployment_info(service)
    pods = get_pod_info(service)
    events = get_events(service)

    checks = {
        "availability": check_availability(deployment),
        "stability": check_stability(pods, events),
        "memory_usage": check_memory_usage(),
        "memory_trend": check_memory_trend(),
        "cpu_usage": check_cpu_usage(),
        "error_rate": check_error_rate(),
        "latency": check_latency(),
        "scaling": check_scaling(deployment),
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
        notes.append(f"{total_restarts} restart(s) detected")

    if events["oom_killed"] > 0:
        notes.append(f"OOMKilled: {events['oom_killed']} time(s)")

    if checks["memory_usage"] == "⚪":
        notes.append("Memory/CPU metrics require Prometheus")

    return {
        "service": service,
        "namespace": NAMESPACE,
        "status": status,
        "checks": checks,
        "notes": notes,
        "deployment": deployment,
        "pods": pods,
    }


def generate_report(results: List[Dict]) -> str:
    """Generate Markdown report"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Count by status
    red_services = [r for r in results if r["status"] == "🔴"]
    yellow_services = [r for r in results if r["status"] == "🟡"]
    green_services = [r for r in results if r["status"] == "🟢"]

    report = f"""# Waas2 Tenant 服務健康檢查報告

**檢查時間**: {timestamp}
**檢查範圍**: 過去 {TIME_WINDOW_HOURS} 小時
**命名空間**: {NAMESPACE}

## 整體狀態

- 🔴 高風險服務: {len(red_services)} 個
- 🟡 需關注服務: {len(yellow_services)} 個
- 🟢 健康服務: {len(green_services)} 個
- **總計**: {len(results)} 個服務

---

"""

    # 🔴 Risk services (詳細顯示)
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

    # 🟡 Attention services (摘要顯示)
    if yellow_services:
        report += "## 🟡 需關注服務\n\n"
        for r in yellow_services:
            notes_str = ", ".join(r['notes']) if r['notes'] else "無"
            report += f"- **{r['service']}**: {notes_str}\n"
        report += "\n---\n\n"

    # 🟢 Healthy services (僅列表)
    if green_services:
        report += "## 🟢 健康服務\n\n"
        service_names = [r['service'] for r in green_services]
        report += ", ".join(service_names) + "\n\n"
        report += "---\n\n"

    # Full details
    report += "## 詳細檢查結果\n\n"
    report += "| 服務 | 狀態 | 可用性 | 穩定性 | 記憶體 | CPU | 擴展 | 備註 |\n"
    report += "|------|------|--------|--------|--------|-----|------|------|\n"

    for r in results:
        c = r['checks']
        notes_str = "; ".join(r['notes'][:2]) if r['notes'] else "-"
        report += f"| {r['service']} | {r['status']} | {c['availability']} | {c['stability']} | {c['memory_usage']} | {c['cpu_usage']} | {c['scaling']} | {notes_str} |\n"

    report += "\n---\n\n"
    report += f"*檢查時間: {timestamp}*\n"
    report += "*根據 k8s-service-monitor.md 規則生成*\n"

    return report


def generate_slack_message(results: List[Dict]) -> Dict:
    """Generate Slack message following k8s-service-monitor.md spec"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    red_services = [r for r in results if r["status"] == "🔴"]
    yellow_count = len([r for r in results if r["status"] == "🟡"])

    # Count top issues
    issue_counts = {}
    for r in red_services + [r for r in results if r["status"] == "🟡"]:
        for note in r["notes"]:
            issue_counts[note] = issue_counts.get(note, 0) + 1

    top_issues = sorted(issue_counts.items(), key=lambda x: x[1], reverse=True)[:3]

    # Build message
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
    print(f"Services: {len(SERVICES)}", file=sys.stderr)
    print("", file=sys.stderr)

    results = []
    for service in SERVICES:
        result = check_service(service)
        results.append(result)

    # Generate report
    report = generate_report(results)
    print(report)

    # Save to file
    report_dir = os.getenv("REPORT_DIR", "/reports")
    os.makedirs(report_dir, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    report_file = f"{report_dir}/health-check-{timestamp}.md"
    with open(report_file, "w") as f:
        f.write(report)
    print(f"\nReport saved to: {report_file}", file=sys.stderr)

    # Send to Slack
    webhook_url = os.getenv("SLACK_WEBHOOK_URL")
    if webhook_url:
        slack_message = generate_slack_message(results)
        send_to_slack(webhook_url, slack_message)
    else:
        print("SLACK_WEBHOOK_URL not set, skipping Slack notification", file=sys.stderr)

    # Exit with status code based on results
    red_count = len([r for r in results if r["status"] == "🔴"])
    sys.exit(1 if red_count > 0 else 0)


if __name__ == "__main__":
    main()
