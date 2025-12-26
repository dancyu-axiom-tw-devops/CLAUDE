#!/usr/bin/env python3
"""
PIGO pigo-rel Namespace Memory Inspection Script

Performs 4-item memory checks:
1. Current memory usage vs Limit
2. Memory trend analysis (24h growth rate)
3. Request vs Limit configuration sanity
4. Memory usage ranking (Top 5)

Generates Markdown inspection report.
"""

import subprocess
import sys
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple

from prometheus_client import PrometheusClient
from report_generator import ReportGenerator


# Configuration
NAMESPACE = "pigo-rel"
KUBE_CONTEXT = "tp-hkidc-k8s"
PROMETHEUS_URL = "http://monitoring-prometheus.monitoring.svc.cluster.local:9090"
TIME_WINDOW_HOURS = 24

# Thresholds
USAGE_THRESHOLD_ATTENTION = 70.0  # 70%
USAGE_THRESHOLD_RISK = 85.0       # 85%
GROWTH_THRESHOLD_ATTENTION = 10.0  # 10%
GROWTH_THRESHOLD_RISK = 20.0       # 20%


class MemoryInspector:
    """Main memory inspection class"""

    def __init__(self):
        self.namespace = NAMESPACE
        self.context = KUBE_CONTEXT
        self.prom_client = PrometheusClient(PROMETHEUS_URL, NAMESPACE, KUBE_CONTEXT)
        self.report_gen = ReportGenerator(NAMESPACE)

    def run_kubectl(self, args: List[str]) -> str:
        """Execute kubectl command and return output"""
        cmd = ["kubectl"] + args + ["--context", self.context]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise Exception(f"kubectl failed: {result.stderr}")
        return result.stdout.strip()

    def discover_deployments(self) -> List[str]:
        """Discover all deployments in the namespace"""
        output = self.run_kubectl([
            "get", "deployments",
            "-n", self.namespace,
            "-o", "jsonpath={.items[*].metadata.name}"
        ])

        if not output:
            return []

        deployments = output.split()
        print(f"發現 {len(deployments)} 個 deployment: {', '.join(deployments)}")
        return deployments

    def get_deployment_pods(self, deployment: str) -> List[str]:
        """Get pod names for a deployment"""
        output = self.run_kubectl([
            "get", "pods",
            "-n", self.namespace,
            "-l", f"app={deployment}",
            "-o", "jsonpath={.items[*].metadata.name}"
        ])

        if not output:
            return []

        return output.split()

    def analyze_memory_usage(self, usage_bytes: float, limit_bytes: float) -> Tuple[str, str]:
        """
        Analyze memory usage rate

        Returns:
            (status_emoji, message)
        """
        if limit_bytes == 0:
            return ('⚪', '無 limit 配置')

        usage_pct = (usage_bytes / limit_bytes) * 100

        if usage_pct >= USAGE_THRESHOLD_RISK:
            return ('🔴', f'使用率 {usage_pct:.1f}% >= {USAGE_THRESHOLD_RISK}%')
        elif usage_pct >= USAGE_THRESHOLD_ATTENTION:
            return ('🟡', f'使用率 {usage_pct:.1f}% >= {USAGE_THRESHOLD_ATTENTION}%')
        else:
            return ('🟢', f'使用率 {usage_pct:.1f}%')

    def analyze_memory_trend(self, values: List[Tuple[int, float]]) -> Tuple[float, str]:
        """
        Analyze 24h memory growth rate using quarter-based comparison

        Args:
            values: List of (timestamp, bytes) tuples

        Returns:
            (growth_pct, status_emoji)
        """
        if not values or len(values) < 4:
            return (0.0, '⚪')

        # Sort by timestamp
        values = sorted(values, key=lambda x: x[0])

        quarter = len(values) // 4
        first_quarter = values[:quarter]
        last_quarter = values[-quarter:]

        first_avg = sum(v[1] for v in first_quarter) / len(first_quarter)
        last_avg = sum(v[1] for v in last_quarter) / len(last_quarter)

        if first_avg == 0:
            return (0.0, '⚪')

        growth_pct = ((last_avg - first_avg) / first_avg) * 100

        if growth_pct >= GROWTH_THRESHOLD_RISK:
            return (growth_pct, '🔴')  # Possible leak
        elif growth_pct >= GROWTH_THRESHOLD_ATTENTION:
            return (growth_pct, '🟡')
        else:
            return (growth_pct, '🟢')

    def analyze_config_sanity(self, usage_bytes: float, request_bytes: float,
                              limit_bytes: float) -> Tuple[str, str, str]:
        """
        Analyze resource configuration sanity

        Returns:
            (status_emoji, message, suggestion)
        """
        if limit_bytes == 0:
            return ('🔴', '無 limit 配置', '建議設置 memory limit 防止 OOM')

        if request_bytes == 0:
            return ('🟡', '無 request 配置', '建議設置 memory request 確保調度')

        usage_pct = (usage_bytes / limit_bytes) * 100

        # Over limit
        if usage_pct > 100:
            suggested_limit = int(usage_bytes * 1.3 / (1024**2)) * (1024**2)  # Round to Mi
            return ('🔴', '已超過 limit', f'建議增加 limit 至 {self._format_memory(suggested_limit)}')

        # Close to limit
        if usage_pct > 85:
            suggested_limit = int(usage_bytes * 1.3 / (1024**2)) * (1024**2)
            return ('🔴', '接近 limit', f'建議增加 limit 至 {self._format_memory(suggested_limit)}')

        # Request too low
        request_pct = (request_bytes / usage_bytes) * 100 if usage_bytes > 0 else 0
        if request_pct < 50:
            suggested_request = int(usage_bytes * 0.8 / (1024**2)) * (1024**2)
            return ('🟡', 'Request 過低', f'建議增加 request 至 {self._format_memory(suggested_request)}')

        # Over-provisioned
        if usage_pct < 30 and limit_bytes > 2 * 1024**3:  # < 30% and limit > 2GB
            return ('🟡', 'Limit 可能過高', '考慮降低 limit 以節省資源')

        return ('🟢', '配置合理', '')

    def check_deployment_memory(self, deployment: str) -> Dict:
        """
        Perform 4-item memory check for a deployment

        Returns:
            Dict with check results
        """
        print(f"\n檢查 {deployment}...")

        result = {
            'deployment_name': deployment,
            'pod_name': '',
            'usage_bytes': 0,
            'limit_bytes': 0,
            'request_bytes': 0,
            'usage_pct': 0,
            'usage_status': '⚪',
            'usage_message': '',
            'growth_pct': 0,
            'trend_status': '⚪',
            'config_status': '⚪',
            'config_message': '',
            'config_suggestion': '',
            'jvm_heap_used': 0,
            'overall_status': '⚪'
        }

        # Get pods for this deployment
        pods = self.get_deployment_pods(deployment)
        if not pods:
            print(f"  未找到 {deployment} 的 Pod")
            return result

        # Use first pod as representative (or aggregate)
        pod = pods[0]
        result['pod_name'] = pod
        pod_pattern = pod.replace(pod.split('-')[-1], '.*')  # Convert pod-xxx to pod-.*

        # 1. Get current memory usage
        try:
            usage_map = self.prom_client.get_memory_usage(pod_pattern)
            if pod in usage_map:
                result['usage_bytes'] = usage_map[pod]
                print(f"  當前使用: {self._format_memory(result['usage_bytes'])}")
        except Exception as e:
            print(f"  查詢記憶體使用失敗: {e}")

        # 2. Get memory limit
        try:
            limit_map = self.prom_client.get_memory_limits(pod_pattern)
            if pod in limit_map:
                result['limit_bytes'] = limit_map[pod]
                print(f"  記憶體限制: {self._format_memory(result['limit_bytes'])}")
        except Exception as e:
            print(f"  查詢記憶體限制失敗: {e}")

        # 3. Get memory request
        try:
            request_map = self.prom_client.get_memory_requests(pod_pattern)
            if pod in request_map:
                result['request_bytes'] = request_map[pod]
                print(f"  記憶體請求: {self._format_memory(result['request_bytes'])}")
        except Exception as e:
            print(f"  查詢記憶體請求失敗: {e}")

        # Calculate usage percentage
        if result['limit_bytes'] > 0:
            result['usage_pct'] = (result['usage_bytes'] / result['limit_bytes']) * 100

        # 4. Analyze usage rate
        status, message = self.analyze_memory_usage(result['usage_bytes'], result['limit_bytes'])
        result['usage_status'] = status
        result['usage_message'] = message
        print(f"  使用率分析: {status} {message}")

        # 5. Get memory trend (24h)
        try:
            trend_map = self.prom_client.get_memory_trend(pod_pattern, TIME_WINDOW_HOURS)
            if pod in trend_map:
                values = trend_map[pod]
                growth, trend_status = self.analyze_memory_trend(values)
                result['growth_pct'] = growth
                result['trend_status'] = trend_status
                print(f"  趨勢分析 (24h): {trend_status} 成長 {growth:+.1f}%")
        except Exception as e:
            print(f"  查詢記憶體趨勢失敗: {e}")

        # 6. Analyze config sanity
        config_status, config_msg, suggestion = self.analyze_config_sanity(
            result['usage_bytes'], result['request_bytes'], result['limit_bytes']
        )
        result['config_status'] = config_status
        result['config_message'] = config_msg
        result['config_suggestion'] = suggestion
        print(f"  配置分析: {config_status} {config_msg}")

        # 7. Get JVM metrics (if available)
        try:
            jvm_map = self.prom_client.get_jvm_heap_usage(pod_pattern)
            if pod in jvm_map and 'heap_used' in jvm_map[pod]:
                result['jvm_heap_used'] = jvm_map[pod]['heap_used']
                print(f"  JVM Heap: {self._format_memory(result['jvm_heap_used'])}")
        except Exception:
            pass  # JVM metrics optional

        # 8. Determine overall status
        statuses = [result['usage_status'], result['trend_status'], result['config_status']]
        if '🔴' in statuses:
            result['overall_status'] = '🔴'
        elif '🟡' in statuses:
            result['overall_status'] = '🟡'
        else:
            result['overall_status'] = '🟢'

        return result

    def run_inspection(self) -> List[Dict]:
        """Run memory inspection for all deployments"""
        print(f"開始巡視 {self.namespace} namespace...")
        print(f"Prometheus: {PROMETHEUS_URL}")
        print(f"時間範圍: 過去 {TIME_WINDOW_HOURS} 小時")
        print("=" * 80)

        deployments = self.discover_deployments()

        if not deployments:
            print("未發現任何 deployment")
            return []

        results = []
        for deployment in deployments:
            result = self.check_deployment_memory(deployment)
            results.append(result)

        print("\n" + "=" * 80)
        print(f"巡視完成，共檢查 {len(results)} 個 deployment")

        return results

    def generate_report(self, results: List[Dict], output_file: str):
        """Generate and save Markdown report"""
        print(f"\n生成報告: {output_file}")

        report_content = self.report_gen.generate_full_report(results, PROMETHEUS_URL)

        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(report_content)

        print(f"✅ 報告已保存: {output_file}")

    def _format_memory(self, bytes_value: float) -> str:
        """Format bytes to human-readable memory string"""
        if bytes_value == 0:
            return "0"

        units = ['B', 'Ki', 'Mi', 'Gi', 'Ti']
        unit_idx = 0
        value = bytes_value

        while value >= 1024 and unit_idx < len(units) - 1:
            value /= 1024
            unit_idx += 1

        if unit_idx == 0:
            return f"{int(value)} {units[unit_idx]}"
        else:
            return f"{value:.0f} {units[unit_idx]}"


def main():
    """Main entry point"""
    print("PIGO Memory Inspection Script v1.0")
    print("=" * 80)

    inspector = MemoryInspector()

    try:
        # Run inspection
        results = inspector.run_inspection()

        if not results:
            print("沒有檢查結果，退出")
            sys.exit(1)

        # Generate report
        timestamp = datetime.now().strftime("%Y%m%d")
        output_file = f"/Users/user/CLAUDE/workflows/WF-20251226-pigo-memory-inspection/data/pigo-rel-memory-inspection-{timestamp}.md"

        inspector.generate_report(results, output_file)

        # Summary
        risk_count = sum(1 for r in results if r['overall_status'] == '🔴')
        attention_count = sum(1 for r in results if r['overall_status'] == '🟡')
        healthy_count = sum(1 for r in results if r['overall_status'] == '🟢')

        print("\n" + "=" * 80)
        print("巡視結果摘要:")
        print(f"  🔴 高風險: {risk_count}")
        print(f"  🟡 需關注: {attention_count}")
        print(f"  🟢 健康: {healthy_count}")
        print("=" * 80)

        sys.exit(0)

    except Exception as e:
        print(f"\n錯誤: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
