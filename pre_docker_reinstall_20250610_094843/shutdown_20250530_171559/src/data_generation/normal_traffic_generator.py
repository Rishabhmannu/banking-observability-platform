# src/data_generation/normal_traffic_generator.py
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import random
from typing import List, Tuple, Dict

# Import the BankingTrafficPatterns class
from .banking_metrics_schema import BankingTrafficPatterns


class NormalTrafficGenerator:
    """Generate realistic normal banking traffic patterns"""

    def __init__(self, patterns: BankingTrafficPatterns):
        self.patterns = patterns
        np.random.seed(42)  # For reproducible results

    def generate_normal_day(self, date: datetime, num_samples: int = 1440) -> pd.DataFrame:
        """Generate 24 hours of normal banking traffic (1 sample per minute)"""

        timestamps = pd.date_range(
            start=date,
            periods=num_samples,
            freq='1min'
        )

        data_points = []

        for ts in timestamps:
            # Determine traffic pattern based on time
            pattern_key = self._get_pattern_key(ts)
            pattern = self.patterns.base_patterns[pattern_key]

            # Apply month-end surge if applicable
            multiplier = self._get_month_end_multiplier(ts)

            # Generate correlated metrics
            metrics = self._generate_correlated_metrics(pattern, multiplier)

            # Add timestamp context
            metrics.update({
                'timestamp': ts,
                'is_business_hours': 9 <= ts.hour <= 17,
                'is_weekend': ts.weekday() >= 5,
                'is_month_end': ts.day >= 28
            })

            data_points.append(metrics)

        return pd.DataFrame(data_points)

    def _get_pattern_key(self, timestamp: datetime) -> str:
        """Determine which traffic pattern to use"""
        if timestamp.weekday() >= 5:  # Weekend
            return 'weekend'
        elif 9 <= timestamp.hour <= 17:  # Business hours
            return 'business_hours'
        else:  # Off hours
            return 'off_hours'

    def _get_month_end_multiplier(self, timestamp: datetime) -> float:
        """Apply month-end surge multiplier"""
        if timestamp.day >= 28:
            # Gradual increase towards month end
            days_from_month_end = 31 - timestamp.day
            surge_intensity = max(
                0, 1.0 + (0.8 * (4 - days_from_month_end) / 4))
            return surge_intensity
        return 1.0

    def _generate_correlated_metrics(self, pattern: Dict, multiplier: float) -> Dict:
        """Generate correlated metrics that make business sense"""

        # Start with base request rate
        api_request_rate = max(0, np.random.normal(
            pattern['api_request_rate']['mean'] * multiplier,
            pattern['api_request_rate']['std']
        ))

        # Other rates should correlate with API request rate
        auth_rate_ratio = np.random.uniform(
            0.15, 0.20)  # 15-20% of requests are auth
        transaction_rate_ratio = np.random.uniform(
            0.25, 0.35)  # 25-35% are transactions
        account_query_ratio = np.random.uniform(
            0.45, 0.65)  # 45-65% are account queries

        auth_request_rate = api_request_rate * auth_rate_ratio
        transaction_request_rate = api_request_rate * transaction_rate_ratio
        account_query_rate = api_request_rate * account_query_ratio

        # ATM traffic is somewhat independent but increases on weekends
        atm_request_rate = max(0, np.random.normal(
            pattern['atm_request_rate']['mean'] * multiplier,
            pattern['atm_request_rate']['std']
        ))

        # Infrastructure metrics correlate with request load
        load_factor = api_request_rate / pattern['api_request_rate']['mean']

        cpu_usage = np.clip(
            np.random.normal(
                pattern['cpu_usage_percent']['mean'] * min(load_factor, 1.5),
                pattern['cpu_usage_percent']['std']
            ), 0, 95
        )

        memory_usage = np.clip(
            np.random.normal(
                pattern['memory_usage_percent']['mean'] *
                min(load_factor, 1.3),
                pattern['memory_usage_percent']['std']
            ), 0, 95
        )

        # Network traffic correlates with request rate
        network_bytes_in = max(0, np.random.normal(
            pattern['network_bytes_in']['mean'] * load_factor,
            pattern['network_bytes_in']['std']
        ))

        network_bytes_out = max(0, np.random.normal(
            pattern['network_bytes_out']['mean'] * load_factor,
            pattern['network_bytes_out']['std']
        ))

        # Active connections scale with concurrent users
        concurrent_users = max(0, int(np.random.normal(
            pattern['concurrent_users']['mean'] * multiplier,
            pattern['concurrent_users']['std']
        )))

        active_connections = max(
            1, int(concurrent_users * np.random.uniform(0.3, 0.5)))

        # Response times increase with load (non-linear relationship)
        base_response_p50 = 45  # 45ms baseline
        base_response_p95 = 120  # 120ms baseline
        base_response_p99 = 250  # 250ms baseline

        response_multiplier = 1 + (load_factor - 1) * \
            2 if load_factor > 1 else 1

        response_time_p50 = max(10, np.random.normal(
            base_response_p50 * response_multiplier, 15
        ))
        response_time_p95 = max(response_time_p50 * 1.5, np.random.normal(
            base_response_p95 * response_multiplier, 30
        ))
        response_time_p99 = max(response_time_p95 * 1.5, np.random.normal(
            base_response_p99 * response_multiplier, 60
        ))

        # Error rate stays low during normal operations
        api_error_rate = max(0, np.random.exponential(0.5)
                             )  # Very low error rate

        # Failed auth rate correlates slightly with auth attempts
        failed_authentication_rate = auth_request_rate * \
            np.random.uniform(0.02, 0.08)

        # Transaction volume scales with transaction rate
        avg_transaction_size = np.random.uniform(
            100, 500)  # $100-500 per transaction
        transaction_volume_usd = transaction_request_rate * avg_transaction_size

        return {
            'api_request_rate': api_request_rate,
            'api_error_rate': api_error_rate,
            'api_response_time_p50': response_time_p50,
            'api_response_time_p95': response_time_p95,
            'api_response_time_p99': response_time_p99,
            'auth_request_rate': auth_request_rate,
            'transaction_request_rate': transaction_request_rate,
            'account_query_rate': account_query_rate,
            'atm_request_rate': atm_request_rate,
            'cpu_usage_percent': cpu_usage,
            'memory_usage_percent': memory_usage,
            'network_bytes_in': network_bytes_in,
            'network_bytes_out': network_bytes_out,
            'active_connections': active_connections,
            'concurrent_users': concurrent_users,
            'transaction_volume_usd': transaction_volume_usd,
            'failed_authentication_rate': failed_authentication_rate
        }

    def generate_normal_dataset(self, start_date: str, num_days: int) -> pd.DataFrame:
        """Generate multiple days of normal traffic"""
        start_dt = datetime.strptime(start_date, '%Y-%m-%d')

        all_data = []
        for day in range(num_days):
            current_date = start_dt + timedelta(days=day)
            day_data = self.generate_normal_day(current_date)
            all_data.append(day_data)

        return pd.concat(all_data, ignore_index=True)
