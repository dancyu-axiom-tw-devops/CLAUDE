#!/usr/bin/env python3
"""
Configuration Loader for Exchange Service Health Check

Loads configuration from YAML files and environment variables.
"""

import os
import yaml
from pathlib import Path
from typing import Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)


class ConfigLoader:
    """Loads and manages configuration from YAML files and environment variables"""

    def __init__(self, config_dir: Optional[str] = None):
        """
        Initialize configuration loader

        Args:
            config_dir: Directory containing config files. Defaults to ../config relative to script
        """
        if config_dir is None:
            # Default to ../config relative to this script
            script_dir = Path(__file__).parent
            config_dir = script_dir.parent / "config"

        self.config_dir = Path(config_dir)
        self.thresholds: Dict[str, Any] = {}
        self.promql_queries: Dict[str, Any] = {}
        self.env_config: Dict[str, Any] = {}

        # Load configurations
        self._load_thresholds()
        self._load_promql_queries()
        self._load_env_config()

    def _load_thresholds(self):
        """Load threshold configuration from YAML"""
        thresholds_file = self.config_dir / "thresholds.yaml"

        if not thresholds_file.exists():
            logger.warning(f"Thresholds file not found: {thresholds_file}")
            self._set_default_thresholds()
            return

        try:
            with open(thresholds_file, 'r') as f:
                self.thresholds = yaml.safe_load(f)
            logger.info(f"Loaded thresholds from {thresholds_file}")
        except Exception as e:
            logger.error(f"Failed to load thresholds: {e}")
            self._set_default_thresholds()

    def _load_promql_queries(self):
        """Load PromQL query templates from YAML"""
        queries_file = self.config_dir / "promql_queries.yaml"

        if not queries_file.exists():
            logger.warning(f"PromQL queries file not found: {queries_file}")
            return

        try:
            with open(queries_file, 'r') as f:
                self.promql_queries = yaml.safe_load(f)
            logger.info(f"Loaded PromQL queries from {queries_file}")
        except Exception as e:
            logger.error(f"Failed to load PromQL queries: {e}")

    def _load_env_config(self):
        """Load configuration from environment variables"""
        self.env_config = {
            # Prometheus
            'prometheus_url': os.getenv('PROMETHEUS_URL', 'http://prometheus-operated.monitoring.svc.cluster.local:9090'),

            # Service details
            'namespace': os.getenv('SERVICE_NAMESPACE', 'forex-prod'),
            'service_name': os.getenv('SERVICE_NAME', 'exchange-service'),
            'deployment_name': os.getenv('DEPLOYMENT_NAME', 'exchange-service'),
            'hpa_name': os.getenv('HPA_NAME', 'exchange-service'),
            'container_name': os.getenv('CONTAINER_NAME', 'exchange-service'),

            # Slack
            'slack_bot_token': os.getenv('SLACK_BOT_TOKEN', ''),
            'slack_webhook_url': os.getenv('SLACK_WEBHOOK_URL', ''),
            'slack_channel': os.getenv('SLACK_CHANNEL', '#sre-alerts'),

            # Report storage
            'report_dir': os.getenv('REPORT_DIR', '/reports'),

            # Collection settings
            'lookback_hours': int(os.getenv('LOOKBACK_HOURS', '24')),
            'query_timeout': int(os.getenv('QUERY_TIMEOUT', '30')),
        }

        logger.info(f"Loaded environment configuration: {self.env_config.keys()}")

    def _set_default_thresholds(self):
        """Set default thresholds if config file not found"""
        self.thresholds = {
            'memory': {
                'usage_warning': 75,
                'usage_critical': 85,
                'leak_slope_threshold': 10,
                'leak_r_squared_threshold': 0.7,
                'leak_p_value_threshold': 0.05,
                'over_provision_ratio': 0.5,
                'under_provision_ratio': 0.85,
                'qos_ratio_warning': 2.0,
            },
            'cpu': {
                'usage_warning': 70,
                'usage_critical': 85,
                'over_provision_ratio': 0.4,
                'under_provision_ratio': 0.80,
                'qos_ratio_warning': 3.0,
            },
            'hpa': {
                'over_scaling_min_replicas': 5,
                'over_scaling_cpu_threshold': 0.5,
                'over_scaling_memory_threshold': 2000,
                'under_scaling_max_replicas': 2,
                'under_scaling_cpu_threshold': 2.0,
                'under_scaling_memory_threshold': 5000,
            },
            'events': {
                'oom_critical_count': 1,
                'oom_lookback_hours': 24,
                'restart_warning_count': 3,
                'restart_critical_count': 10,
                'restart_lookback_hours': 24,
            },
            'collection': {
                'lookback_hours': 24,
                'step': '5m',
                'timeout': 30,
            }
        }
        logger.info("Using default thresholds")

    def get_threshold(self, category: str, key: str, default: Any = None) -> Any:
        """
        Get a specific threshold value

        Args:
            category: Threshold category (e.g., 'memory', 'cpu')
            key: Threshold key within category
            default: Default value if not found

        Returns:
            Threshold value or default
        """
        try:
            return self.thresholds.get(category, {}).get(key, default)
        except Exception:
            return default

    def get_promql_query(self, category: str, query_name: str, **kwargs) -> str:
        """
        Get a PromQL query template and format with provided variables

        Args:
            category: Query category (e.g., 'memory', 'cpu')
            query_name: Query name within category
            **kwargs: Variables to format into the query template

        Returns:
            Formatted PromQL query string
        """
        try:
            template = self.promql_queries.get(category, {}).get(query_name, '')
            if not template:
                logger.warning(f"Query not found: {category}.{query_name}")
                return ''

            # Add default variables from env_config
            format_vars = {
                'namespace': self.env_config['namespace'],
                'pod_pattern': f"{self.env_config['service_name']}-.*",
                'container': self.env_config['container_name'],
                'deployment_name': self.env_config['deployment_name'],
                'hpa_name': self.env_config['hpa_name'],
                'lookback': f"{self.get_threshold('collection', 'lookback_hours', 24)}h",
                'step': self.get_threshold('collection', 'step', '5m'),
            }

            # Override with provided kwargs
            format_vars.update(kwargs)

            # Format the template
            return template.format(**format_vars)
        except Exception as e:
            logger.error(f"Failed to format query {category}.{query_name}: {e}")
            return ''

    def get_env(self, key: str, default: Any = None) -> Any:
        """Get environment configuration value"""
        return self.env_config.get(key, default)

    def get_all_thresholds(self) -> Dict[str, Any]:
        """Get all threshold configurations"""
        return self.thresholds

    def get_service_config(self) -> Dict[str, str]:
        """Get service-specific configuration"""
        return {
            'namespace': self.env_config['namespace'],
            'service_name': self.env_config['service_name'],
            'deployment_name': self.env_config['deployment_name'],
            'hpa_name': self.env_config['hpa_name'],
            'container_name': self.env_config['container_name'],
        }


# Singleton instance
_config_instance: Optional[ConfigLoader] = None


def get_config(config_dir: Optional[str] = None) -> ConfigLoader:
    """
    Get singleton configuration instance

    Args:
        config_dir: Config directory (only used on first call)

    Returns:
        ConfigLoader instance
    """
    global _config_instance
    if _config_instance is None:
        _config_instance = ConfigLoader(config_dir)
    return _config_instance


if __name__ == '__main__':
    # Test configuration loading
    logging.basicConfig(level=logging.INFO)

    config = get_config()

    print("=== Thresholds ===")
    print(f"Memory warning threshold: {config.get_threshold('memory', 'usage_warning')}%")
    print(f"CPU critical threshold: {config.get_threshold('cpu', 'usage_critical')}%")
    print(f"OOM critical count: {config.get_threshold('events', 'oom_critical_count')}")

    print("\n=== Environment Config ===")
    print(f"Prometheus URL: {config.get_env('prometheus_url')}")
    print(f"Namespace: {config.get_env('namespace')}")
    print(f"Service: {config.get_env('service_name')}")

    print("\n=== PromQL Query Example ===")
    query = config.get_promql_query('memory', 'current_usage')
    print(f"Memory usage query:\n{query}")

    print("\n=== Service Config ===")
    for key, value in config.get_service_config().items():
        print(f"{key}: {value}")
