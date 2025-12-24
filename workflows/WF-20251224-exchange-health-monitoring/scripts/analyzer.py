#!/usr/bin/env python3
"""
Data Analyzer for Exchange Service Health Check

Analyzes metrics to detect issues and provide recommendations.
"""

import logging
import numpy as np
from scipy import stats
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime

logger = logging.getLogger(__name__)


class HealthAnalyzer:
    """Analyzes service health metrics"""

    def __init__(self, thresholds: Dict[str, Any]):
        """
        Initialize analyzer with threshold configuration

        Args:
            thresholds: Threshold configuration dict
        """
        self.thresholds = thresholds

    def analyze_memory_trend(
        self,
        time_series: Dict[str, List[Tuple[datetime, float]]]
    ) -> Dict[str, Any]:
        """
        Analyze memory trend for leak detection using linear regression

        Args:
            time_series: Dict mapping pod name to list of (timestamp, memory_bytes) tuples

        Returns:
            Analysis result with leak detection
        """
        if not time_series:
            return {'leak_detected': False, 'slope_mb_per_hour': 0, 'r_squared': 0}

        # Aggregate data across all pods
        all_points = []
        for pod_name, series in time_series.items():
            all_points.extend(series)

        if len(all_points) < 10:
            logger.warning("Insufficient data points for trend analysis")
            return {'leak_detected': False, 'slope_mb_per_hour': 0, 'r_squared': 0}

        # Sort by timestamp
        all_points.sort(key=lambda x: x[0])

        # Convert to arrays for regression
        timestamps = np.array([(dt - all_points[0][0]).total_seconds() / 3600.0 for dt, _ in all_points])
        memory_mb = np.array([value / (1024 ** 2) for _, value in all_points])

        # Perform linear regression
        slope, intercept, r_value, p_value, std_err = stats.linregress(timestamps, memory_mb)

        r_squared = r_value ** 2

        # Check leak conditions
        slope_threshold = self.thresholds.get('memory', {}).get('leak_slope_threshold', 10)
        r_squared_threshold = self.thresholds.get('memory', {}).get('leak_r_squared_threshold', 0.7)
        p_value_threshold = self.thresholds.get('memory', {}).get('leak_p_value_threshold', 0.05)

        leak_detected = (
            slope > slope_threshold and
            r_squared > r_squared_threshold and
            p_value < p_value_threshold
        )

        return {
            'leak_detected': leak_detected,
            'slope_mb_per_hour': round(slope, 2),
            'r_squared': round(r_squared, 3),
            'p_value': round(p_value, 4),
            'intercept_mb': round(intercept, 2),
            'std_err': round(std_err, 2),
            'data_points': len(all_points),
        }

    def analyze_resource_allocation(
        self,
        avg_usage: float,
        p95_usage: float,
        request: float,
        limit: float,
        resource_type: str = 'memory'
    ) -> Dict[str, Any]:
        """
        Analyze resource allocation efficiency

        Args:
            avg_usage: Average resource usage
            p95_usage: 95th percentile usage
            request: Resource request value
            limit: Resource limit value
            resource_type: 'memory' or 'cpu'

        Returns:
            Analysis result with recommendations
        """
        issues = []
        recommendations = []

        thresholds = self.thresholds.get(resource_type, {})
        over_provision_ratio = thresholds.get('over_provision_ratio', 0.5)
        under_provision_ratio = thresholds.get('under_provision_ratio', 0.85)
        qos_ratio_warning = thresholds.get('qos_ratio_warning', 2.0)

        # Check over-provisioning (avg usage vs request)
        if request > 0:
            avg_vs_request = avg_usage / request
            if avg_vs_request < over_provision_ratio:
                issues.append({
                    'severity': 'LOW',
                    'category': 'OVER_PROVISION',
                    'message': f'{resource_type.upper()} request over-provisioned: avg usage {avg_vs_request:.1%} of request',
                    'suggestion': f'Consider reducing request to {int(avg_usage / over_provision_ratio)}'
                })

        # Check under-provisioning (p95 usage vs limit)
        if limit > 0:
            p95_vs_limit = p95_usage / limit
            if p95_vs_limit > under_provision_ratio:
                severity = 'CRITICAL' if p95_vs_limit > 0.95 else 'HIGH'
                issues.append({
                    'severity': severity,
                    'category': 'OOM_RISK' if resource_type == 'memory' else 'THROTTLE_RISK',
                    'message': f'{resource_type.upper()} P95 usage {p95_vs_limit:.1%} of limit',
                    'suggestion': f'Consider increasing limit to {int(p95_usage / under_provision_ratio)}'
                })

        # Check request/limit ratio (QoS)
        if request > 0 and limit > 0:
            ratio = limit / request
            if ratio > qos_ratio_warning:
                issues.append({
                    'severity': 'MEDIUM',
                    'category': 'QOS_WARNING',
                    'message': f'{resource_type.upper()} limit/request ratio {ratio:.1f}x (affects QoS class)',
                    'suggestion': 'Consider narrowing the gap for better QoS guarantees'
                })

        return {
            'avg_vs_request': round(avg_usage / request, 3) if request > 0 else 0,
            'p95_vs_limit': round(p95_usage / limit, 3) if limit > 0 else 0,
            'limit_request_ratio': round(limit / request, 2) if request > 0 else 0,
            'issues': issues,
        }

    def analyze_hpa_behavior(
        self,
        current_replicas: int,
        min_replicas: int,
        max_replicas: int,
        avg_cpu_cores: float,
        avg_memory_mb: float,
        hpa_metrics: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Analyze HPA scaling behavior

        Args:
            current_replicas: Current number of replicas
            min_replicas: HPA min replicas
            max_replicas: HPA max replicas
            avg_cpu_cores: Average CPU usage per pod (cores)
            avg_memory_mb: Average memory usage per pod (MB)
            hpa_metrics: HPA metric target configuration

        Returns:
            Analysis result with scaling recommendations
        """
        issues = []

        hpa_thresholds = self.thresholds.get('hpa', {})

        # Check for over-scaling
        over_scaling_min = hpa_thresholds.get('over_scaling_min_replicas', 5)
        over_scaling_cpu = hpa_thresholds.get('over_scaling_cpu_threshold', 0.5)
        over_scaling_memory = hpa_thresholds.get('over_scaling_memory_threshold', 2000)

        if current_replicas >= over_scaling_min:
            if avg_cpu_cores < over_scaling_cpu:
                issues.append({
                    'severity': 'MEDIUM',
                    'category': 'OVER_SCALING',
                    'message': f'{current_replicas} replicas but avg CPU only {avg_cpu_cores:.2f} cores',
                    'suggestion': 'HPA may be over-scaling. Review CPU target or consider reducing min replicas'
                })
            elif avg_memory_mb < over_scaling_memory:
                issues.append({
                    'severity': 'MEDIUM',
                    'category': 'OVER_SCALING',
                    'message': f'{current_replicas} replicas but avg memory only {avg_memory_mb:.0f} MB',
                    'suggestion': 'HPA may be over-scaling. Review memory target'
                })

        # Check for under-scaling
        under_scaling_max = hpa_thresholds.get('under_scaling_max_replicas', 2)
        under_scaling_cpu = hpa_thresholds.get('under_scaling_cpu_threshold', 2.0)
        under_scaling_memory = hpa_thresholds.get('under_scaling_memory_threshold', 5000)

        if current_replicas <= under_scaling_max:
            if avg_cpu_cores > under_scaling_cpu:
                issues.append({
                    'severity': 'HIGH',
                    'category': 'UNDER_SCALING',
                    'message': f'Only {current_replicas} replicas but avg CPU {avg_cpu_cores:.2f} cores',
                    'suggestion': 'HPA may be under-scaling. Review CPU target or increase max replicas'
                })
            elif avg_memory_mb > under_scaling_memory:
                issues.append({
                    'severity': 'HIGH',
                    'category': 'UNDER_SCALING',
                    'message': f'Only {current_replicas} replicas but avg memory {avg_memory_mb:.0f} MB',
                    'suggestion': 'HPA may be under-scaling. Review memory target'
                })

        # Check if at min/max bounds
        if current_replicas == min_replicas and current_replicas > 1:
            issues.append({
                'severity': 'INFO',
                'category': 'HPA_AT_MIN',
                'message': f'HPA at minimum replicas ({min_replicas})',
                'suggestion': 'Consider if min replicas can be reduced'
            })
        elif current_replicas == max_replicas:
            issues.append({
                'severity': 'HIGH',
                'category': 'HPA_AT_MAX',
                'message': f'HPA at maximum replicas ({max_replicas})',
                'suggestion': 'Consider increasing max replicas or optimizing service'
            })

        return {
            'current_replicas': current_replicas,
            'min_max_range': f'{min_replicas}-{max_replicas}',
            'utilization': {
                'cpu_cores': round(avg_cpu_cores, 2),
                'memory_mb': round(avg_memory_mb, 0),
            },
            'issues': issues,
        }

    def analyze_events(
        self,
        oom_events: List[Dict[str, Any]],
        restart_count: int,
        lookback_hours: int = 24
    ) -> Dict[str, Any]:
        """
        Analyze pod events for issues

        Args:
            oom_events: List of OOMKilled events
            restart_count: Total pod restart count
            lookback_hours: Analysis time window

        Returns:
            Analysis result
        """
        issues = []

        event_thresholds = self.thresholds.get('events', {})

        # Check OOM events
        oom_critical_count = event_thresholds.get('oom_critical_count', 1)
        if len(oom_events) >= oom_critical_count:
            issues.append({
                'severity': 'CRITICAL',
                'category': 'OOM_KILLED',
                'message': f'{len(oom_events)} OOMKilled events in last {lookback_hours}h',
                'suggestion': 'Increase memory limit immediately'
            })

        # Check restart count
        restart_warning = event_thresholds.get('restart_warning_count', 3)
        restart_critical = event_thresholds.get('restart_critical_count', 10)

        if restart_count >= restart_critical:
            issues.append({
                'severity': 'CRITICAL',
                'category': 'HIGH_RESTART_COUNT',
                'message': f'{restart_count} pod restarts in last {lookback_hours}h',
                'suggestion': 'Investigate pod stability issues'
            })
        elif restart_count >= restart_warning:
            issues.append({
                'severity': 'WARNING',
                'category': 'MODERATE_RESTART_COUNT',
                'message': f'{restart_count} pod restarts in last {lookback_hours}h',
                'suggestion': 'Monitor pod stability'
            })

        return {
            'oom_events': len(oom_events),
            'restart_count': restart_count,
            'issues': issues,
        }

    def calculate_overall_status(self, all_issues: List[Dict[str, Any]]) -> str:
        """
        Calculate overall health status based on issues

        Args:
            all_issues: List of all detected issues

        Returns:
            Overall status: 'HEALTHY', 'WARNING', or 'CRITICAL'
        """
        if not all_issues:
            return 'HEALTHY'

        severities = [issue['severity'] for issue in all_issues]

        if 'CRITICAL' in severities:
            return 'CRITICAL'
        elif 'HIGH' in severities or 'WARNING' in severities:
            return 'WARNING'
        else:
            return 'HEALTHY'


if __name__ == '__main__':
    # Test analyzer
    logging.basicConfig(level=logging.INFO)

    # Sample thresholds
    thresholds = {
        'memory': {
            'leak_slope_threshold': 10,
            'leak_r_squared_threshold': 0.7,
            'leak_p_value_threshold': 0.05,
            'over_provision_ratio': 0.5,
            'under_provision_ratio': 0.85,
        },
        'hpa': {
            'over_scaling_min_replicas': 5,
            'over_scaling_cpu_threshold': 0.5,
        },
        'events': {
            'oom_critical_count': 1,
            'restart_warning_count': 3,
        }
    }

    analyzer = HealthAnalyzer(thresholds)

    # Test memory trend analysis
    print("=== Memory Trend Analysis ===")
    from datetime import timedelta
    base_time = datetime.now()
    time_series = {
        'pod-1': [
            (base_time + timedelta(hours=i), 3000 * (1024**2) + i * 50 * (1024**2))
            for i in range(24)
        ]
    }
    result = analyzer.analyze_memory_trend(time_series)
    print(f"Leak detected: {result['leak_detected']}")
    print(f"Slope: {result['slope_mb_per_hour']} MB/h")
    print(f"R²: {result['r_squared']}")

    # Test resource allocation
    print("\n=== Resource Allocation ===")
    result = analyzer.analyze_resource_allocation(
        avg_usage=3500 * (1024**2),
        p95_usage=4000 * (1024**2),
        request=4096 * (1024**2),
        limit=6144 * (1024**2),
        resource_type='memory'
    )
    print(f"Avg vs Request: {result['avg_vs_request']:.1%}")
    print(f"P95 vs Limit: {result['p95_vs_limit']:.1%}")
    print(f"Issues: {len(result['issues'])}")
