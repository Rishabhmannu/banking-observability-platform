# src/services/prometheus_collector.py
import requests
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import logging


class PrometheusDataCollector:
    def __init__(self, prometheus_url="http://localhost:9090"):
        self.prometheus_url = prometheus_url
        self.logger = logging.getLogger(__name__)

    def query_range(self, query, start_time, end_time, step='30s'):
        """Query Prometheus for historical data"""
        url = f"{self.prometheus_url}/api/v1/query_range"
        params = {
            'query': query,
            'start': start_time.timestamp(),
            'end': end_time.timestamp(),
            'step': step
        }

        response = requests.get(url, params=params)
        return response.json()

    def get_banking_metrics(self, lookback_minutes=60):
        """Collect key banking metrics for DDoS detection"""
        end_time = datetime.now()
        start_time = end_time - timedelta(minutes=lookback_minutes)

        # Define key metrics for DDoS detection
        metrics_queries = {
            'request_rate': 'sum(rate(http_requests_total[1m]))',
            'error_rate': 'sum(rate(http_requests_total{status=~"5.."}[1m]))',
            'response_time_p95': 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))',
            'active_connections': 'sum(up)',
            'network_in': 'sum(rate(node_network_receive_bytes_total[1m]))',
            'network_out': 'sum(rate(node_network_transmit_bytes_total[1m]))',
            'cpu_usage': 'avg(100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100))',
            'memory_usage': 'avg((1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100)'
        }

        collected_data = {}
        for metric_name, query in metrics_queries.items():
            try:
                result = self.query_range(query, start_time, end_time)
                collected_data[metric_name] = self._parse_prometheus_result(
                    result)
            except Exception as e:
                self.logger.error(f"Failed to collect {metric_name}: {e}")

        return self._align_timestamps(collected_data)

    def _parse_prometheus_result(self, result):
        """Parse Prometheus API response into pandas DataFrame"""
        if result['status'] != 'success' or not result['data']['result']:
            return pd.DataFrame()

        # Handle multiple series (if any)
        all_data = []
        for series in result['data']['result']:
            df = pd.DataFrame(series['values'], columns=['timestamp', 'value'])
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='s')
            df['value'] = pd.to_numeric(df['value'], errors='coerce')
            all_data.append(df)

        if all_data:
            combined_df = pd.concat(all_data, ignore_index=True)
            return combined_df.groupby('timestamp')['value'].sum().reset_index()
        return pd.DataFrame()

    def _align_timestamps(self, metrics_data):
        """Align all metrics to common timestamps"""
        if not metrics_data:
            return pd.DataFrame()

        # Find common timestamp range
        common_timestamps = None
        for metric_name, df in metrics_data.items():
            if df.empty:
                continue
            if common_timestamps is None:
                common_timestamps = set(df['timestamp'])
            else:
                common_timestamps = common_timestamps.intersection(
                    set(df['timestamp']))

        if not common_timestamps:
            return pd.DataFrame()

        # Create aligned dataset
        aligned_data = pd.DataFrame({'timestamp': sorted(common_timestamps)})

        for metric_name, df in metrics_data.items():
            if df.empty:
                aligned_data[metric_name] = np.nan
            else:
                df_dict = df.set_index('timestamp')['value'].to_dict()
                aligned_data[metric_name] = aligned_data['timestamp'].map(
                    df_dict)

        return aligned_data.sort_values('timestamp').reset_index(drop=True)
