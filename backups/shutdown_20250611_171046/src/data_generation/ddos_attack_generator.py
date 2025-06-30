# src/data_generation/ddos_attack_generator.py
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Tuple
import random


class DDoSAttackGenerator:
    """Generate realistic DDoS attack patterns"""

    def __init__(self):
        self.attack_types = self._define_attack_types()

    def _define_attack_types(self) -> Dict:
        """Define different types of DDoS attacks and their characteristics"""
        return {
            'volumetric_flood': {
                'name': 'Volumetric Traffic Flood',
                'description': 'High volume of requests to overwhelm bandwidth',
                'characteristics': {
                    'request_rate_multiplier': (10, 50),  # 10-50x normal rate
                    'error_rate_increase': (5, 20),       # 5-20x normal errors
                    # 3-15x slower responses
                    'response_time_multiplier': (3, 15),
                    'cpu_usage_increase': (40, 80),       # +40-80% CPU usage
                    # +20-50% memory usage
                    'memory_usage_increase': (20, 50),
                    # 8-25x network traffic
                    'network_multiplier': (8, 25),
                    'connection_multiplier': (5, 20),     # 5-20x connections
                    'duration_minutes': (5, 45),          # 5-45 minute attacks
                    'ramp_up_minutes': (1, 5),           # 1-5 minute ramp up
                    'ramp_down_minutes': (2, 8)          # 2-8 minute ramp down
                }
            },
            'application_layer': {
                'name': 'Application Layer Attack',
                'description': 'Targets specific banking endpoints',
                'characteristics': {
                    'request_rate_multiplier': (3, 12),   # 3-12x normal rate
                    # 10-40x normal errors
                    'error_rate_increase': (10, 40),
                    # 5-25x slower responses
                    'response_time_multiplier': (5, 25),
                    'cpu_usage_increase': (60, 90),       # +60-90% CPU usage
                    # +30-70% memory usage
                    'memory_usage_increase': (30, 70),
                    'network_multiplier': (2, 8),        # 2-8x network traffic
                    'connection_multiplier': (8, 30),     # 8-30x connections
                    # 10-90 minute attacks
                    'duration_minutes': (10, 90),
                    'ramp_up_minutes': (2, 10),          # 2-10 minute ramp up
                    # 3-15 minute ramp down
                    'ramp_down_minutes': (3, 15)
                }
            },
            'protocol_attack': {
                'name': 'Protocol-Level Attack',
                'description': 'Exploits protocol weaknesses',
                'characteristics': {
                    'request_rate_multiplier': (5, 20),   # 5-20x normal rate
                    'error_rate_increase': (8, 30),       # 8-30x normal errors
                    # 2-10x slower responses
                    'response_time_multiplier': (2, 10),
                    'cpu_usage_increase': (30, 60),       # +30-60% CPU usage
                    # +40-80% memory usage
                    'memory_usage_increase': (40, 80),
                    # 15-40x network traffic
                    'network_multiplier': (15, 40),
                    'connection_multiplier': (20, 50),    # 20-50x connections
                    'duration_minutes': (3, 30),          # 3-30 minute attacks
                    'ramp_up_minutes': (0.5, 3),         # 30s-3min ramp up
                    'ramp_down_minutes': (1, 5)          # 1-5 minute ramp down
                }
            },
            'slow_rate': {
                'name': 'Slow Rate Attack',
                'description': 'Low-volume but sustained attack',
                'characteristics': {
                    'request_rate_multiplier': (1.5, 4),  # 1.5-4x normal rate
                    'error_rate_increase': (3, 10),       # 3-10x normal errors
                    # 8-30x slower responses
                    'response_time_multiplier': (8, 30),
                    'cpu_usage_increase': (20, 40),       # +20-40% CPU usage
                    # +50-90% memory usage
                    'memory_usage_increase': (50, 90),
                    # 1.2-3x network traffic
                    'network_multiplier': (1.2, 3),
                    'connection_multiplier': (10, 40),    # 10-40x connections
                    # 30-180 minute attacks
                    'duration_minutes': (30, 180),
                    'ramp_up_minutes': (5, 20),          # 5-20 minute ramp up
                    # 10-30 minute ramp down
                    'ramp_down_minutes': (10, 30)
                }
            }
        }

    def generate_attack_sequence(
        self,
        normal_data: pd.DataFrame,
        attack_start_idx: int,
        attack_type: str = None
    ) -> Tuple[pd.DataFrame, List[int]]:
        """
        Generate a single attack sequence starting at the given index
        
        Args:
            normal_data: DataFrame containing normal traffic data
            attack_start_idx: Index to start the attack
            attack_type: Type of attack to simulate (random if None)
        
        Returns:
            Tuple of (modified_data, attack_indices)
        """

        if attack_type is None:
            attack_type = random.choice(list(self.attack_types.keys()))

        attack_config = self.attack_types[attack_type]
        chars = attack_config['characteristics']

        # Determine attack duration and phases
        duration_minutes = random.randint(*chars['duration_minutes'])
        ramp_up_min, ramp_up_max = chars['ramp_up_minutes']
        ramp_up_minutes = random.randint(int(round(ramp_up_min)), int(round(ramp_up_max)))
        ramp_down_min, ramp_down_max = chars['ramp_down_minutes']
        ramp_down_minutes = random.randint(int(round(ramp_down_min)), int(round(ramp_down_max)))

        # Ensure attack doesn't exceed data bounds
        max_duration = len(normal_data) - attack_start_idx
        duration_minutes = min(duration_minutes, max_duration)
        
        # Recalculate phases to fit within duration
        ramp_up_minutes = min(ramp_up_minutes, duration_minutes // 3)
        ramp_down_minutes = min(ramp_down_minutes, duration_minutes // 3)

        # Calculate attack indices
        attack_end_idx = attack_start_idx + duration_minutes
        ramp_up_end_idx = attack_start_idx + ramp_up_minutes
        steady_end_idx = max(ramp_up_end_idx, attack_end_idx - ramp_down_minutes)

        attack_indices = list(range(attack_start_idx, attack_end_idx))

        # Create modified data
        modified_data = normal_data.copy()

        for idx in range(attack_start_idx, attack_end_idx):
            if idx >= len(modified_data):
                break

            # Calculate attack intensity based on phase
            if idx < ramp_up_end_idx:
                # Ramp up phase
                progress = (idx - attack_start_idx) / max(1, ramp_up_end_idx - attack_start_idx)
                intensity = progress
            elif idx < steady_end_idx:
                # Steady attack phase
                intensity = 1.0
            else:
                # Ramp down phase
                progress = (attack_end_idx - idx) / max(1, attack_end_idx - steady_end_idx)
                intensity = progress

            # Apply attack characteristics with intensity scaling
            modified_data.iloc[idx] = self._apply_attack_characteristics(
                modified_data.iloc[idx], chars, intensity, attack_type
            )

        return modified_data, attack_indices

    def _apply_attack_characteristics(
        self,
        row: pd.Series,
        characteristics: Dict,
        intensity: float,
        attack_type: str
    ) -> pd.Series:
        """Apply attack characteristics to a single data point"""

        modified_row = row.copy()

        # Calculate multipliers based on intensity
        request_multiplier = 1 + \
            (random.uniform(
                *characteristics['request_rate_multiplier']) - 1) * intensity
        error_multiplier = 1 + \
            (random.uniform(
                *characteristics['error_rate_increase']) - 1) * intensity
        response_multiplier = 1 + \
            (random.uniform(
                *characteristics['response_time_multiplier']) - 1) * intensity
        cpu_increase = random.uniform(
            *characteristics['cpu_usage_increase']) * intensity
        memory_increase = random.uniform(
            *characteristics['memory_usage_increase']) * intensity
        network_multiplier = 1 + \
            (random.uniform(
                *characteristics['network_multiplier']) - 1) * intensity
        connection_multiplier = 1 + \
            (random.uniform(
                *characteristics['connection_multiplier']) - 1) * intensity

        # Apply request rate changes
        modified_row['api_request_rate'] *= request_multiplier

        # Different attack types affect different service endpoints differently
        if attack_type == 'application_layer':
            # Target specific banking services
            # Heavy auth attacks
            modified_row['auth_request_rate'] *= request_multiplier * 1.5
            # Fewer completed transactions
            modified_row['transaction_request_rate'] *= request_multiplier * 0.3
            modified_row['account_query_rate'] *= request_multiplier * 1.2
        elif attack_type == 'volumetric_flood':
            # Affects all services equally
            modified_row['auth_request_rate'] *= request_multiplier
            # Most transactions fail
            modified_row['transaction_request_rate'] *= request_multiplier * 0.1
            modified_row['account_query_rate'] *= request_multiplier
            # ATMs less affected
            modified_row['atm_request_rate'] *= request_multiplier * 0.5
        else:
            # Default scaling
            modified_row['auth_request_rate'] *= request_multiplier * 0.8
            modified_row['transaction_request_rate'] *= request_multiplier * 0.4
            modified_row['account_query_rate'] *= request_multiplier * 0.9

        # Apply error rate increases
        modified_row['api_error_rate'] = modified_row['api_error_rate'] * error_multiplier + \
            modified_row['api_request_rate'] * 0.1 * intensity

        # Auth failures spike
        modified_row['failed_authentication_rate'] *= error_multiplier * 2

        # Apply response time increases
        modified_row['api_response_time_p50'] *= response_multiplier
        modified_row['api_response_time_p95'] *= response_multiplier * 1.2
        modified_row['api_response_time_p99'] *= response_multiplier * 1.5

        # Apply infrastructure impacts
        modified_row['cpu_usage_percent'] = min(
            98, modified_row['cpu_usage_percent'] + cpu_increase)
        modified_row['memory_usage_percent'] = min(
            95, modified_row['memory_usage_percent'] + memory_increase)

        # Apply network impacts
        modified_row['network_bytes_in'] *= network_multiplier
        modified_row['network_bytes_out'] *= network_multiplier * \
            0.3  # Less outbound during attack

        # Apply connection impacts
        modified_row['active_connections'] = int(
            modified_row['active_connections'] * connection_multiplier)

        # Concurrent users may decrease due to poor experience
        modified_row['concurrent_users'] = int(
            modified_row['concurrent_users'] * (1 - 0.3 * intensity))

        # Transaction volume decreases due to failures
        modified_row['transaction_volume_usd'] *= (1 - 0.7 * intensity)

        return modified_row

    def generate_multiple_attacks(
        self,
        normal_data: pd.DataFrame,
        num_attacks: int = 5,
        min_gap_hours: int = 2
    ) -> Tuple[pd.DataFrame, List[Tuple[int, int, str]]]:
        """
        Generate multiple random attacks in the dataset
        
        Returns:
            Tuple of (modified_data, list_of_(start_idx, end_idx, attack_type))
        """

        modified_data = normal_data.copy()
        attack_info = []

        # Ensure attacks don't overlap by maintaining minimum gaps
        attack_positions = []
        data_length = len(normal_data)
        min_gap_minutes = min_gap_hours * 60

        for _ in range(num_attacks):
            attempts = 0
            while attempts < 100:  # Avoid infinite loop
                # At least 1 hour from end
                start_idx = random.randint(0, data_length - 60)

                # Check if position conflicts with existing attacks
                conflict = False
                for existing_start, existing_end in attack_positions:
                    if abs(start_idx - existing_start) < min_gap_minutes:
                        conflict = True
                        break

                if not conflict:
                    attack_type = random.choice(list(self.attack_types.keys()))
                    modified_data, attack_indices = self.generate_attack_sequence(
                        modified_data, start_idx, attack_type
                    )

                    end_idx = start_idx + \
                        len(attack_indices) - \
                        1 if attack_indices else start_idx
                    attack_positions.append((start_idx, end_idx))
                    attack_info.append((start_idx, end_idx, attack_type))
                    break

                attempts += 1

        return modified_data, attack_info
