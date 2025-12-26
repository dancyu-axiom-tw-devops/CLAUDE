#!/usr/bin/env python3
"""
Report Generator Module
Generates Markdown memory inspection reports
"""

from datetime import datetime
from typing import Dict, List, Tuple


class ReportGenerator:
    """Generates Markdown formatted memory inspection reports"""

    def __init__(self, namespace: str):
        self.namespace = namespace
        self.timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    def generate_summary(self, results: List[Dict]) -> str:
        """Generate overall summary section"""
        total = len(results)
        healthy = sum(1 for r in results if r['overall_status'] == '🟢')
        attention = sum(1 for r in results if r['overall_status'] == '🟡')
        risk = sum(1 for r in results if r['overall_status'] == '🔴')
        leak_risk = sum(1 for r in results if r['trend_status'] == '🔴')

        # Determine overall status
        if risk > 0:
            overall = '🔴 高風險'
        elif attention > 0:
            overall = '🟡 需要關注'
        else:
            overall = '🟢 健康'

        summary = f"""## 📊 整體摘要

| 項目 | 數值 |
|------|------|
| 總 Pod 數 | {total} |
| 健康 Pod (< 70%) | {healthy} |
| 需關注 Pod (70-85%) | {attention} |
| 高風險 Pod (> 85%) | {risk} |
| 記憶體洩漏風險 (成長 > 20%) | {leak_risk} |

**整體狀態**: {overall}

---
"""
        return summary

    def generate_ranking(self, results: List[Dict]) -> str:
        """Generate memory usage ranking tables"""

        # Sort by absolute usage
        by_usage = sorted(results, key=lambda x: x.get('usage_bytes', 0), reverse=True)[:5]

        # Sort by usage percentage
        by_percentage = sorted(results, key=lambda x: x.get('usage_pct', 0), reverse=True)[:5]

        ranking = """## 🏆 記憶體使用排行榜

### Top 5 絕對使用量

| 排名 | Pod 名稱 | 當前使用 | 限制 | 使用率 | 狀態 |
|------|---------|---------|------|--------|------|
"""

        for i, result in enumerate(by_usage, 1):
            pod = result['pod_name']
            usage = self._format_memory(result.get('usage_bytes', 0))
            limit = self._format_memory(result.get('limit_bytes', 0))
            pct = result.get('usage_pct', 0)
            status = result.get('usage_status', '⚪')

            ranking += f"| {i} | {pod} | {usage} | {limit} | {pct:.1f}% | {status} |\n"

        ranking += "\n### Top 5 使用率\n\n"
        ranking += "| 排名 | Pod 名稱 | 使用率 | 當前使用 | 限制 | 狀態 |\n"
        ranking += "|------|---------|--------|---------|------|------|\n"

        for i, result in enumerate(by_percentage, 1):
            pod = result['pod_name']
            pct = result.get('usage_pct', 0)
            usage = self._format_memory(result.get('usage_bytes', 0))
            limit = self._format_memory(result.get('limit_bytes', 0))
            status = result.get('usage_status', '⚪')

            ranking += f"| {i} | {pod} | {pct:.1f}% | {usage} | {limit} | {status} |\n"

        ranking += "\n---\n\n"
        return ranking

    def generate_pod_detail(self, result: Dict) -> str:
        """Generate detailed check results for a single pod"""
        pod = result['pod_name']
        overall_status = result.get('overall_status', '⚪')

        detail = f"### {overall_status} {pod}\n\n"

        # 1. Current memory usage
        detail += "#### 1️⃣ 當前記憶體使用率\n"
        detail += "| 項目 | 數值 |\n"
        detail += "|------|------|\n"
        detail += f"| 當前使用 | {self._format_memory(result.get('usage_bytes', 0))} |\n"
        detail += f"| 限制 (Limit) | {self._format_memory(result.get('limit_bytes', 0))} |\n"
        detail += f"| 請求 (Request) | {self._format_memory(result.get('request_bytes', 0))} |\n"
        detail += f"| **使用率** | **{result.get('usage_pct', 0):.1f}%** {result.get('usage_status', '⚪')} |\n\n"

        usage_status = result.get('usage_status', '⚪')
        if usage_status == '🔴':
            detail += "**狀態**: 🔴 記憶體使用率極高，OOM 風險\n\n"
        elif usage_status == '🟡':
            detail += "**狀態**: 🟡 記憶體使用率偏高，需要關注\n\n"
        else:
            detail += "**狀態**: 🟢 記憶體使用率正常\n\n"

        # 2. Memory trend
        detail += "#### 2️⃣ 記憶體趨勢分析 (過去 24h)\n"
        growth = result.get('growth_pct', 0)
        trend_status = result.get('trend_status', '⚪')

        detail += f"**成長率**: {growth:+.1f}% {trend_status}\n"

        if trend_status == '🔴':
            detail += "**狀態**: 🔴 記憶體成長過快，可能存在記憶體洩漏\n\n"
        elif trend_status == '🟡':
            detail += "**狀態**: 🟡 記憶體持續成長，建議監控\n\n"
        else:
            detail += "**狀態**: 🟢 記憶體穩定或正常成長\n\n"

        # 3. Config sanity
        detail += "#### 3️⃣ Request vs Limit 配置合理性\n"
        config_status = result.get('config_status', '⚪')
        config_msg = result.get('config_message', '')

        detail += f"**狀態**: {config_status} {config_msg}\n\n"

        if result.get('config_suggestion'):
            detail += f"**建議**: {result['config_suggestion']}\n\n"

        # 4. JVM memory (if available)
        detail += "#### 4️⃣ JVM 記憶體分析\n"
        if result.get('jvm_heap_used'):
            heap_used = self._format_memory(result['jvm_heap_used'])
            detail += f"**Heap Used**: {heap_used}\n"
            detail += "**狀態**: ✅ JVM metrics 可用\n\n"
        else:
            detail += "**狀態**: ⚪ JVM metrics 未採集\n\n"

        detail += "---\n\n"
        return detail

    def generate_problem_summary(self, results: List[Dict]) -> str:
        """Generate summary table of problematic pods"""
        problem_pods = [r for r in results if r.get('overall_status') in ['🔴', '🟡']]

        if not problem_pods:
            return "## ✅ 所有 Pod 記憶體狀態健康\n\n---\n\n"

        summary = """## 🚨 問題 Pod 匯總表

| Pod 名稱 | 當前使用率 | 24h 成長率 | 配置問題 | 建議處理 |
|---------|-----------|-----------|---------|---------|
"""

        for result in problem_pods:
            pod = result['pod_name']
            usage_status = result.get('usage_status', '⚪')
            usage_pct = result.get('usage_pct', 0)
            trend_status = result.get('trend_status', '⚪')
            growth = result.get('growth_pct', 0)
            config_status = result.get('config_status', '⚪')
            config_msg = result.get('config_message', '')

            suggestion = result.get('config_suggestion', '-')

            summary += f"| {pod} | {usage_status} {usage_pct:.1f}% | {trend_status} {growth:+.1f}% | {config_status} {config_msg} | {suggestion} |\n"

        summary += "\n---\n\n"
        return summary

    def generate_recommendations(self, results: List[Dict]) -> str:
        """Generate conclusions and recommendations"""
        risk_pods = [r for r in results if r.get('overall_status') == '🔴']
        attention_pods = [r for r in results if r.get('overall_status') == '🟡']
        leak_pods = [r for r in results if r.get('trend_status') == '🔴']

        # Overall assessment
        if risk_pods:
            overall = '🔴 需要緊急處理'
        elif attention_pods:
            overall = '🟡 需要關注'
        else:
            overall = '🟢 健康'

        recommendations = f"""## 💡 結論與建議

### 整體健康評估
**總體狀態**: {overall}

"""

        # Urgent actions
        if risk_pods:
            recommendations += "### 🔴 緊急 (24h 內)\n\n"
            for result in risk_pods:
                pod = result['pod_name']
                usage_pct = result.get('usage_pct', 0)
                usage = self._format_memory(result.get('usage_bytes', 0))
                limit = self._format_memory(result.get('limit_bytes', 0))

                recommendations += f"**{pod} 記憶體配置調整**\n"
                recommendations += f"- 現況: 使用 {usage} / 限制 {limit} ({usage_pct:.1f}%)\n"
                recommendations += f"- 風險: {'已超限' if usage_pct > 100 else '接近限制'}，{'隨時' if usage_pct > 100 else '可能'}發生 OOMKilled\n"

                if result.get('config_suggestion'):
                    recommendations += f"- 建議: {result['config_suggestion']}\n"

                recommendations += "\n"

        # Attention items
        if attention_pods:
            recommendations += "### 🟡 需要關注 (7天內)\n\n"
            for result in attention_pods:
                pod = result['pod_name']
                recommendations += f"**{pod}**\n"
                recommendations += f"- 使用率: {result.get('usage_pct', 0):.1f}%\n"
                recommendations += f"- 24h成長: {result.get('growth_pct', 0):+.1f}%\n"

                if result.get('config_suggestion'):
                    recommendations += f"- 建議: {result['config_suggestion']}\n"

                recommendations += "\n"

        # Memory leak warnings
        if leak_pods:
            recommendations += "### ⚠️ 記憶體洩漏風險\n\n"
            recommendations += "以下 Pod 過去 24h 記憶體成長超過 20%，建議深入調查：\n\n"
            for result in leak_pods:
                pod = result['pod_name']
                growth = result.get('growth_pct', 0)
                recommendations += f"- **{pod}**: 成長 {growth:+.1f}%\n"

            recommendations += "\n"

        recommendations += "---\n\n"
        return recommendations

    def generate_full_report(self, results: List[Dict], prometheus_url: str) -> str:
        """Generate complete Markdown report"""
        report = f"""# PIGO {self.namespace} Namespace Pod 記憶體巡視報告

**巡視時間**: {self.timestamp}
**巡視範圍**: {self.namespace} namespace (過去 24h)
**Prometheus**: {prometheus_url}

---

"""
        report += self.generate_summary(results)
        report += self.generate_ranking(results)
        report += "## 🔍 逐一檢查詳情\n\n"

        # Sort by overall status (red first, then yellow, then green)
        status_order = {'🔴': 0, '🟡': 1, '🟢': 2, '⚪': 3}
        sorted_results = sorted(results, key=lambda x: status_order.get(x.get('overall_status', '⚪'), 3))

        for result in sorted_results:
            report += self.generate_pod_detail(result)

        report += self.generate_problem_summary(results)
        report += self.generate_recommendations(results)

        report += f"""---

**報告生成時間**: {self.timestamp}
**巡視工具**: PIGO Memory Inspection Script v1.0
"""

        return report

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
