#!/usr/bin/env python3
"""
Test Aliyun Prometheus (ARMS) connectivity
"""

import json
import base64
import urllib.request
import urllib.parse
import urllib.error

# Prometheus configuration
PROMETHEUS_URL = "https://workspace-default-cms-5886645564773850-cn-hongkong.cn-hongkong.log.aliyuncs.com/prometheus/workspace-default-cms-5886645564773850-cn-hongkong/aliyun-prom-c61392b504d1742f1954f31dea08f7869"
PROMETHEUS_USERNAME = "YOUR_ALIYUN_ACCESS_KEY_ID"
PROMETHEUS_PASSWORD = "YOUR_ALIYUN_ACCESS_KEY_SECRET"

def test_prometheus_query(query):
    """Test a Prometheus query"""
    try:
        params = {"query": query}
        url = f"{PROMETHEUS_URL}/api/v1/query?{urllib.parse.urlencode(params)}"

        print(f"Testing query: {query}")
        print(f"URL: {url}")

        # Create request with basic auth
        req = urllib.request.Request(url)
        credentials = f"{PROMETHEUS_USERNAME}:{PROMETHEUS_PASSWORD}"
        encoded_credentials = base64.b64encode(credentials.encode()).decode()
        req.add_header("Authorization", f"Basic {encoded_credentials}")

        # Execute request
        with urllib.request.urlopen(req, timeout=30) as response:
            data = json.loads(response.read().decode())

            print(f"Status: {data.get('status')}")

            if data.get('status') == 'success':
                results = data.get('data', {}).get('result', [])
                print(f"Results count: {len(results)}")

                if results:
                    print("Sample result:")
                    print(json.dumps(results[0], indent=2))
                else:
                    print("No data returned (query may be correct but no matching metrics)")
            else:
                print(f"Error: {data.get('error')}")

            print("-" * 80)
            return data.get('status') == 'success'

    except urllib.error.HTTPError as e:
        print(f"HTTP Error: {e.code} {e.reason}")
        print(f"Response: {e.read().decode()}")
        print("-" * 80)
        return False
    except Exception as e:
        print(f"Error: {e}")
        print("-" * 80)
        return False


def main():
    print("=" * 80)
    print("Testing Aliyun Prometheus (ARMS) Connectivity")
    print("=" * 80)
    print()

    # Test 1: Simple up query
    print("Test 1: Simple 'up' query")
    test_prometheus_query("up")
    print()

    # Test 2: Container memory query
    print("Test 2: Container memory for waas2-prod namespace")
    test_prometheus_query('container_memory_working_set_bytes{namespace="waas2-prod"}')
    print()

    # Test 3: Specific service memory
    print("Test 3: service-admin memory")
    test_prometheus_query('container_memory_working_set_bytes{namespace="waas2-prod", pod=~"service-admin-.*"}')
    print()

    # Test 4: CPU query
    print("Test 4: Container CPU for waas2-prod")
    test_prometheus_query('rate(container_cpu_usage_seconds_total{namespace="waas2-prod"}[5m])')
    print()

    # Test 5: Available namespaces
    print("Test 5: Check available namespaces")
    test_prometheus_query('count by (namespace) (kube_pod_info)')
    print()

    print("=" * 80)
    print("Test complete!")
    print("=" * 80)


if __name__ == "__main__":
    main()
