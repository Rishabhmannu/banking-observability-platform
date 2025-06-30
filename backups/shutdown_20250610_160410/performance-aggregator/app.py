from flask import Flask, jsonify, request, Response
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
import requests
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import threading
import time
import logging
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import IsolationForest

# Initialize Flask app
app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics for aggregation service
aggregation_calculations_total = Counter(
    'aggregation_calculations_total',
    'Total number of aggregation calculations performed'
)

aggregation_processing_time = Histogram(
    'aggregation_processing_time_seconds',
    'Time taken to process aggregations',
    buckets=(0.1, 0.5, 1.0, 2.5, 5.0, 10.0)
)

transaction_performance_score = Gauge(
    'transaction_performance_score',
    'Composite transaction performance score',
    ['category']
)

peak_transaction_rate = Gauge(
    'peak_transaction_rate',
    'Peak transaction rate detected',
    ['window']
)

avg_transactions_per_user = Gauge(
    'avg_transactions_per_user',
    'Average transactions per user'
)

business_hour_transaction_rate = Gauge(
    'business_hour_transaction_rate',
    'Transaction rate during business hours'
)

off_hour_transaction_rate = Gauge(
    'off_hour_transaction_rate',
    'Transaction rate during off hours'
)

slo_compliance_percentage = Gauge(
    'slo_compliance_percentage',
    'SLO compliance percentage',
    ['slo_type']
)

anomaly_score = Gauge(
    'transaction_anomaly_score',
    'Anomaly score for transaction patterns'
)

# Configuration
PROMETHEUS_URL = "http://prometheus:9090"
TRANSACTION_MONITOR_URL = "http://transaction-monitor:5003"

# SLO Definitions
SLO_DEFINITIONS = {
    'response_time_p95': 0.5,  # 500ms
    'response_time_p99': 1.0,  # 1s
    'error_rate': 0.01,        # 1%
    'availability': 0.999      # 99.9%
}


class MetricsAggregator:
    def __init__(self):
        self.historical_data = []
        self.anomaly_detector = None
        self.lock = threading.Lock()

    def query_prometheus(self, query, time_range_minutes=60):
        """Query Prometheus for metrics with longer time range"""
        try:
            end_time = datetime.now()
            start_time = end_time - timedelta(minutes=time_range_minutes)

            url = f"{PROMETHEUS_URL}/api/v1/query_range"
            params = {
                'query': query,
                'start': start_time.timestamp(),
                'end': end_time.timestamp(),
                'step': '30s'
            }

            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()

            return response.json()
        except Exception as e:
            logger.error(f"Prometheus query failed: {e}")
            return None

    def get_transaction_monitor_stats(self):
        """Get stats from transaction monitor service"""
        try:
            response = requests.get(
                f"{TRANSACTION_MONITOR_URL}/stats", timeout=5)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Failed to get transaction monitor stats: {e}")
            return {}

    def calculate_business_hours_metrics(self):
        """Calculate metrics split by business hours"""
        current_hour = datetime.now().hour
        is_business_hour = 9 <= current_hour < 17  # 9 AM to 5 PM

        # Query transaction rates
        query = 'sum(rate(transaction_requests_total[5m])) * 60'
        result = self.query_prometheus(query, time_range_minutes=30)

        if result and result.get('status') == 'success' and result['data']['result']:
            values = result['data']['result'][0]['values']
            rates = [float(v[1]) for _, v in values]

            if rates:
                current_rate = rates[-1]
                if is_business_hour:
                    business_hour_transaction_rate.set(current_rate)
                else:
                    off_hour_transaction_rate.set(current_rate)

    def calculate_peak_metrics(self):
        """Calculate peak transaction rates"""
        windows = {
            '1h': 60,
            '24h': 1440,
            '7d': 10080
        }

        for window_name, minutes in windows.items():
            query = 'sum(rate(transaction_requests_total[1m])) * 60'
            result = self.query_prometheus(query, time_range_minutes=minutes)

            if result and result.get('status') == 'success' and result['data']['result']:
                values = result['data']['result'][0]['values']
                rates = [float(v[1]) for _, v in values]

                if rates:
                    peak_rate = max(rates)
                    peak_transaction_rate.labels(
                        window=window_name).set(peak_rate)

    def calculate_slo_compliance(self):
        """Calculate SLO compliance metrics"""
        start_time = time.time()

        # Response time SLO
        p95_query = 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))'
        p95_result = self.query_prometheus(p95_query, time_range_minutes=60)

        if p95_result and p95_result.get('status') == 'success' and p95_result['data']['result']:
            values = p95_result['data']['result'][0]['values']
            p95_values = [float(v[1]) for _, v in values]

            compliant_count = sum(
                1 for v in p95_values if v <= SLO_DEFINITIONS['response_time_p95'])
            compliance_pct = (compliant_count / len(p95_values)
                              ) * 100 if p95_values else 0
            slo_compliance_percentage.labels(
                slo_type='response_time_p95').set(compliance_pct)

        # Error rate SLO
        error_query = 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'
        error_result = self.query_prometheus(
            error_query, time_range_minutes=60)

        if error_result and error_result.get('status') == 'success' and error_result['data']['result']:
            values = error_result['data']['result'][0]['values']
            error_rates = [float(v[1]) for _, v in values if v[1] != 'NaN']

            if error_rates:
                compliant_count = sum(
                    1 for v in error_rates if v <= SLO_DEFINITIONS['error_rate'])
                compliance_pct = (compliant_count / len(error_rates)) * 100
                slo_compliance_percentage.labels(
                    slo_type='error_rate').set(compliance_pct)

        # Availability SLO
        availability_query = 'avg_over_time(up{job="banking-services"}[5m])'
        availability_result = self.query_prometheus(
            availability_query, time_range_minutes=60)

        if availability_result and availability_result.get('status') == 'success':
            # Calculate average availability across all services
            availabilities = []
            for service in availability_result['data']['result']:
                values = service['values']
                if values:
                    avg_availability = np.mean(
                        [float(v[1]) for _, v in values])
                    availabilities.append(avg_availability)

            if availabilities:
                overall_availability = np.mean(availabilities)
                compliance_pct = 100 if overall_availability >= SLO_DEFINITIONS['availability'] else (
                    overall_availability * 100)
                slo_compliance_percentage.labels(
                    slo_type='availability').set(compliance_pct)

        processing_time = time.time() - start_time
        aggregation_processing_time.observe(processing_time)
        aggregation_calculations_total.inc()

    def detect_anomalies(self):
        """Detect anomalies in transaction patterns"""
        try:
            # Collect features for anomaly detection
            features = []

            # Transaction rate
            rate_query = 'sum(rate(transaction_requests_total[5m])) * 60'
            rate_result = self.query_prometheus(
                rate_query, time_range_minutes=120)

            if rate_result and rate_result.get('status') == 'success' and rate_result['data']['result']:
                values = rate_result['data']['result'][0]['values']
                rates = [float(v[1]) for _, v in values]

                # Response times
                latency_query = 'avg(http_request_duration_seconds)'
                latency_result = self.query_prometheus(
                    latency_query, time_range_minutes=120)

                if latency_result and latency_result.get('status') == 'success' and latency_result['data']['result']:
                    latency_values = latency_result['data']['result'][0]['values']
                    latencies = [float(v[1]) for _, v in latency_values]

                    # Create feature vectors
                    min_len = min(len(rates), len(latencies))
                    for i in range(min_len):
                        features.append([rates[i], latencies[i]])

                    if len(features) > 10:
                        # Train or update anomaly detector
                        features_array = np.array(features)

                        if self.anomaly_detector is None:
                            self.anomaly_detector = IsolationForest(
                                contamination=0.1, random_state=42)
                            self.anomaly_detector.fit(features_array)

                        # Detect anomalies in recent data
                        recent_features = features_array[-10:]
                        anomaly_scores = self.anomaly_detector.score_samples(
                            recent_features)

                        # Convert to 0-1 range (higher is more anomalous)
                        normalized_scores = 1 - (anomaly_scores - anomaly_scores.min()) / (
                            anomaly_scores.max() - anomaly_scores.min() + 1e-10)
                        current_anomaly_score = float(normalized_scores[-1])

                        anomaly_score.set(current_anomaly_score)

        except Exception as e:
            logger.error(f"Error in anomaly detection: {e}")

    def calculate_performance_scores(self):
        """Calculate composite performance scores"""
        try:
            # Get various metrics
            metrics = {
                'response_time': self.query_prometheus('avg(http_request_duration_seconds)'),
                'error_rate': self.query_prometheus('sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'),
                'throughput': self.query_prometheus('sum(rate(transaction_requests_total[5m])) * 60')
            }

            scores = {}

            # Response time score (lower is better)
            if metrics['response_time'] and metrics['response_time'].get('status') == 'success' and metrics['response_time']['data']['result']:
                values = metrics['response_time']['data']['result'][0]['values']
                if values:
                    avg_response_time = float(values[-1][1])
                    # Score: 100 for <100ms, 0 for >2s
                    scores['latency'] = max(
                        0, min(100, 100 * (2 - avg_response_time) / 1.9))

            # Error rate score (lower is better)
            if metrics['error_rate'] and metrics['error_rate'].get('status') == 'success' and metrics['error_rate']['data']['result']:
                values = metrics['error_rate']['data']['result'][0]['values']
                if values and values[-1][1] != 'NaN':
                    error_rate = float(values[-1][1])
                    # Score: 100 for 0%, 0 for 10%+
                    scores['reliability'] = max(
                        0, min(100, 100 * (1 - error_rate * 10)))

            # Throughput score (higher is better, relative to baseline)
            if metrics['throughput'] and metrics['throughput'].get('status') == 'success' and metrics['throughput']['data']['result']:
                values = metrics['throughput']['data']['result'][0]['values']
                if values:
                    current_throughput = float(values[-1][1])
                    # Assume baseline of 100 req/min
                    scores['throughput'] = min(
                        100, (current_throughput / 100) * 100)

            # Set scores
            for category, score in scores.items():
                transaction_performance_score.labels(
                    category=category).set(score)

            # Overall score (weighted average)
            if scores:
                weights = {'latency': 0.4,
                           'reliability': 0.4, 'throughput': 0.2}
                overall_score = sum(scores.get(
                    k, 0) * weights.get(k, 0.33) for k in weights.keys())
                transaction_performance_score.labels(
                    category='overall').set(overall_score)

        except Exception as e:
            logger.error(f"Error calculating performance scores: {e}")


aggregator = MetricsAggregator()


def background_aggregation():
    """Background thread for continuous aggregation"""
    while True:
        try:
            logger.info("Running aggregation cycle...")

            # Run various aggregations
            aggregator.calculate_business_hours_metrics()
            aggregator.calculate_peak_metrics()
            aggregator.calculate_slo_compliance()
            aggregator.detect_anomalies()
            aggregator.calculate_performance_scores()

            # Simulate user metrics (in real system, this would come from actual user data)
            avg_transactions_per_user.set(np.random.uniform(5, 15))

            time.sleep(30)  # Run every 30 seconds

        except Exception as e:
            logger.error(f"Error in background aggregation: {e}")
            time.sleep(60)


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'performance-aggregator',
        'timestamp': datetime.now().isoformat(),
        'anomaly_detector_trained': aggregator.anomaly_detector is not None
    })


@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(REGISTRY), mimetype='text/plain; version=0.0.4; charset=utf-8')

@app.route('/aggregated-stats', methods=['GET'])
def get_aggregated_stats():
    """Get current aggregated statistics"""
    try:
        # Collect current values
        stats = {
            'slo_compliance': {},
            'peak_rates': {},
            'performance_scores': {},
            'anomaly_detection': {
                'trained': aggregator.anomaly_detector is not None,
                'current_score': anomaly_score._value.get() if hasattr(anomaly_score, '_value') else 0
            }
        }

        # Get metric values (simplified for demo)
        stats['timestamp'] = datetime.now().isoformat()

        return jsonify(stats)

    except Exception as e:
        logger.error(f"Error getting aggregated stats: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/trigger-calculation', methods=['POST'])
def trigger_calculation():
    """Manually trigger aggregation calculations"""
    try:
        calculation_type = request.json.get('type', 'all')

        if calculation_type == 'slo' or calculation_type == 'all':
            aggregator.calculate_slo_compliance()

        if calculation_type == 'anomaly' or calculation_type == 'all':
            aggregator.detect_anomalies()

        if calculation_type == 'performance' or calculation_type == 'all':
            aggregator.calculate_performance_scores()

        return jsonify({
            'status': 'triggered',
            'type': calculation_type,
            'timestamp': datetime.now().isoformat()
        })

    except Exception as e:
        logger.error(f"Error triggering calculation: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    # Start background aggregation thread
    aggregation_thread = threading.Thread(
        target=background_aggregation, daemon=True)
    aggregation_thread.start()

    logger.info("Performance Aggregator starting on port 5004")
    app.run(host='0.0.0.0', port=5004, debug=False)
