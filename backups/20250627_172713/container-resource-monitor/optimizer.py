"""
Container Resource Optimization Algorithms
Implements various algorithms to recommend optimal resource allocation
"""
import numpy as np
import pandas as pd
from scipy import stats
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class ResourceOptimizer:
    """Container resource optimization engine"""
    
    def __init__(self, config):
        self.config = config
        self.recommendations = {}
        
    def analyze_container_resources(self, container_name, metrics_history):
        """Analyze resource usage and provide recommendations"""
        if not metrics_history or len(metrics_history) < 10:
            logger.warning(f"Insufficient data for {container_name}")
            return None
        
        # Convert to DataFrame for easier analysis
        df = pd.DataFrame(metrics_history)
        
        # Calculate statistics
        cpu_stats = self._calculate_resource_stats(df['cpu_usage_cores'])
        memory_stats = self._calculate_resource_stats(df['memory_usage_bytes'])
        
        # Get current limits
        current_cpu_limit = df['cpu_limit_cores'].iloc[-1] if 'cpu_limit_cores' in df else None
        current_memory_limit = df['memory_limit_bytes'].iloc[-1] if 'memory_limit_bytes' in df else None
        
        # Calculate recommendations
        cpu_recommendation = self._recommend_cpu(cpu_stats, current_cpu_limit)
        memory_recommendation = self._recommend_memory(memory_stats, current_memory_limit)
        
        # Calculate stability score
        stability_score = self._calculate_stability_score(df)
        
        # Calculate waste percentage
        cpu_waste = self._calculate_waste_percentage(
            cpu_stats['p95'], 
            current_cpu_limit
        ) if current_cpu_limit else 0
        
        memory_waste = self._calculate_waste_percentage(
            memory_stats['p95'] / 1048576,  # Convert to MB
            current_memory_limit / 1048576 if current_memory_limit else None
        ) if current_memory_limit else 0
        
        # Calculate potential cost savings
        cost_savings = self._calculate_cost_savings(
            current_cpu_limit,
            cpu_recommendation,
            current_memory_limit,
            memory_recommendation
        )
        
        recommendation = {
            'container_name': container_name,
            'timestamp': datetime.now().isoformat(),
            'cpu': {
                'current_limit': current_cpu_limit,
                'current_usage_p95': round(cpu_stats['p95'], 3),
                'recommended_limit': cpu_recommendation,
                'waste_percent': round(cpu_waste, 1)
            },
            'memory': {
                'current_limit_mb': round(current_memory_limit / 1048576, 0) if current_memory_limit else None,
                'current_usage_p95_mb': round(memory_stats['p95'] / 1048576, 0),
                'recommended_limit_mb': round(memory_recommendation / 1048576, 0),
                'waste_percent': round(memory_waste, 1)
            },
            'stability_score': round(stability_score, 2),
            'estimated_monthly_savings_usd': round(cost_savings, 2),
            'confidence': self._calculate_confidence(len(metrics_history))
        }
        
        return recommendation
    
    def _calculate_resource_stats(self, series):
        """Calculate statistical metrics for resource usage"""
        return {
            'mean': series.mean(),
            'std': series.std(),
            'min': series.min(),
            'max': series.max(),
            'p50': series.quantile(0.50),
            'p75': series.quantile(0.75),
            'p90': series.quantile(0.90),
            'p95': series.quantile(0.95),
            'p99': series.quantile(0.99)
        }
    
    def _recommend_cpu(self, stats, current_limit):
        """Recommend optimal CPU allocation"""
        # Use p95 as baseline with buffer
        recommended = stats['p95'] * self.config.CPU_RECOMMENDATION_BUFFER
        
        # Consider burst capacity (p99)
        burst_capacity = stats['p99'] * 1.1
        recommended = max(recommended, burst_capacity)
        
        # Apply min/max constraints
        recommended = max(0.1, recommended)  # Minimum 0.1 cores
        recommended = min(4.0, recommended)   # Maximum 4 cores
        
        # Round to nearest 0.25
        recommended = round(recommended * 4) / 4
        
        return recommended
    
    def _recommend_memory(self, stats, current_limit):
        """Recommend optimal memory allocation"""
        # Use p95 as baseline with buffer
        recommended = stats['p95'] * self.config.MEMORY_RECOMMENDATION_BUFFER
        
        # Consider peak usage
        peak_buffer = stats['max'] * 1.1
        recommended = max(recommended, peak_buffer)
        
        # Apply min/max constraints
        recommended = max(134217728, recommended)  # Minimum 128MB
        recommended = min(8589934592, recommended)  # Maximum 8GB
        
        # Round to nearest 64MB
        mb = recommended / 1048576
        recommended = round(mb / 64) * 64 * 1048576
        
        return recommended
    
    def _calculate_stability_score(self, df):
        """Calculate container stability score (0-100)"""
        score = 100.0
        
        # Check for restarts
        if 'restart_count' in df.columns:
            restarts = df['restart_count'].iloc[-1] - df['restart_count'].iloc[0]
            score -= restarts * self.config.RESTART_PENALTY_WEIGHT
        
        # Check for OOM kills
        if 'oom_kill_count' in df.columns:
            oom_kills = df['oom_kill_count'].iloc[-1] - df['oom_kill_count'].iloc[0]
            score -= oom_kills * self.config.OOM_KILL_PENALTY_WEIGHT
        
        # Check for high CPU throttling
        if 'cpu_throttled_periods' in df.columns:
            throttle_rate = df['cpu_throttled_periods'].mean()
            if throttle_rate > 0.1:  # More than 10% throttled
                score -= 10
        
        # Check for memory pressure
        if 'memory_usage_bytes' in df.columns and 'memory_limit_bytes' in df.columns:
            memory_pressure = (df['memory_usage_bytes'] / df['memory_limit_bytes']).mean()
            if memory_pressure > 0.9:  # Over 90% memory usage
                score -= 15
        
        return max(0, score)
    
    def _calculate_waste_percentage(self, used, limit):
        """Calculate resource waste percentage"""
        if not limit or limit == 0:
            return 0
        
        waste = (limit - used) / limit * 100
        return max(0, waste)
    
    def _calculate_cost_savings(self, current_cpu, recommended_cpu, 
                               current_memory, recommended_memory):
        """Calculate potential monthly cost savings"""
        if not current_cpu or not current_memory:
            return 0
        
        # CPU savings
        cpu_diff = max(0, current_cpu - recommended_cpu)
        cpu_savings = cpu_diff * self.config.CPU_COST_PER_CORE_HOUR * 24 * 30
        
        # Memory savings
        memory_diff_gb = max(0, (current_memory - recommended_memory) / 1073741824)
        memory_savings = memory_diff_gb * self.config.MEMORY_COST_PER_GB_HOUR * 24 * 30
        
        return cpu_savings + memory_savings
    
    def _calculate_confidence(self, data_points):
        """Calculate confidence level based on data availability"""
        if data_points < 10:
            return 'low'
        elif data_points < 100:
            return 'medium'
        else:
            return 'high'

class VPARecommender:
    """Vertical Pod Autoscaler-style recommender"""
    
    @staticmethod
    def calculate_recommendation(metrics_history, percentile=95):
        """Calculate VPA-style recommendation"""
        if not metrics_history:
            return None
        
        df = pd.DataFrame(metrics_history)
        
        # Calculate percentile-based recommendation
        cpu_percentile = df['cpu_usage_cores'].quantile(percentile / 100)
        memory_percentile = df['memory_usage_bytes'].quantile(percentile / 100)
        
        # Add safety margin
        cpu_recommendation = cpu_percentile * 1.15
        memory_recommendation = memory_percentile * 1.2
        
        return {
            'cpu_cores': round(cpu_recommendation, 3),
            'memory_bytes': int(memory_recommendation),
            'method': f'vpa_p{percentile}'
        }

class MLBasedOptimizer:
    """Machine learning based optimizer (simplified)"""
    
    @staticmethod
    def predict_future_usage(metrics_history, horizon_hours=24):
        """Predict future resource usage using simple linear regression"""
        if len(metrics_history) < 20:
            return None
        
        df = pd.DataFrame(metrics_history)
        
        # Simple trend analysis
        x = np.arange(len(df))
        
        # CPU trend
        cpu_slope, cpu_intercept, _, _, _ = stats.linregress(x, df['cpu_usage_cores'])
        future_cpu = cpu_intercept + cpu_slope * (len(df) + horizon_hours * 2)
        
        # Memory trend
        mem_slope, mem_intercept, _, _, _ = stats.linregress(x, df['memory_usage_bytes'])
        future_memory = mem_intercept + mem_slope * (len(df) + horizon_hours * 2)
        
        return {
            'predicted_cpu_cores': max(0.1, round(future_cpu, 3)),
            'predicted_memory_bytes': max(134217728, int(future_memory)),
            'method': 'ml_linear_regression',
            'horizon_hours': horizon_hours
        }

class RightSizingAnalyzer:
    """Analyzes containers for right-sizing opportunities"""
    
    @staticmethod
    def categorize_container(recommendation):
        """Categorize container based on resource usage patterns"""
        cpu_waste = recommendation['cpu']['waste_percent']
        memory_waste = recommendation['memory']['waste_percent']
        stability = recommendation['stability_score']
        
        if cpu_waste > 70 or memory_waste > 70:
            return 'severely_overprovisioned'
        elif cpu_waste > 50 or memory_waste > 50:
            return 'overprovisioned'
        elif cpu_waste < 10 and memory_waste < 10:
            return 'right_sized'
        elif stability < 50:
            return 'unstable'
        else:
            return 'slightly_overprovisioned'
    
    @staticmethod
    def prioritize_optimizations(recommendations, service_priorities):
        """Prioritize which containers to optimize first"""
        scored_recommendations = []
        
        for rec in recommendations:
            container_name = rec['container_name']
            
            # Calculate optimization score
            waste_score = (rec['cpu']['waste_percent'] + rec['memory']['waste_percent']) / 2
            savings_score = rec['estimated_monthly_savings_usd']
            priority = service_priorities.get(container_name, 0.5)
            
            # Combined score (higher is better)
            total_score = (waste_score * 0.3 + savings_score * 0.5) * priority
            
            scored_recommendations.append({
                'recommendation': rec,
                'optimization_score': round(total_score, 2)
            })
        
        # Sort by score descending
        return sorted(scored_recommendations, key=lambda x: x['optimization_score'], reverse=True)