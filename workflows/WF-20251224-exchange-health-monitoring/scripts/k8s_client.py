#!/usr/bin/env python3
"""
Kubernetes Client for Exchange Service Health Check

Wrapper around Kubernetes Python client for querying cluster resources.
"""

import logging
from typing import Dict, List, Any, Optional
from datetime import datetime, timezone
from kubernetes import client, config
from kubernetes.client.rest import ApiException

logger = logging.getLogger(__name__)


class K8sClient:
    """Client for querying Kubernetes resources"""

    def __init__(self, in_cluster: bool = True):
        """
        Initialize Kubernetes client

        Args:
            in_cluster: True if running inside cluster, False for local kubeconfig
        """
        try:
            if in_cluster:
                config.load_incluster_config()
                logger.info("Loaded in-cluster Kubernetes config")
            else:
                config.load_kube_config()
                logger.info("Loaded kubeconfig from local file")

            self.core_v1 = client.CoreV1Api()
            self.apps_v1 = client.AppsV1Api()
            self.autoscaling_v2 = client.AutoscalingV2Api()

        except Exception as e:
            logger.error(f"Failed to initialize Kubernetes client: {e}")
            raise

    def get_deployment(self, name: str, namespace: str) -> Optional[Dict[str, Any]]:
        """
        Get deployment information

        Args:
            name: Deployment name
            namespace: Namespace

        Returns:
            Deployment details or None if not found
        """
        try:
            deployment = self.apps_v1.read_namespaced_deployment(name, namespace)

            return {
                'name': deployment.metadata.name,
                'namespace': deployment.metadata.namespace,
                'replicas': {
                    'desired': deployment.spec.replicas,
                    'available': deployment.status.available_replicas or 0,
                    'unavailable': deployment.status.unavailable_replicas or 0,
                    'ready': deployment.status.ready_replicas or 0,
                },
                'containers': self._extract_container_specs(deployment.spec.template.spec.containers),
                'created_at': deployment.metadata.creation_timestamp,
            }

        except ApiException as e:
            if e.status == 404:
                logger.warning(f"Deployment not found: {namespace}/{name}")
            else:
                logger.error(f"Failed to get deployment: {e}")
            return None

    def _extract_container_specs(self, containers: List[Any]) -> Dict[str, Dict[str, Any]]:
        """Extract resource specs from container definitions"""
        container_specs = {}

        for container in containers:
            resources = container.resources or client.V1ResourceRequirements()

            requests = resources.requests or {}
            limits = resources.limits or {}

            container_specs[container.name] = {
                'image': container.image,
                'resources': {
                    'requests': {
                        'memory': self._parse_memory(requests.get('memory', '0')),
                        'cpu': self._parse_cpu(requests.get('cpu', '0')),
                    },
                    'limits': {
                        'memory': self._parse_memory(limits.get('memory', '0')),
                        'cpu': self._parse_cpu(limits.get('cpu', '0')),
                    },
                },
            }

        return container_specs

    def _parse_memory(self, memory_str: str) -> int:
        """Parse memory string to bytes (e.g., '4Gi' -> 4294967296)"""
        if not memory_str or memory_str == '0':
            return 0

        memory_str = str(memory_str).strip()
        units = {'Ki': 1024, 'Mi': 1024**2, 'Gi': 1024**3, 'Ti': 1024**4}

        for unit, multiplier in units.items():
            if memory_str.endswith(unit):
                try:
                    return int(float(memory_str[:-len(unit)]) * multiplier)
                except ValueError:
                    logger.warning(f"Failed to parse memory: {memory_str}")
                    return 0

        # Try parsing as raw bytes
        try:
            return int(memory_str)
        except ValueError:
            logger.warning(f"Failed to parse memory: {memory_str}")
            return 0

    def _parse_cpu(self, cpu_str: str) -> float:
        """Parse CPU string to cores (e.g., '1000m' -> 1.0)"""
        if not cpu_str or cpu_str == '0':
            return 0.0

        cpu_str = str(cpu_str).strip()

        # Milli-cores (e.g., '500m')
        if cpu_str.endswith('m'):
            try:
                return float(cpu_str[:-1]) / 1000.0
            except ValueError:
                logger.warning(f"Failed to parse CPU: {cpu_str}")
                return 0.0

        # Cores (e.g., '2' or '1.5')
        try:
            return float(cpu_str)
        except ValueError:
            logger.warning(f"Failed to parse CPU: {cpu_str}")
            return 0.0

    def get_pods(self, namespace: str, label_selector: str) -> List[Dict[str, Any]]:
        """
        Get pods matching label selector

        Args:
            namespace: Namespace
            label_selector: Label selector (e.g., 'app=exchange-service')

        Returns:
            List of pod details
        """
        try:
            pods = self.core_v1.list_namespaced_pod(namespace, label_selector=label_selector)

            pod_list = []
            for pod in pods.items:
                pod_list.append({
                    'name': pod.metadata.name,
                    'namespace': pod.metadata.namespace,
                    'phase': pod.status.phase,
                    'created_at': pod.metadata.creation_timestamp,
                    'node': pod.spec.node_name,
                    'restart_count': self._get_total_restarts(pod.status.container_statuses),
                })

            return pod_list

        except ApiException as e:
            logger.error(f"Failed to list pods: {e}")
            return []

    def _get_total_restarts(self, container_statuses: Optional[List[Any]]) -> int:
        """Calculate total restart count across all containers"""
        if not container_statuses:
            return 0

        return sum(status.restart_count for status in container_statuses)

    def get_hpa(self, name: str, namespace: str) -> Optional[Dict[str, Any]]:
        """
        Get HorizontalPodAutoscaler information

        Args:
            name: HPA name
            namespace: Namespace

        Returns:
            HPA details or None if not found
        """
        try:
            hpa = self.autoscaling_v2.read_namespaced_horizontal_pod_autoscaler(name, namespace)

            return {
                'name': hpa.metadata.name,
                'namespace': hpa.metadata.namespace,
                'min_replicas': hpa.spec.min_replicas,
                'max_replicas': hpa.spec.max_replicas,
                'current_replicas': hpa.status.current_replicas or 0,
                'desired_replicas': hpa.status.desired_replicas or 0,
                'metrics': self._extract_hpa_metrics(hpa.spec.metrics),
                'current_metrics': self._extract_current_metrics(hpa.status.current_metrics),
            }

        except ApiException as e:
            if e.status == 404:
                logger.warning(f"HPA not found: {namespace}/{name}")
            else:
                logger.error(f"Failed to get HPA: {e}")
            return None

    def _extract_hpa_metrics(self, metrics: Optional[List[Any]]) -> List[Dict[str, Any]]:
        """Extract HPA metric targets"""
        if not metrics:
            return []

        metric_list = []
        for metric in metrics:
            metric_dict = {
                'type': metric.type,
            }

            if metric.type == 'Resource':
                metric_dict['name'] = metric.resource.name
                if metric.resource.target.type == 'Utilization':
                    metric_dict['target'] = metric.resource.target.average_utilization
                    metric_dict['unit'] = '%'
                elif metric.resource.target.type == 'AverageValue':
                    metric_dict['target'] = metric.resource.target.average_value
                    metric_dict['unit'] = 'value'

            metric_list.append(metric_dict)

        return metric_list

    def _extract_current_metrics(self, current_metrics: Optional[List[Any]]) -> List[Dict[str, Any]]:
        """Extract current HPA metric values"""
        if not current_metrics:
            return []

        metric_list = []
        for metric in current_metrics:
            metric_dict = {
                'type': metric.type,
            }

            if metric.type == 'Resource':
                metric_dict['name'] = metric.resource.name
                if hasattr(metric.resource.current, 'average_utilization'):
                    metric_dict['current'] = metric.resource.current.average_utilization
                    metric_dict['unit'] = '%'
                elif hasattr(metric.resource.current, 'average_value'):
                    metric_dict['current'] = metric.resource.current.average_value
                    metric_dict['unit'] = 'value'

            metric_list.append(metric_dict)

        return metric_list

    def get_events(
        self,
        namespace: str,
        field_selector: Optional[str] = None,
        since: Optional[datetime] = None
    ) -> List[Dict[str, Any]]:
        """
        Get events from namespace

        Args:
            namespace: Namespace
            field_selector: Field selector filter
            since: Only return events after this time

        Returns:
            List of events
        """
        try:
            events = self.core_v1.list_namespaced_event(
                namespace,
                field_selector=field_selector
            )

            event_list = []
            for event in events.items:
                event_time = event.last_timestamp or event.event_time

                # Filter by time if specified
                if since and event_time:
                    if event_time.replace(tzinfo=timezone.utc) < since.replace(tzinfo=timezone.utc):
                        continue

                event_list.append({
                    'type': event.type,
                    'reason': event.reason,
                    'message': event.message,
                    'count': event.count or 1,
                    'first_timestamp': event.first_timestamp,
                    'last_timestamp': event_time,
                    'involved_object': {
                        'kind': event.involved_object.kind,
                        'name': event.involved_object.name,
                        'namespace': event.involved_object.namespace,
                    },
                })

            return event_list

        except ApiException as e:
            logger.error(f"Failed to list events: {e}")
            return []

    def get_oom_events(self, namespace: str, pod_prefix: str, since: Optional[datetime] = None) -> List[Dict[str, Any]]:
        """Get OOMKilled events for pods with specific prefix"""
        all_events = self.get_events(namespace, since=since)

        oom_events = []
        for event in all_events:
            if event['reason'] == 'OOMKilling' and event['involved_object']['name'].startswith(pod_prefix):
                oom_events.append(event)

        return oom_events


if __name__ == '__main__':
    # Test Kubernetes client
    logging.basicConfig(level=logging.INFO)

    # Use local kubeconfig for testing
    k8s = K8sClient(in_cluster=False)

    # Test deployment
    print("\n=== Deployment ===")
    deployment = k8s.get_deployment('exchange-service', 'forex-prod')
    if deployment:
        print(f"Name: {deployment['name']}")
        print(f"Replicas: {deployment['replicas']}")
        print(f"Containers: {list(deployment['containers'].keys())}")

    # Test HPA
    print("\n=== HPA ===")
    hpa = k8s.get_hpa('exchange-service', 'forex-prod')
    if hpa:
        print(f"Name: {hpa['name']}")
        print(f"Min/Max: {hpa['min_replicas']}/{hpa['max_replicas']}")
        print(f"Current/Desired: {hpa['current_replicas']}/{hpa['desired_replicas']}")

    # Test pods
    print("\n=== Pods ===")
    pods = k8s.get_pods('forex-prod', 'app=exchange-service')
    print(f"Found {len(pods)} pods")
    for pod in pods[:3]:
        print(f"  {pod['name']}: {pod['phase']}, restarts={pod['restart_count']}")

    # Test events
    print("\n=== Events ===")
    from datetime import timedelta
    since = datetime.now(timezone.utc) - timedelta(hours=24)
    events = k8s.get_events('forex-prod', since=since)
    print(f"Found {len(events)} events in last 24h")
