# src/data_generation/master_dataset_generator.py
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Tuple, List, Dict
import json
import os

# Import local modules
from .banking_metrics_schema import BankingTrafficPatterns
from .normal_traffic_generator import NormalTrafficGenerator
from .ddos_attack_generator import DDoSAttackGenerator


class MasterDatasetGenerator:
    """Master class to generate complete training datasets"""

    def __init__(self, output_dir: str = "data/synthetic"):
        self.output_dir = output_dir
        self.patterns = BankingTrafficPatterns()
        self.normal_generator = NormalTrafficGenerator(self.patterns)
        self.attack_generator = DDoSAttackGenerator()

        # Create output directory
        os.makedirs(output_dir, exist_ok=True)

    def generate_training_dataset(
        self,
        start_date: str = "2024-01-01",
        num_days: int = 30,
        attack_probability: float = 0.15,  # 15% chance of attack per day
        save_dataset: bool = True
    ) -> Tuple[pd.DataFrame, np.ndarray]:
        """
        Generate complete training dataset with normal traffic and attacks
        
        Args:
            start_date: Starting date for data generation
            num_days: Number of days to generate
            attack_probability: Probability of attack on any given day
            save_dataset: Whether to save the dataset to disk
        
        Returns:
            Tuple of (features_dataframe, labels_array)
        """

        print(f"Generating {num_days} days of synthetic banking data...")

        # Generate baseline normal traffic
        print("Generating normal traffic patterns...")
        normal_data = self.normal_generator.generate_normal_dataset(
            start_date, num_days)

        # Create labels array (0 = normal, 1 = attack)
        labels = np.zeros(len(normal_data))

        # Add attacks randomly based on probability
        print("Injecting DDoS attacks...")
        modified_data = normal_data.copy()
        attack_log = []

        # Group data by days to control attack frequency
        daily_groups = modified_data.groupby(
            modified_data['timestamp'].dt.date)

        current_idx = 0
        for date, day_data in daily_groups:
            day_start_idx = current_idx
            day_end_idx = current_idx + len(day_data)

            # Decide if this day should have an attack
            if np.random.random() < attack_probability:
                # Random attack time during the day (avoid first/last hour)
                attack_start_offset = np.random.randint(
                    60, len(day_data) - 120)  # 1 hour buffer
                attack_start_idx = day_start_idx + attack_start_offset

                # Generate attack
                attack_type = np.random.choice(
                    list(self.attack_generator.attack_types.keys()))
                day_data_copy = day_data.copy()

                # Adjust indices for the day subset
                day_attack_data, day_attack_indices = self.attack_generator.generate_attack_sequence(
                    day_data_copy, attack_start_offset, attack_type
                )

                # Update the main dataset
                modified_data.iloc[day_start_idx:day_end_idx] = day_attack_data.values

                # Update labels for attack period
                for attack_idx in day_attack_indices:
                    global_idx = day_start_idx + attack_idx
                    if global_idx < len(labels):
                        labels[global_idx] = 1

                # Log attack info
                attack_log.append({
                    'date': str(date),
                    'start_idx': day_start_idx + day_attack_indices[0] if day_attack_indices else attack_start_idx,
                    'end_idx': day_start_idx + day_attack_indices[-1] if day_attack_indices else attack_start_idx,
                    'attack_type': attack_type,
                    'duration_minutes': len(day_attack_indices)
                })

            current_idx = day_end_idx

        print(f"Generated {len(attack_log)} attacks across {num_days} days")

        # Add derived features
        print("Computing additional features...")
        enhanced_data = self._add_derived_features(modified_data)

        if save_dataset:
            self._save_dataset(enhanced_data, labels,
                               attack_log, start_date, num_days)

        return enhanced_data, labels

    def _add_derived_features(self, data: pd.DataFrame) -> pd.DataFrame:
        """Add derived features that help with DDoS detection"""

        enhanced_data = data.copy()

        # Rate of change features (key for detecting sudden spikes)
        for col in ['api_request_rate', 'api_error_rate', 'cpu_usage_percent', 'memory_usage_percent']:
            enhanced_data[f'{col}_change_1min'] = enhanced_data[col].pct_change(
                periods=1)
            enhanced_data[f'{col}_change_5min'] = enhanced_data[col].pct_change(
                periods=5)

        # Rolling statistics (to detect deviations from normal patterns)
        windows = [5, 15, 30]  # 5, 15, 30 minute windows
        for window in windows:
            for col in ['api_request_rate', 'api_error_rate', 'api_response_time_p95']:
                enhanced_data[f'{col}_rolling_mean_{window}'] = enhanced_data[col].rolling(
                    window=window).mean()
                enhanced_data[f'{col}_rolling_std_{window}'] = enhanced_data[col].rolling(
                    window=window).std()

                # Z-score (standardized deviation from rolling mean)
                rolling_mean = enhanced_data[f'{col}_rolling_mean_{window}']
                rolling_std = enhanced_data[f'{col}_rolling_std_{window}']
                enhanced_data[f'{col}_zscore_{window}'] = (
                    enhanced_data[col] - rolling_mean
                    # Add small epsilon to avoid division by zero
                ) / (rolling_std + 1e-8)

        # Ratio features (often more stable indicators)
        enhanced_data['error_to_request_ratio'] = (
            enhanced_data['api_error_rate'] /
            (enhanced_data['api_request_rate'] + 1e-8)
        )
        enhanced_data['network_in_to_out_ratio'] = (
            enhanced_data['network_bytes_in'] /
            (enhanced_data['network_bytes_out'] + 1e-8)
        )
        enhanced_data['auth_to_total_ratio'] = (
            enhanced_data['auth_request_rate'] /
            (enhanced_data['api_request_rate'] + 1e-8)
        )

        # Composite risk indicators
        enhanced_data['infrastructure_stress'] = (
            enhanced_data['cpu_usage_percent'] / 100 * 0.4 +
            enhanced_data['memory_usage_percent'] / 100 * 0.3 +
            enhanced_data['api_response_time_p95'] /
            1000 * 0.3  # Normalize to 0-1 scale
        )

        enhanced_data['traffic_anomaly_score'] = (
            enhanced_data['api_request_rate_change_1min'].abs() * 0.3 +
            enhanced_data['api_error_rate_change_1min'].abs() * 0.4 +
            enhanced_data['error_to_request_ratio'] * 0.3
        )

        return enhanced_data

    def _save_dataset(
        self,
        data: pd.DataFrame,
        labels: np.ndarray,
        attack_log: List[Dict],
        start_date: str,
        num_days: int
    ):
        """Save the generated dataset and metadata"""

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Save main dataset and labels
        data_path = f"{self.output_dir}/banking_ddos_dataset_{timestamp}.csv"
        labels_path = f"{self.output_dir}/banking_ddos_labels_{timestamp}.npy"

        data.to_csv(data_path, index=False)
        np.save(labels_path, labels)

        # Save attack log
        attack_log_df = pd.DataFrame(attack_log)
        attack_log_path = f"{self.output_dir}/attack_log_{timestamp}.csv"
        attack_log_df.to_csv(attack_log_path, index=False)

        # Save metadata
        metadata = {
            'generation_date': datetime.now().isoformat(),
            'start_date': start_date,
            'num_days': num_days,
            'total_samples': len(data),
            'num_attacks': len(attack_log),
            'attack_percentage': (labels.sum() / len(labels)) * 100,
            'feature_columns': list(data.columns),
            'data_path': data_path,
            'labels_path': labels_path,
            'attack_log_path': attack_log_path
        }

        metadata_path = f"{self.output_dir}/metadata_{timestamp}.json"
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)

        print(f"Dataset saved:")
        print(f"  Data: {data_path}")
        print(f"  Labels: {labels_path}")
        print(f"  Attack Log: {attack_log_path}")
        print(f"  Metadata: {metadata_path}")
        print(f"  Total samples: {len(data):,}")
        print(
            f"  Attack samples: {int(labels.sum()):,} ({(labels.sum()/len(labels)*100):.2f}%)")

    def generate_validation_dataset(
        self,
        start_date: str = "2024-02-01",
        num_days: int = 7,
        attack_probability: float = 0.3,  # Higher attack rate for validation
        save_dataset: bool = True
    ) -> Tuple[pd.DataFrame, np.ndarray]:
        """Generate a separate validation dataset with different patterns"""

        print("Generating validation dataset...")
        return self.generate_training_dataset(
            start_date=start_date,
            num_days=num_days,
            attack_probability=attack_probability,
            save_dataset=save_dataset
        )
