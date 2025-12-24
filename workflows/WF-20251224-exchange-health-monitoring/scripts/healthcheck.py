#!/usr/bin/env python3
"""
Exchange Service Health Check - Main Entry Point

Orchestrates data collection, analysis, reporting, and notification.
"""

import os
import sys
import logging
from datetime import datetime, timedelta
from pathlib import Path

# Add script directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from config_loader import get_config
from prometheus_client import PrometheusClient
from k8s_client import K8sClient
from analyzer import HealthAnalyzer
from reporter import Reporter
from slack_notifier import SlackNotifier

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    """Main health check workflow"""
    logger.info("=== Exchange Service Health Check Started ===")

    try:
        # 1. Load configuration
        logger.info("Loading configuration...")
        config = get_config()
        service_config = config.get_service_config()

        # 2. Initialize clients
        logger.info("Initializing clients...")
        prom = PrometheusClient(config.get_env('prometheus_url'), config.get_env('query_timeout'))
        k8s = K8sClient(in_cluster=True)

        # Check connectivity
        if not prom.check_connection():
            logger.error("Failed to connect to Prometheus")
            sys.exit(1)

        # 3. Collect data
        logger.info("Collecting metrics...")
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=config.get_env('lookback_hours'))

        # Memory metrics
        memory_query = config.get_promql_query('memory', 'usage_over_time')
        memory_series = prom.get_time_series(memory_query, start_time, end_time)

        memory_current = config.get_promql_query('memory', 'current_usage')
        memory_avg = prom.get_scalar_value(config.get_promql_query('memory', 'average_usage')) or 0
        memory_max = prom.get_scalar_value(config.get_promql_query('memory', 'max_usage')) or 0
        memory_p95 = prom.get_scalar_value(config.get_promql_query('memory', 'p95_usage')) or 0

        # CPU metrics
        cpu_avg = prom.get_scalar_value(config.get_promql_query('cpu', 'average_usage')) or 0
        cpu_p95 = prom.get_scalar_value(config.get_promql_query('cpu', 'p95_usage')) or 0

        # K8s resources
        deployment = k8s.get_deployment(service_config['deployment_name'], service_config['namespace'])
        hpa = k8s.get_hpa(service_config['hpa_name'], service_config['namespace'])
        pods = k8s.get_pods(service_config['namespace'], f"app={service_config['service_name']}")
        oom_events = k8s.get_oom_events(service_config['namespace'], service_config['service_name'], since=start_time)

        # Extract resource specs
        container_spec = deployment['containers'].get(service_config['container_name'], {}) if deployment else {}
        resources = container_spec.get('resources', {})
        memory_request = resources.get('requests', {}).get('memory', 0)
        memory_limit = resources.get('limits', {}).get('memory', 0)
        cpu_request = resources.get('requests', {}).get('cpu', 0)
        cpu_limit = resources.get('limits', {}).get('cpu', 0)

        # 4. Analyze data
        logger.info("Analyzing metrics...")
        analyzer = HealthAnalyzer(config.get_all_thresholds())

        # Memory trend analysis
        memory_trend = analyzer.analyze_memory_trend(memory_series)

        # Resource allocation analysis
        memory_allocation = analyzer.analyze_resource_allocation(
            memory_avg, memory_p95, memory_request, memory_limit, 'memory'
        )
        cpu_allocation = analyzer.analyze_resource_allocation(
            cpu_avg, cpu_p95, cpu_request, cpu_limit, 'cpu'
        )

        # HPA behavior
        total_restarts = sum(pod['restart_count'] for pod in pods)
        hpa_analysis = analyzer.analyze_hpa_behavior(
            hpa['current_replicas'] if hpa else 0,
            hpa['min_replicas'] if hpa else 0,
            hpa['max_replicas'] if hpa else 0,
            cpu_avg / max(len(pods), 1),
            (memory_avg / (1024**2)) / max(len(pods), 1),
            hpa['metrics'] if hpa else []
        )

        # Events analysis
        events_analysis = analyzer.analyze_events(oom_events, total_restarts)

        # Collect all issues
        all_issues = []
        all_issues.extend(memory_allocation.get('issues', []))
        all_issues.extend(cpu_allocation.get('issues', []))
        all_issues.extend(hpa_analysis.get('issues', []))
        all_issues.extend(events_analysis.get('issues', []))

        # Calculate overall status
        overall_status = analyzer.calculate_overall_status(all_issues)

        # 5. Generate report
        logger.info("Generating report...")
        report_data = {
            'metadata': {
                'generated_at': datetime.now().isoformat(),
                'service': service_config['service_name'],
                'namespace': service_config['namespace'],
                'lookback_hours': config.get_env('lookback_hours'),
            },
            'summary': {
                'overall_status': overall_status,
                'issue_count': len(all_issues),
                'critical_count': sum(1 for i in all_issues if i['severity'] == 'CRITICAL'),
                'warning_count': sum(1 for i in all_issues if i['severity'] in ['WARNING', 'HIGH', 'MEDIUM']),
            },
            'metrics': {
                'memory': {
                    'avg_mi': memory_avg / (1024**2),
                    'max_mi': memory_max / (1024**2),
                    'p95_mi': memory_p95 / (1024**2),
                    'limit_mi': memory_limit / (1024**2),
                    'usage_pct': (memory_avg / memory_limit * 100) if memory_limit > 0 else 0,
                    'slope_mb_per_hour': memory_trend.get('slope_mb_per_hour', 0),
                },
                'cpu': {
                    'avg_cores': cpu_avg,
                    'p95_cores': cpu_p95,
                },
                'hpa': hpa or {},
            },
            'analysis': {
                'memory_trend': memory_trend,
                'resource_allocation': {
                    'memory': {
                        'request_mi': memory_request / (1024**2),
                        'limit_mi': memory_limit / (1024**2),
                        **memory_allocation
                    },
                    'cpu': {
                        'request_cores': cpu_request,
                        'limit_cores': cpu_limit,
                        **cpu_allocation
                    },
                },
                'hpa': hpa_analysis,
                'events': events_analysis,
            },
            'issues': all_issues,
        }

        reporter = Reporter(use_emoji=True)
        markdown_report = reporter.generate_markdown(report_data)
        json_report = reporter.generate_json(report_data)

        # 6. Save reports
        logger.info("Saving reports...")
        report_dir = Path(config.get_env('report_dir'))
        report_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        markdown_file = report_dir / f"health-check-{timestamp}.md"
        json_file = report_dir / f"health-check-{timestamp}.json"

        markdown_file.write_text(markdown_report)
        json_file.write_text(json_report)

        logger.info(f"Reports saved: {markdown_file}, {json_file}")

        # 7. Send notification
        logger.info("Sending Slack notification...")
        notifier = SlackNotifier(
            bot_token=config.get_env('slack_bot_token'),
            webhook_url=config.get_env('slack_webhook_url')
        )

        if notifier.send_report(markdown_report, config.get_env('slack_channel')):
            logger.info("Slack notification sent successfully")
        else:
            logger.warning("Failed to send Slack notification")

        # 8. Done
        logger.info(f"=== Health Check Completed: {overall_status} ===")
        sys.exit(0 if overall_status != 'CRITICAL' else 1)

    except Exception as e:
        logger.error(f"Health check failed: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
