#!/usr/bin/env python3
"""
Prometheus Client Module
Handles Prometheus API queries via kubectl exec from within cluster
"""

import subprocess
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple


class PrometheusClient:
    """Client for querying Prometheus from within Kubernetes cluster"""

    def __init__(self, prometheus_url: str, namespace: str, context: str):
        self.prometheus_url = prometheus_url
        self.namespace = namespace
        self.context = context
        self.query_pod = None

    def _find_query_pod(self) -> str:
        """Find a pod to use for querying Prometheus"""
        if self.query_pod:
            return self.query_pod

        cmd = [
            "kubectl", "get", "pods",
            "-n", self.namespace,
            "--context", self.context,
            "-o", "jsonpath={.items[0].metadata.name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise Exception(f"Failed to find query pod: {result.stderr}")

        self.query_pod = result.stdout.strip()
        return self.query_pod

    def _exec_wget(self, url: str) -> str:
        """Execute wget from pod to access Prometheus"""
        pod = self._find_query_pod()
        cmd = [
            "kubectl", "exec", "-n", self.namespace,
            pod, "--context", self.context,
            "--", "wget", "-qO-", url
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise Exception(f"Prometheus query failed: {result.stderr}")
        return result.stdout

    def query_instant(self, query: str, time: Optional[datetime] = None) -> Dict:
        """
        Execute instant Prometheus query

        Args:
            query: PromQL query string
            time: Optional time for query (default: now)

        Returns:
            Prometheus API response data
        """
        params = f"query={query}"
        if time:
            timestamp = int(time.timestamp())
            params += f"&time={timestamp}"

        url = f"{self.prometheus_url}/api/v1/query?{params}"
        response = self._exec_wget(url)
        data = json.loads(response)

        if data.get('status') != 'success':
            raise Exception(f"Prometheus query failed: {data.get('error', 'unknown error')}")

        return data.get('data', {})

    def query_range(self, query: str, start: datetime, end: datetime, step: str = "5m") -> Dict:
        """
        Execute range Prometheus query

        Args:
            query: PromQL query string
            start: Start time
            end: End time
            step: Query resolution (e.g., "5m", "1h")

        Returns:
            Prometheus API response data
        """
        start_ts = int(start.timestamp())
        end_ts = int(end.timestamp())

        # Convert step string to seconds
        step_seconds = self._parse_step(step)

        url = (f"{self.prometheus_url}/api/v1/query_range?"
               f"query={query}&start={start_ts}&end={end_ts}&step={step_seconds}")

        response = self._exec_wget(url)
        data = json.loads(response)

        if data.get('status') != 'success':
            raise Exception(f"Prometheus range query failed: {data.get('error', 'unknown error')}")

        return data.get('data', {})

    def _parse_step(self, step: str) -> int:
        """Convert step string (5m, 1h) to seconds"""
        if step.endswith('s'):
            return int(step[:-1])
        elif step.endswith('m'):
            return int(step[:-1]) * 60
        elif step.endswith('h'):
            return int(step[:-1]) * 3600
        elif step.endswith('d'):
            return int(step[:-1]) * 86400
        else:
            return int(step)  # Assume seconds if no suffix

    def get_memory_usage(self, pod_pattern: str) -> Dict[str, float]:
        """
        Get current memory working set for pods matching pattern

        Args:
            pod_pattern: Regex pattern for pod names (e.g., "nacos-.*")

        Returns:
            Dict mapping pod names to memory usage in bytes
        """
        query = (f'container_memory_working_set_bytes{{'
                f'namespace="{self.namespace}",'
                f'pod=~"{pod_pattern}",'
                f'container!="",'
                f'container!="POD"}}')

        result = self.query_instant(query)

        usage = {}
        for item in result.get('result', []):
            pod = item['metric'].get('pod', '')
            container = item['metric'].get('container', '')
            value = float(item['value'][1])

            # Sum all containers for each pod
            if pod not in usage:
                usage[pod] = 0
            usage[pod] += value

        return usage

    def get_memory_limits(self, pod_pattern: str) -> Dict[str, float]:
        """
        Get memory limits for pods matching pattern

        Args:
            pod_pattern: Regex pattern for pod names

        Returns:
            Dict mapping pod names to memory limit in bytes
        """
        query = (f'kube_pod_container_resource_limits{{'
                f'namespace="{self.namespace}",'
                f'pod=~"{pod_pattern}",'
                f'resource="memory"}}')

        result = self.query_instant(query)

        limits = {}
        for item in result.get('result', []):
            pod = item['metric'].get('pod', '')
            container = item['metric'].get('container', '')
            value = float(item['value'][1])

            # Take max limit across containers
            if pod not in limits or value > limits[pod]:
                limits[pod] = value

        return limits

    def get_memory_requests(self, pod_pattern: str) -> Dict[str, float]:
        """
        Get memory requests for pods matching pattern

        Args:
            pod_pattern: Regex pattern for pod names

        Returns:
            Dict mapping pod names to memory request in bytes
        """
        query = (f'kube_pod_container_resource_requests{{'
                f'namespace="{self.namespace}",'
                f'pod=~"{pod_pattern}",'
                f'resource="memory"}}')

        result = self.query_instant(query)

        requests = {}
        for item in result.get('result', []):
            pod = item['metric'].get('pod', '')
            value = float(item['value'][1])

            # Sum all containers for each pod
            if pod not in requests:
                requests[pod] = 0
            requests[pod] += value

        return requests

    def get_memory_trend(self, pod_pattern: str, hours: int = 24) -> Dict[str, List[Tuple[int, float]]]:
        """
        Get memory usage trend for pods over time

        Args:
            pod_pattern: Regex pattern for pod names
            hours: Number of hours to look back

        Returns:
            Dict mapping pod names to list of (timestamp, value) tuples
        """
        end = datetime.now()
        start = end - timedelta(hours=hours)

        query = (f'container_memory_working_set_bytes{{'
                f'namespace="{self.namespace}",'
                f'pod=~"{pod_pattern}",'
                f'container!="",'
                f'container!="POD"}}')

        result = self.query_range(query, start, end, step="5m")

        trends = {}
        for item in result.get('result', []):
            pod = item['metric'].get('pod', '')
            values = item.get('values', [])

            if pod not in trends:
                trends[pod] = []

            # Convert values to (timestamp, bytes) tuples
            for timestamp, value in values:
                trends[pod].append((int(timestamp), float(value)))

        # Aggregate by pod (sum all containers)
        aggregated = {}
        for pod in set(k for k in trends.keys()):
            pod_base = pod  # Already aggregated by pod name
            if pod not in aggregated:
                aggregated[pod] = trends[pod]

        return aggregated

    def get_jvm_heap_usage(self, pod_pattern: str) -> Dict[str, Dict[str, float]]:
        """
        Get JVM heap memory metrics (if available)

        Args:
            pod_pattern: Regex pattern for pod names

        Returns:
            Dict with JVM heap used, committed, max values
        """
        query = (f'jvm_memory_used_bytes{{'
                f'namespace="{self.namespace}",'
                f'pod=~"{pod_pattern}",'
                f'area="heap"}}')

        try:
            result = self.query_instant(query)

            jvm_metrics = {}
            for item in result.get('result', []):
                pod = item['metric'].get('pod', '')
                value = float(item['value'][1])

                if pod not in jvm_metrics:
                    jvm_metrics[pod] = {}

                jvm_metrics[pod]['heap_used'] = value

            return jvm_metrics
        except Exception:
            # JVM metrics may not be available yet
            return {}
