#!/usr/bin/env python3
"""
Report Generator for Exchange Service Health Check

Generates Markdown and JSON reports from analysis results.
"""

import json
import logging
from typing import Dict, List, Any
from datetime import datetime

logger = logging.getLogger(__name__)


class Reporter:
    """Generates health check reports"""

    def __init__(self, use_emoji: bool = True):
        """Initialize reporter"""
        self.use_emoji = use_emoji
        self.status_indicators = {
            'HEALTHY': '🟢' if use_emoji else '[OK]',
            'WARNING': '🟡' if use_emoji else '[WARN]',
            'CRITICAL': '🔴' if use_emoji else '[CRIT]',
        }

    def generate_markdown(self, data: Dict[str, Any]) -> str:
        """Generate Markdown report"""
        status = data.get('summary', {}).get('overall_status', 'UNKNOWN')
        indicator = self.status_indicators.get(status, '⚪')

        md = [
            f"# {indicator} Exchange Service Health Check Report",
            "",
            f"**Check Time**: {data.get('metadata', {}).get('generated_at', 'N/A')}",
            f"**Check Period**: Past {data.get('metadata', {}).get('lookback_hours', 24)} hours",
            f"**Overall Status**: {status}",
            "",
            "---",
            "",
            "## 📊 Metrics Summary",
            "",
        ]

        # Memory summary
        memory = data.get('metrics', {}).get('memory', {})
        md.extend([
            "### Memory Usage",
            "",
            "| Metric | Value | Status |",
            "|--------|-------|--------|",
            f"| Average | {memory.get('avg_mi', 0):.0f} Mi | {self._get_status_indicator(memory.get('avg_status', 'HEALTHY'))} |",
            f"| Peak (Max) | {memory.get('max_mi', 0):.0f} Mi | {self._get_status_indicator(memory.get('max_status', 'HEALTHY'))} |",
            f"| P95 | {memory.get('p95_mi', 0):.0f} Mi | {self._get_status_indicator(memory.get('p95_status', 'HEALTHY'))} |",
            f"| vs Limit ({memory.get('limit_mi', 0):.0f} Mi) | {memory.get('usage_pct', 0):.1f}% | {self._get_status_indicator(memory.get('usage_status', 'HEALTHY'))} |",
            f"| Trend | {memory.get('slope_mb_per_hour', 0):+.1f} MB/h | {self._trend_indicator(memory.get('slope_mb_per_hour', 0))} |",
            "",
        ])

        # Resource allocation
        resources = data.get('analysis', {}).get('resource_allocation', {})
        md.extend([
            "### Resource Configuration",
            "",
            "| Resource | Request | Limit | Avg Usage | Usage Rate | Status |",
            "|----------|---------|-------|-----------|------------|--------|",
            f"| Memory | {resources.get('memory', {}).get('request_mi', 0):.0f} Mi | {resources.get('memory', {}).get('limit_mi', 0):.0f} Mi | {memory.get('avg_mi', 0):.0f} Mi | {resources.get('memory', {}).get('avg_vs_request', 0):.1%} | {self._get_status_indicator(resources.get('memory', {}).get('status', 'HEALTHY'))} |",
            f"| CPU | {resources.get('cpu', {}).get('request_cores', 0):.2f} | {resources.get('cpu', {}).get('limit_cores', 0):.2f} | {data.get('metrics', {}).get('cpu', {}).get('avg_cores', 0):.2f} | {resources.get('cpu', {}).get('avg_vs_request', 0):.1%} | {self._get_status_indicator(resources.get('cpu', {}).get('status', 'HEALTHY'))} |",
            "",
        ])

        # HPA status
        hpa = data.get('metrics', {}).get('hpa', {})
        md.extend([
            "### HPA Status",
            "",
            f"- Current Replicas: **{hpa.get('current_replicas', 0)}**",
            f"- Min/Max: {hpa.get('min_replicas', 0)} / {hpa.get('max_replicas', 0)}",
            f"- Target Metrics: {', '.join(hpa.get('metrics', []))}",
            "",
        ])

        # Events
        events = data.get('analysis', {}).get('events', {})
        md.extend([
            "### Anomaly Events",
            "",
            f"- OOMKilled: **{events.get('oom_events', 0)}** times",
            f"- Pod Restarts: **{events.get('restart_count', 0)}** times",
            "",
        ])

        # Issues
        issues = data.get('issues', [])
        if issues:
            md.extend([
                "---",
                "",
                "## 🚨 Issues & Risks",
                "",
            ])

            # Group by severity
            by_severity = {}
            for issue in issues:
                severity = issue.get('severity', 'INFO')
                by_severity.setdefault(severity, []).append(issue)

            for severity in ['CRITICAL', 'HIGH', 'WARNING', 'MEDIUM', 'LOW', 'INFO']:
                if severity in by_severity:
                    for issue in by_severity[severity]:
                        md.extend([
                            f"### {self._severity_indicator(severity)} {severity} - {issue.get('category', 'UNKNOWN')}",
                            "",
                            f"**Issue**: {issue.get('message', 'N/A')}",
                            "",
                            f"**Suggestion**: {issue.get('suggestion', 'N/A')}",
                            "",
                        ])
        else:
            md.extend([
                "---",
                "",
                "## ✅ No Issues Detected",
                "",
                "All metrics are within healthy ranges.",
                "",
            ])

        # Footer
        md.extend([
            "---",
            "",
            "*Report generated by exchange-service-health-check*",
            f"*Next check: Tomorrow at 09:00 UTC+8*",
            "",
        ])

        return "\n".join(md)

    def generate_json(self, data: Dict[str, Any]) -> str:
        """Generate JSON report"""
        return json.dumps(data, indent=2, default=str)

    def _get_status_indicator(self, status: str) -> str:
        """Get status indicator emoji/text"""
        return self.status_indicators.get(status, '⚪')

    def _severity_indicator(self, severity: str) -> str:
        """Get severity indicator"""
        indicators = {
            'CRITICAL': '🔴',
            'HIGH': '🟠',
            'WARNING': '🟡',
            'MEDIUM': '🟡',
            'LOW': '🟢',
            'INFO': 'ℹ️',
        }
        return indicators.get(severity, '⚪') if self.use_emoji else severity

    def _trend_indicator(self, slope: float) -> str:
        """Get trend indicator"""
        if slope > 5:
            return '📈 Increasing' if self.use_emoji else 'UP'
        elif slope < -5:
            return '📉 Decreasing' if self.use_emoji else 'DOWN'
        else:
            return '➡️ Stable' if self.use_emoji else 'STABLE'


if __name__ == '__main__':
    # Test reporter
    sample_data = {
        'metadata': {
            'generated_at': datetime.now().isoformat(),
            'lookback_hours': 24,
        },
        'summary': {
            'overall_status': 'WARNING',
        },
        'metrics': {
            'memory': {
                'avg_mi': 3500,
                'max_mi': 4200,
                'p95_mi': 4000,
                'limit_mi': 6144,
                'usage_pct': 58.3,
                'slope_mb_per_hour': 2.5,
                'avg_status': 'HEALTHY',
                'max_status': 'HEALTHY',
                'p95_status': 'HEALTHY',
                'usage_status': 'HEALTHY',
            },
            'hpa': {
                'current_replicas': 3,
                'min_replicas': 2,
                'max_replicas': 10,
                'metrics': ['CPU: 70%', 'Memory: 75%'],
            },
        },
        'analysis': {
            'resource_allocation': {
                'memory': {
                    'request_mi': 4096,
                    'limit_mi': 6144,
                    'avg_vs_request': 0.854,
                    'status': 'WARNING',
                },
                'cpu': {
                    'request_cores': 1.0,
                    'limit_cores': 4.0,
                    'avg_vs_request': 0.3,
                    'status': 'HEALTHY',
                },
            },
            'events': {
                'oom_events': 0,
                'restart_count': 1,
            },
        },
        'issues': [
            {
                'severity': 'MEDIUM',
                'category': 'RESOURCE_ALLOCATION',
                'message': 'Memory usage 85.4% close to HPA threshold',
                'suggestion': 'Monitor for 3 days or adjust HPA threshold to 85%',
            }
        ],
    }

    reporter = Reporter()

    print("=== Markdown Report ===")
    print(reporter.generate_markdown(sample_data))

    print("\n=== JSON Report (truncated) ===")
    print(reporter.generate_json(sample_data)[:500] + "...")
