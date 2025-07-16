from flask import Flask, jsonify, request
import requests
import json
import time
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Tuple
import numpy as np
from scipy import stats
import threading
from prometheus_client import Counter, Histogram, Gauge, generate_latest
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Prometheus metrics for self-monitoring
correlation_analysis_duration = Histogram(
    'correlation_analysis_duration_seconds',
    'Time spent analyzing correlations'
)
correlation_events_total = Counter(
    'correlation_events_total',
    'Total correlation events detected',
    ['correlation_type']
)
correlation_confidence_score = Gauge(
    'correlation_confidence_score',
    'Latest correlation confidence score',
    ['metric_pair']
)


class EventCorrelationEngine:
    def __init__(self):
        self.prometheus_url = os.getenv(
            'PROMETHEUS_URL', 'http://prometheus:9090')
        self.analysis_interval = int(os.getenv('ANALYSIS_INTERVAL', '60'))
        self.confidence_threshold = float(
            os.getenv('CONFIDENCE_THRESHOLD', '0.7'))
        self.correlation_history = []
        self.is_running = False

        # ✅ VERIFIED WORKING METRICS - Organized by Business Value

        # HIGH PRIORITY: Transaction & Business Metrics
        self.transaction_metrics = [
            'transaction_requests_total',
            'transaction_failures_total',
            'transaction_duration_seconds_bucket',
            'transaction_avg_response_time',
            'slow_transaction_percentage',
            'transaction_anomaly_score',
            'business_hour_transaction_rate',
            'off_hour_transaction_rate',
            'slo_compliance_percentage',
            'transaction_performance_score'
        ]

        # HIGH PRIORITY: Database Performance Metrics
        self.database_metrics = [
            'banking_db_pool_utilization_percent',
            'banking_db_pool_connections_active',
            'banking_db_pool_connections_idle',
            'banking_db_queries_total',
            'banking_db_query_duration_seconds_bucket',
            'pg_stat_activity_count',
            'banking_db_pool_size'
        ]

        # PERFORMANCE CRITICAL: Cache Efficiency Metrics
        self.cache_metrics = [
            'banking_cache_hits_total',
            'banking_cache_misses_total',
            'redis_cache_hit_ratio',
            'redis_cache_efficiency_score',
            'redis_memory_used_bytes',
            'redis_connected_clients',
            'banking_cache_active_entries',
            'redis_cache_eviction_rate'
        ]

        # WORKFLOW CRITICAL: Message Queue Metrics
        self.message_queue_metrics = [
            'banking_messages_published_total',
            'banking_messages_consumed_total',
            'banking_unprocessed_messages',
            'banking_queue_consumer_lag',
            'rabbitmq_queue_messages_ready',
            'rabbitmq_queue_messages_total'
        ]

        # SECURITY CRITICAL: DDoS & Threat Detection
        self.security_metrics = [
            'ddos_detection_score',
            'ddos_binary_prediction',
            'ddos_confidence',
            'ddos_model_predictions_total',
            'detection_latency_seconds'
        ]

        # INFRASTRUCTURE: Container & System Resources
        self.infrastructure_metrics = [
            'container_cpu_usage_cores',
            'container_memory_usage_mb',
            'container_cpu_usage_percent',
            'container_memory_usage_percent',
            'container_network_rx_mb',
            'container_network_tx_mb'
        ]

        # Combined comprehensive metrics list
        self.key_metrics = (self.transaction_metrics +
                            self.database_metrics +
                            self.cache_metrics +
                            self.message_queue_metrics +
                            self.security_metrics +
                            self.infrastructure_metrics)

        logger.info(
            f"Initialized correlation engine with {len(self.key_metrics)} verified metrics")
        logger.info(f"Transaction metrics: {len(self.transaction_metrics)}")
        logger.info(f"Database metrics: {len(self.database_metrics)}")
        logger.info(f"Cache metrics: {len(self.cache_metrics)}")
        logger.info(
            f"Message queue metrics: {len(self.message_queue_metrics)}")
        logger.info(f"Security metrics: {len(self.security_metrics)}")
        logger.info(
            f"Infrastructure metrics: {len(self.infrastructure_metrics)}")

    def start_analysis_loop(self):
        """Start the continuous correlation analysis loop"""
        self.is_running = True
        analysis_thread = threading.Thread(target=self._analysis_loop)
        analysis_thread.daemon = True
        analysis_thread.start()
        logger.info("Event correlation analysis loop started")

    def _analysis_loop(self):
        """Main analysis loop - runs every analysis_interval seconds"""
        while self.is_running:
            try:
                with correlation_analysis_duration.time():
                    self._perform_correlation_analysis()
                time.sleep(self.analysis_interval)
            except Exception as e:
                logger.error(f"Error in analysis loop: {e}")
                time.sleep(30)  # Wait 30 seconds before retrying

    def _perform_correlation_analysis(self):
        """Perform comprehensive correlation analysis on verified working metrics"""
        logger.info(
            "Starting comprehensive correlation analysis with verified metrics...")

        # Get metrics data from last 15 minutes
        end_time = datetime.now()
        start_time = end_time - timedelta(minutes=15)

        business_correlations = []
        cross_domain_correlations = []
        infrastructure_correlations = []

        # Priority 1: Business-to-Business Correlations (HIGHEST VALUE)
        logger.info("Analyzing high-value business correlations...")
        business_metric_groups = [
            ('transaction', self.transaction_metrics),
            ('database', self.database_metrics),
            ('cache', self.cache_metrics),
            ('message_queue', self.message_queue_metrics),
            ('security', self.security_metrics)
        ]

        # Cross-category business correlations (most valuable)
        for i, (group1_name, group1_metrics) in enumerate(business_metric_groups):
            for j, (group2_name, group2_metrics) in enumerate(business_metric_groups[i+1:], i+1):
                # Limit to top 3 metrics per group
                for metric1 in group1_metrics[:3]:
                    for metric2 in group2_metrics[:3]:
                        correlation = self._analyze_metric_pair_safe(
                            metric1, metric2, start_time, end_time)
                        # Lower threshold for business
                        if correlation and correlation['confidence'] > 0.5:
                            correlation['category'] = 'business'
                            correlation['correlation_group'] = f"{group1_name}_to_{group2_name}"
                            business_correlations.append(correlation)
                            logger.info(
                                f"Business correlation: {group1_name}→{group2_name}: {metric1} ↔ {metric2} (confidence: {correlation['confidence']:.3f})")

        # Priority 2: Cross-Domain Correlations (Infrastructure to Business)
        logger.info("Analyzing cross-domain correlations...")
        # Top 5 infrastructure metrics
        for infra_metric in self.infrastructure_metrics[:5]:
            for business_group_name, business_metrics in business_metric_groups:
                # Top 2 from each business group
                for business_metric in business_metrics[:2]:
                    correlation = self._analyze_metric_pair_safe(
                        infra_metric, business_metric, start_time, end_time)
                    if correlation and correlation['confidence'] > self.confidence_threshold:
                        correlation['category'] = 'cross_domain'
                        correlation['correlation_group'] = f"infrastructure_to_{business_group_name}"
                        cross_domain_correlations.append(correlation)

        # Priority 3: Infrastructure Correlations (only if needed)
        if len(business_correlations) < 5:
            logger.info("Analyzing infrastructure correlations...")
            for i, metric1 in enumerate(self.infrastructure_metrics[:8]):
                # Limit combinations
                for metric2 in self.infrastructure_metrics[i+1:i+4]:
                    correlation = self._analyze_metric_pair_safe(
                        metric1, metric2, start_time, end_time)
                    if correlation and correlation['confidence'] > self.confidence_threshold:
                        correlation['category'] = 'infrastructure'
                        correlation['correlation_group'] = 'infrastructure_internal'
                        infrastructure_correlations.append(correlation)

        # Combine all correlations with business metrics prioritized
        all_correlations = business_correlations + \
            cross_domain_correlations + infrastructure_correlations

        # Update Prometheus metrics for all found correlations
        for correlation in all_correlations:
            correlation_events_total.labels(
                correlation_type=correlation['type']
            ).inc()

            # Create clean metric pair name for Prometheus
            metric1_clean = correlation['metric1'].split(
                '{')[0].replace('_total', '').replace('_seconds', '')
            metric2_clean = correlation['metric2'].split(
                '{')[0].replace('_total', '').replace('_seconds', '')
            correlation_confidence_score.labels(
                metric_pair=f"{metric1_clean}_{metric2_clean}"
            ).set(correlation['confidence'])

        # Store correlation results
        if all_correlations:
            self.correlation_history.append({
                'timestamp': end_time.isoformat(),
                'correlations': all_correlations,
                'analysis_summary': {
                    'business_correlations': len(business_correlations),
                    'cross_domain_correlations': len(cross_domain_correlations),
                    'infrastructure_correlations': len(infrastructure_correlations),
                    'total_correlations': len(all_correlations),
                    'high_value_correlations': len([c for c in business_correlations if c['confidence'] > 0.8])
                }
            })

            # Keep only last 100 analysis results
            if len(self.correlation_history) > 100:
                self.correlation_history.pop(0)

            logger.info(
                f"Analysis complete: {len(business_correlations)} business, {len(cross_domain_correlations)} cross-domain, {len(infrastructure_correlations)} infrastructure")
        else:
            logger.info(
                "No significant correlations found in this analysis cycle")

    def _analyze_metric_pair_safe(self, metric1: str, metric2: str, start_time: datetime, end_time: datetime) -> Dict:
        """Safely analyze correlation between two metrics with error handling"""
        try:
            return self._analyze_metric_pair(metric1, metric2, start_time, end_time)
        except Exception as e:
            logger.debug(f"Error analyzing {metric1} vs {metric2}: {e}")
            return None

    def _analyze_metric_pair(self, metric1: str, metric2: str, start_time: datetime, end_time: datetime) -> Dict:
        """Analyze correlation between two metrics with proper time series alignment"""
        try:
            # Get time series data for both metrics
            data1_raw = self._get_metric_timeseries_with_timestamps(
                metric1, start_time, end_time)
            data2_raw = self._get_metric_timeseries_with_timestamps(
                metric2, start_time, end_time)

            if not data1_raw or not data2_raw:
                return None

            # Align time series data to same timestamps
            aligned_data1, aligned_data2 = self._align_time_series(
                data1_raw, data2_raw)

            if len(aligned_data1) < 5 or len(aligned_data2) < 5:
                return None

            # Ensure both arrays have the same length
            min_length = min(len(aligned_data1), len(aligned_data2))
            aligned_data1 = aligned_data1[:min_length]
            aligned_data2 = aligned_data2[:min_length]

            # Calculate Pearson correlation
            correlation_coeff, p_value = stats.pearsonr(
                aligned_data1, aligned_data2)

            # Business-aware correlation thresholds
            min_correlation, max_p_value = self._get_correlation_thresholds(
                metric1, metric2)

            if abs(correlation_coeff) > min_correlation and p_value < max_p_value:
                return {
                    'metric1': metric1,
                    'metric2': metric2,
                    'correlation_coefficient': float(correlation_coeff),
                    'p_value': float(p_value),
                    'confidence': float(abs(correlation_coeff)),
                    'type': 'positive' if correlation_coeff > 0 else 'negative',
                    'sample_size': len(aligned_data1),
                    'timestamp': datetime.now().isoformat(),
                    'business_impact': self._assess_business_impact(metric1, metric2, correlation_coeff),
                    'statistical_significance': 'high' if p_value < 0.01 else 'medium' if p_value < 0.05 else 'low'
                }

        except Exception as e:
            logger.error(
                f"Error in correlation analysis for {metric1} vs {metric2}: {e}")

        return None

    def _get_correlation_thresholds(self, metric1: str, metric2: str) -> Tuple[float, float]:
        """Get appropriate correlation thresholds based on metric types"""
        # Check metric categories
        metric1_is_business = any(metric1 in group for group in [
            self.transaction_metrics, self.database_metrics,
            self.cache_metrics, self.message_queue_metrics, self.security_metrics
        ])
        metric2_is_business = any(metric2 in group for group in [
            self.transaction_metrics, self.database_metrics,
            self.cache_metrics, self.message_queue_metrics, self.security_metrics
        ])

        if metric1_is_business and metric2_is_business:
            return 0.5, 0.1  # Lower threshold for business-to-business correlations
        elif metric1_is_business or metric2_is_business:
            return 0.6, 0.05  # Medium threshold for cross-domain
        else:
            return 0.7, 0.05  # Higher threshold for infrastructure-only

    def _assess_business_impact(self, metric1: str, metric2: str, correlation_coeff: float) -> str:
        """Enhanced business impact assessment with banking domain knowledge"""

        # Define business-critical metric categories
        transaction_keywords = ['transaction', 'request', 'response', 'slo']
        database_keywords = ['db_pool', 'query', 'connection', 'pg_stat']
        cache_keywords = ['cache', 'redis', 'hit_ratio']
        security_keywords = ['ddos', 'detection', 'threat', 'confidence']
        queue_keywords = ['messages', 'queue', 'consumer', 'rabbitmq']

        def get_category(metric):
            metric_lower = metric.lower()
            if any(kw in metric_lower for kw in transaction_keywords):
                return 'transaction'
            elif any(kw in metric_lower for kw in database_keywords):
                return 'database'
            elif any(kw in metric_lower for kw in cache_keywords):
                return 'cache'
            elif any(kw in metric_lower for kw in security_keywords):
                return 'security'
            elif any(kw in metric_lower for kw in queue_keywords):
                return 'message_queue'
            else:
                return 'infrastructure'

        cat1 = get_category(metric1)
        cat2 = get_category(metric2)

        # High-value business correlations
        high_value_pairs = [
            ('transaction', 'database'), ('transaction', 'cache'),
            ('transaction', 'security'), ('database', 'cache'),
            ('security', 'transaction'), ('message_queue', 'transaction')
        ]

        correlation_strength = abs(correlation_coeff)

        if (cat1, cat2) in high_value_pairs or (cat2, cat1) in high_value_pairs:
            if correlation_strength > 0.8:
                return f"CRITICAL - Strong {cat1}↔{cat2} correlation affects core banking operations"
            elif correlation_strength > 0.6:
                return f"HIGH - Significant {cat1}↔{cat2} correlation impacts business performance"
            else:
                return f"MEDIUM - Moderate {cat1}↔{cat2} correlation, monitor for trends"

        elif cat1 == cat2 and cat1 in ['transaction', 'database', 'cache', 'security']:
            return f"MEDIUM - Internal {cat1} correlation may indicate bottlenecks"

        elif 'infrastructure' in [cat1, cat2]:
            return f"LOW - Infrastructure correlation with {cat1 if cat1 != 'infrastructure' else cat2}"

        else:
            return "LOW - General infrastructure correlation"

    def _get_metric_timeseries_with_timestamps(self, metric: str, start_time: datetime, end_time: datetime) -> List[Tuple[float, float]]:
        """Get time series data with timestamps for a metric from Prometheus"""
        try:
            # Handle different metric formats and try multiple query patterns
            query_variations = [
                metric,  # Direct metric name
                f"rate({metric}[1m])",  # Rate for counter metrics
                f"{metric}_total" if not metric.endswith('_total') else metric,
                f"avg({metric})" if 'ratio' in metric or 'percent' in metric else metric
            ]

            for query_metric in query_variations:
                data = self._query_prometheus_metric(
                    query_metric, start_time, end_time)
                if data and len(data) > 0:
                    logger.debug(
                        f"Successfully fetched {metric} using query: {query_metric}")
                    return data

            logger.debug(f"No data found for metric: {metric}")
            return []

        except Exception as e:
            logger.error(f"Error fetching metric {metric}: {e}")
            return []

    def _query_prometheus_metric(self, metric: str, start_time: datetime, end_time: datetime) -> List[Tuple[float, float]]:
        """Query Prometheus for a specific metric"""
        try:
            query = f"query_range?query={metric}&start={start_time.timestamp()}&end={end_time.timestamp()}&step=60"
            response = requests.get(
                f"{self.prometheus_url}/api/v1/{query}", timeout=10)

            if response.status_code != 200:
                return []

            data = response.json()
            if data['status'] != 'success' or not data['data']['result']:
                return []

            # Extract timestamp-value pairs from all result series and aggregate
            time_value_pairs = []
            for result in data['data']['result']:
                for timestamp, value in result['values']:
                    try:
                        time_value_pairs.append(
                            (float(timestamp), float(value)))
                    except (ValueError, TypeError):
                        continue

            return time_value_pairs

        except Exception as e:
            logger.debug(f"Error querying Prometheus for {metric}: {e}")
            return []

    def _align_time_series(self, data1: List[Tuple[float, float]], data2: List[Tuple[float, float]]) -> Tuple[List[float], List[float]]:
        """Align two time series to have the same timestamps"""
        try:
            # Convert to dictionaries for easier lookup
            dict1 = {timestamp: value for timestamp, value in data1}
            dict2 = {timestamp: value for timestamp, value in data2}

            # Find common timestamps
            common_timestamps = set(dict1.keys()) & set(dict2.keys())

            if not common_timestamps:
                return [], []

            # Sort timestamps
            common_timestamps = sorted(common_timestamps)

            # Extract aligned values
            aligned_values1 = [dict1[ts] for ts in common_timestamps]
            aligned_values2 = [dict2[ts] for ts in common_timestamps]

            return aligned_values1, aligned_values2

        except Exception as e:
            logger.error(f"Error aligning time series: {e}")
            return [], []


# Initialize the correlation engine
correlation_engine = EventCorrelationEngine()


@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'event-correlation-engine',
        'version': '3.0.0',
        'analysis_running': correlation_engine.is_running,
        'prometheus_connected': _check_prometheus_connection(),
        'metrics_configured': {
            'transaction_metrics': len(correlation_engine.transaction_metrics),
            'database_metrics': len(correlation_engine.database_metrics),
            'cache_metrics': len(correlation_engine.cache_metrics),
            'message_queue_metrics': len(correlation_engine.message_queue_metrics),
            'security_metrics': len(correlation_engine.security_metrics),
            'infrastructure_metrics': len(correlation_engine.infrastructure_metrics),
            'total_metrics': len(correlation_engine.key_metrics)
        }
    })


@app.route('/correlations')
def get_correlations():
    """Get recent correlation analysis results"""
    limit = request.args.get('limit', 10, type=int)
    category_filter = request.args.get('category', None)

    filtered_history = correlation_engine.correlation_history[-limit:]

    if category_filter:
        for analysis in filtered_history:
            analysis['correlations'] = [
                corr for corr in analysis['correlations']
                if corr.get('category', 'unknown') == category_filter
            ]

    return jsonify({
        'correlations': filtered_history,
        'total_analyses': len(correlation_engine.correlation_history),
        'filter_applied': category_filter
    })


@app.route('/correlations/latest')
def get_latest_correlations():
    """Get the most recent correlation analysis"""
    if not correlation_engine.correlation_history:
        return jsonify({'message': 'No correlation analysis available yet'})

    return jsonify(correlation_engine.correlation_history[-1])


@app.route('/correlations/business')
def get_business_correlations():
    """Get only business service correlations"""
    if not correlation_engine.correlation_history:
        return jsonify({'message': 'No correlation analysis available yet'})

    latest_analysis = correlation_engine.correlation_history[-1]
    business_correlations = [
        corr for corr in latest_analysis['correlations']
        if corr.get('category') == 'business'
    ]

    return jsonify({
        'timestamp': latest_analysis['timestamp'],
        'business_correlations': business_correlations,
        'count': len(business_correlations)
    })


@app.route('/correlations/summary')
def get_correlation_summary():
    """Get correlation analysis summary statistics"""
    if not correlation_engine.correlation_history:
        return jsonify({'message': 'No correlation analysis available yet'})

    latest_analysis = correlation_engine.correlation_history[-1]

    # Calculate summary statistics
    correlations = latest_analysis['correlations']

    summary = {
        'timestamp': latest_analysis['timestamp'],
        'total_correlations': len(correlations),
        'by_category': {},
        'by_confidence': {
            'high_confidence_80_plus': len([c for c in correlations if c['confidence'] > 0.8]),
            'medium_confidence_60_80': len([c for c in correlations if 0.6 <= c['confidence'] <= 0.8]),
            'low_confidence_below_60': len([c for c in correlations if c['confidence'] < 0.6])
        },
        'by_significance': {
            'high_significance': len([c for c in correlations if c.get('statistical_significance') == 'high']),
            'medium_significance': len([c for c in correlations if c.get('statistical_significance') == 'medium']),
            'low_significance': len([c for c in correlations if c.get('statistical_significance') == 'low'])
        },
        'business_impact_distribution': {}
    }

    # Count by category
    for correlation in correlations:
        category = correlation.get('category', 'unknown')
        summary['by_category'][category] = summary['by_category'].get(
            category, 0) + 1

        # Count by business impact
        impact = correlation.get('business_impact', 'unknown')
        impact_level = impact.split(' - ')[0] if ' - ' in impact else 'unknown'
        summary['business_impact_distribution'][impact_level] = summary['business_impact_distribution'].get(
            impact_level, 0) + 1

    return jsonify(summary)


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': 'text/plain'}


@app.route('/config')
def get_config():
    """Get current configuration"""
    return jsonify({
        'prometheus_url': correlation_engine.prometheus_url,
        'analysis_interval': correlation_engine.analysis_interval,
        'confidence_threshold': correlation_engine.confidence_threshold,
        'metrics_configuration': {
            'transaction_metrics': correlation_engine.transaction_metrics,
            'database_metrics': correlation_engine.database_metrics,
            'cache_metrics': correlation_engine.cache_metrics,
            'message_queue_metrics': correlation_engine.message_queue_metrics,
            'security_metrics': correlation_engine.security_metrics,
            'infrastructure_metrics': correlation_engine.infrastructure_metrics,
            'total_metrics': len(correlation_engine.key_metrics)
        }
    })


def _check_prometheus_connection():
    """Check if Prometheus is accessible"""
    try:
        response = requests.get(
            f"{correlation_engine.prometheus_url}/api/v1/targets", timeout=5)
        return response.status_code == 200
    except:
        return False


if __name__ == '__main__':
    # Start the correlation analysis loop
    correlation_engine.start_analysis_loop()

    # Start Flask app
    app.run(host='0.0.0.0', port=5025, debug=False)
