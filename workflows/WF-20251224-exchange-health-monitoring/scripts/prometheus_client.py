#!/usr/bin/env python3
"""
Prometheus Client for Exchange Service Health Check

Wrapper around Prometheus HTTP API for querying metrics.
"""

import requests
import logging
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime, timedelta
from urllib.parse import urljoin

logger = logging.getLogger(__name__)


class PrometheusClient:
    """Client for querying Prometheus metrics"""

    def __init__(self, base_url: str, timeout: int = 30):
        """
        Initialize Prometheus client

        Args:
            base_url: Prometheus server URL (e.g., http://prometheus:9090)
            timeout: Query timeout in seconds
        """
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.api_base = urljoin(self.base_url, '/api/v1/')

    def _make_request(self, endpoint: str, params: Dict[str, Any]) -> Dict[str, Any]:
        """
        Make HTTP request to Prometheus API

        Args:
            endpoint: API endpoint (e.g., 'query', 'query_range')
            params: Query parameters

        Returns:
            Response data

        Raises:
            Exception: If request fails
        """
        url = urljoin(self.api_base, endpoint)

        try:
            response = requests.get(url, params=params, timeout=self.timeout)
            response.raise_for_status()

            data = response.json()

            if data.get('status') != 'success':
                error_msg = data.get('error', 'Unknown error')
                raise Exception(f"Prometheus query failed: {error_msg}")

            return data.get('data', {})

        except requests.exceptions.Timeout:
            logger.error(f"Prometheus query timeout after {self.timeout}s")
            raise Exception(f"Prometheus query timeout (>{self.timeout}s)")
        except requests.exceptions.RequestException as e:
            logger.error(f"Prometheus request failed: {e}")
            raise Exception(f"Prometheus request failed: {e}")

    def query(self, promql: str, time: Optional[datetime] = None) -> List[Dict[str, Any]]:
        """
        Execute instant query

        Args:
            promql: PromQL query string
            time: Optional evaluation timestamp (defaults to now)

        Returns:
            List of result items with metrics and values
        """
        params = {'query': promql}

        if time:
            params['time'] = time.timestamp()

        try:
            data = self._make_request('query', params)
            result = data.get('result', [])

            logger.debug(f"Query returned {len(result)} results: {promql[:100]}...")
            return result

        except Exception as e:
            logger.error(f"Instant query failed: {e}")
            return []

    def query_range(
        self,
        promql: str,
        start: datetime,
        end: datetime,
        step: str = '5m'
    ) -> List[Dict[str, Any]]:
        """
        Execute range query

        Args:
            promql: PromQL query string
            start: Start time
            end: End time
            step: Query resolution step (e.g., '5m', '1h')

        Returns:
            List of result items with time series data
        """
        params = {
            'query': promql,
            'start': start.timestamp(),
            'end': end.timestamp(),
            'step': step,
        }

        try:
            data = self._make_request('query_range', params)
            result = data.get('result', [])

            logger.debug(f"Range query returned {len(result)} series: {promql[:100]}...")
            return result

        except Exception as e:
            logger.error(f"Range query failed: {e}")
            return []

    def get_scalar_value(self, promql: str) -> Optional[float]:
        """
        Execute query and return single scalar value

        Args:
            promql: PromQL query that returns single value

        Returns:
            Scalar value or None if no result
        """
        results = self.query(promql)

        if not results:
            logger.warning(f"No results for scalar query: {promql[:100]}...")
            return None

        if len(results) > 1:
            logger.warning(f"Multiple results for scalar query, using first: {promql[:100]}...")

        try:
            value = float(results[0]['value'][1])
            return value
        except (KeyError, ValueError, IndexError) as e:
            logger.error(f"Failed to parse scalar value: {e}")
            return None

    def get_vector_values(self, promql: str) -> List[Tuple[Dict[str, str], float]]:
        """
        Execute query and return vector of (labels, value) tuples

        Args:
            promql: PromQL query that returns vector

        Returns:
            List of (metric_labels, value) tuples
        """
        results = self.query(promql)

        vector = []
        for item in results:
            try:
                labels = item.get('metric', {})
                value = float(item['value'][1])
                vector.append((labels, value))
            except (KeyError, ValueError, IndexError) as e:
                logger.warning(f"Failed to parse vector item: {e}")
                continue

        return vector

    def get_time_series(self, promql: str, start: datetime, end: datetime, step: str = '5m') -> Dict[str, List[Tuple[datetime, float]]]:
        """
        Execute range query and return time series data

        Args:
            promql: PromQL query
            start: Start time
            end: End time
            step: Query resolution

        Returns:
            Dict mapping pod name to list of (timestamp, value) tuples
        """
        results = self.query_range(promql, start, end, step)

        series_data = {}

        for item in results:
            try:
                # Extract pod name from labels
                labels = item.get('metric', {})
                pod_name = labels.get('pod', 'unknown')

                # Parse values (timestamps and values)
                values = item.get('values', [])
                series = []

                for timestamp, value in values:
                    try:
                        dt = datetime.fromtimestamp(float(timestamp))
                        val = float(value)
                        series.append((dt, val))
                    except (ValueError, TypeError) as e:
                        logger.warning(f"Failed to parse time series point: {e}")
                        continue

                series_data[pod_name] = series

            except Exception as e:
                logger.warning(f"Failed to parse time series: {e}")
                continue

        logger.debug(f"Parsed {len(series_data)} time series")
        return series_data

    def check_connection(self) -> bool:
        """
        Check if Prometheus is reachable

        Returns:
            True if connection successful
        """
        try:
            # Query simple expression to test connection
            self.query('up')
            logger.info(f"Successfully connected to Prometheus at {self.base_url}")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to Prometheus: {e}")
            return False

    def get_metric_aggregation(
        self,
        promql: str,
        start: datetime,
        end: datetime,
        step: str = '5m'
    ) -> Dict[str, float]:
        """
        Get aggregated statistics (min, max, avg) from time series

        Args:
            promql: PromQL query
            start: Start time
            end: End time
            step: Query resolution

        Returns:
            Dict with 'min', 'max', 'avg', 'current' values
        """
        series_data = self.get_time_series(promql, start, end, step)

        if not series_data:
            return {'min': 0.0, 'max': 0.0, 'avg': 0.0, 'current': 0.0}

        # Aggregate across all pods
        all_values = []
        current_values = []

        for pod_name, series in series_data.items():
            values = [val for _, val in series]
            all_values.extend(values)

            # Current value is the last value
            if values:
                current_values.append(values[-1])

        if not all_values:
            return {'min': 0.0, 'max': 0.0, 'avg': 0.0, 'current': 0.0}

        return {
            'min': min(all_values),
            'max': max(all_values),
            'avg': sum(all_values) / len(all_values),
            'current': sum(current_values) / len(current_values) if current_values else 0.0,
        }


if __name__ == '__main__':
    # Test Prometheus client
    logging.basicConfig(level=logging.DEBUG)

    import os
    prom_url = os.getenv('PROMETHEUS_URL', 'http://localhost:9090')

    client = PrometheusClient(prom_url)

    # Test connection
    if not client.check_connection():
        print("Failed to connect to Prometheus")
        exit(1)

    # Test instant query
    print("\n=== Instant Query ===")
    results = client.query('up{job="prometheus"}')
    print(f"Results: {results}")

    # Test scalar query
    print("\n=== Scalar Query ===")
    value = client.get_scalar_value('count(up)')
    print(f"Number of targets: {value}")

    # Test range query
    print("\n=== Range Query ===")
    end = datetime.now()
    start = end - timedelta(hours=1)
    series = client.get_time_series('up{job="prometheus"}', start, end, '1m')
    for pod, values in series.items():
        print(f"{pod}: {len(values)} data points")
