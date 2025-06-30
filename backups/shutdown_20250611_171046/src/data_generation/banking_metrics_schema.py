# src/data_generation/banking_metrics_schema.py
from dataclasses import dataclass
from typing import Dict, List
import pandas as pd
import numpy as np
from datetime import datetime, timedelta


@dataclass
class BankingMetricsSchema:
    """Define the exact metrics your banking system produces"""

    # Core application metrics
    api_request_rate: float          # requests/second
    api_error_rate: float           # errors/second
    api_response_time_p50: float    # milliseconds
    api_response_time_p95: float    # milliseconds
    api_response_time_p99: float    # milliseconds

    # Service-specific metrics
    auth_request_rate: float        # login attempts/second
    transaction_request_rate: float  # transactions/second
    account_query_rate: float       # account lookups/second
    atm_request_rate: float         # ATM transactions/second

    # Infrastructure metrics
    cpu_usage_percent: float        # CPU utilization %
    memory_usage_percent: float     # Memory utilization %
    network_bytes_in: float         # bytes/second
    network_bytes_out: float        # bytes/second
    active_connections: int         # concurrent connections

    # Banking-specific business metrics
    concurrent_users: int           # active users
    transaction_volume_usd: float   # $/second being processed
    failed_authentication_rate: float  # failed logins/second

    # Time context
    timestamp: datetime
    is_business_hours: bool
    is_weekend: bool
    is_month_end: bool


class BankingTrafficPatterns:
    """Generate realistic banking traffic patterns"""

    def __init__(self):
        self.base_patterns = self._define_base_patterns()

    def _define_base_patterns(self) -> Dict:
        """Define baseline traffic patterns for different times"""
        return {
            'business_hours': {
                'api_request_rate': {'mean': 150, 'std': 30},
                'auth_request_rate': {'mean': 25, 'std': 8},
                'transaction_request_rate': {'mean': 45, 'std': 12},
                'account_query_rate': {'mean': 80, 'std': 20},
                'atm_request_rate': {'mean': 15, 'std': 5},
                'concurrent_users': {'mean': 500, 'std': 100},
                'cpu_usage_percent': {'mean': 45, 'std': 15},
                'memory_usage_percent': {'mean': 60, 'std': 10},
                'network_bytes_in': {'mean': 50000, 'std': 15000},
                'network_bytes_out': {'mean': 40000, 'std': 12000},
                'active_connections': {'mean': 200, 'std': 50}
            },
            'off_hours': {
                'api_request_rate': {'mean': 40, 'std': 10},
                'auth_request_rate': {'mean': 8, 'std': 3},
                'transaction_request_rate': {'mean': 12, 'std': 4},
                'account_query_rate': {'mean': 20, 'std': 8},
                'atm_request_rate': {'mean': 8, 'std': 3},
                'concurrent_users': {'mean': 120, 'std': 30},
                'cpu_usage_percent': {'mean': 25, 'std': 8},
                'memory_usage_percent': {'mean': 40, 'std': 8},
                'network_bytes_in': {'mean': 15000, 'std': 5000},
                'network_bytes_out': {'mean': 12000, 'std': 4000},
                'active_connections': {'mean': 60, 'std': 20}
            },
            'weekend': {
                'api_request_rate': {'mean': 25, 'std': 8},
                'auth_request_rate': {'mean': 5, 'std': 2},
                'transaction_request_rate': {'mean': 8, 'std': 3},
                'account_query_rate': {'mean': 12, 'std': 5},
                # Higher ATM usage on weekends
                'atm_request_rate': {'mean': 12, 'std': 4},
                'concurrent_users': {'mean': 80, 'std': 25},
                'cpu_usage_percent': {'mean': 20, 'std': 6},
                'memory_usage_percent': {'mean': 35, 'std': 7},
                'network_bytes_in': {'mean': 8000, 'std': 3000},
                'network_bytes_out': {'mean': 6000, 'std': 2500},
                'active_connections': {'mean': 40, 'std': 15}
            },
            'month_end': {  # Salary day surge
                'multiplier': 1.8,  # 80% increase in activity
                'duration_hours': 72  # 3-day surge
            }
        }
