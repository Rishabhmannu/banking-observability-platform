from flask import Flask, jsonify, request, Response
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
import requests
import time
import logging
import threading
from datetime import datetime, timedelta
import numpy as np

# Initialize Flask app
app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# IMPORTANT: Define metrics at module level, not inside functions
# Prometheus metrics for transaction monitoring
transaction_requests_total = Counter(
    'transaction_requests_total',
    'Total number of transaction requests',
    ['type', 'status']
)

transaction_duration_seconds = Histogram(
    'transaction_duration_seconds',
    'Transaction processing duration in seconds',
    ['type'],
    buckets=(0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0)
)

transaction_failures_total = Counter(
    'transaction_failures_total',
    'Total number of failed transactions',
    ['type', 'error_code']
)

slow_transactions_total = Counter(
    'slow_transactions_total',
    'Total number of slow transactions',
    ['threshold', 'type']
)

transaction_requests_per_minute = Gauge(
    'transaction_requests_per_minute',
    'Transaction requests per minute',
    ['type']
)

transaction_avg_response_time = Gauge(
    'transaction_avg_response_time',
    'Average transaction response time in seconds',
    ['type']
)

slow_transaction_percentage = Gauge(
    'slow_transaction_percentage',
    'Percentage of slow transactions',
    ['threshold']
)

transaction_performance_score = Gauge(
    'transaction_performance_score',
    'Overall transaction performance score (0-100)'
)

transaction_health_status = Gauge(
    'transaction_health_status',
    'Transaction service health status',
    ['status']
)

# Initialize some metrics with default values
transaction_performance_score.set(100)
for status in ['healthy', 'degraded', 'critical']:
    transaction_health_status.labels(status=status).set(0)
transaction_health_status.labels(status='healthy').set(1)



# Configuration
PROMETHEUS_URL = "http://prometheus:9090"
BANKING_API_URL = "http://api-gateway:8080"
SLOW_THRESHOLDS = [0.5, 1.0, 2.0]  # seconds

# In-memory metrics storage for calculations


class MetricsStore:
    def __init__(self):
        self.transactions = []
        self.lock = threading.Lock()

    def add_transaction(self, type, duration, status, error_code=None):
        with self.lock:
            self.transactions.append({
                'type': type,
                'duration': duration,
                'status': status,
                'error_code': error_code,
                'timestamp': datetime.now()
            })
            # Keep only last hour of data
            cutoff = datetime.now() - timedelta(hours=1)
            self.transactions = [
                t for t in self.transactions if t['timestamp'] > cutoff]

    def get_stats(self):
        with self.lock:
            if not self.transactions:
                return {}

            # Calculate statistics
            recent = datetime.now() - timedelta(minutes=1)
            recent_transactions = [
                t for t in self.transactions if t['timestamp'] > recent]

            stats = {
                'total_count': len(recent_transactions),
                'failure_count': len([t for t in recent_transactions if t['status'] != 'success']),
                'avg_duration': np.mean([t['duration'] for t in recent_transactions]) if recent_transactions else 0,
                'slow_counts': {}
            }

            for threshold in SLOW_THRESHOLDS:
                slow_count = len(
                    [t for t in recent_transactions if t['duration'] > threshold])
                stats['slow_counts'][threshold] = slow_count

            return stats


metrics_store = MetricsStore()


def query_prometheus(query, time_range_minutes=5):
    """Query Prometheus for metrics"""
    try:
        end_time = datetime.now()
        start_time = end_time - timedelta(minutes=time_range_minutes)

        url = f"{PROMETHEUS_URL}/api/v1/query_range"
        params = {
            'query': query,
            'start': start_time.timestamp(),
            'end': end_time.timestamp(),
            'step': '15s'
        }

        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()

        return response.json()
    except Exception as e:
        logger.error(f"Prometheus query failed: {e}")
        return None


def monitor_transactions():
    """Background thread to monitor transaction metrics"""
    while True:
        try:
            # Query banking service metrics
            queries = {
                'request_rate': 'sum(rate(http_requests_total{job="banking-services"}[1m]))',
                'error_rate': 'sum(rate(http_requests_total{job="banking-services",status=~"5.."}[1m]))',
                'p95_latency': 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job="banking-services"}[1m])) by (le))'
            }

            for metric_name, query in queries.items():
                result = query_prometheus(query)
                if result and result.get('status') == 'success' and result['data']['result']:
                    try:
                        values = result['data']['result'][0]['values']
                        if values:
                            latest_value = float(values[-1][1])

                            # Simulate transaction monitoring based on real metrics
                            if metric_name == 'request_rate':
                                # Update requests per minute for different transaction types
                                types = ['deposit', 'withdrawal',
                                         'transfer', 'query']
                                for t in types:
                                    # Distribute requests across types
                                    type_rate = latest_value * 60 / len(types)
                                    transaction_requests_per_minute.labels(
                                        type=t).set(type_rate)

                            elif metric_name == 'p95_latency':
                                # Update average response time
                                for t in ['deposit', 'withdrawal', 'transfer', 'query']:
                                    # Add some variance for different transaction types
                                    variance = np.random.normal(1.0, 0.1)
                                    transaction_avg_response_time.labels(
                                        type=t).set(latest_value * variance)

                    except Exception as e:
                        logger.error(
                            f"Error processing metric {metric_name}: {e}")

            # Calculate performance score
            stats = metrics_store.get_stats()
            if stats:
                # Simple scoring algorithm (0-100)
                failure_rate = stats['failure_count'] / \
                    max(stats['total_count'], 1)
                slow_rate = stats['slow_counts'].get(
                    0.5, 0) / max(stats['total_count'], 1)

                score = 100 * (1 - failure_rate) * (1 - slow_rate)
                transaction_performance_score.set(max(0, min(100, score)))

                # Update slow transaction percentage
                for threshold in SLOW_THRESHOLDS:
                    percentage = (stats['slow_counts'].get(
                        threshold, 0) / max(stats['total_count'], 1)) * 100
                    slow_transaction_percentage.labels(
                        threshold=f"{threshold}s").set(percentage)

                # Update health status
                if score >= 90:
                    transaction_health_status.labels(status='healthy').set(1)
                    transaction_health_status.labels(status='degraded').set(0)
                    transaction_health_status.labels(status='critical').set(0)
                elif score >= 70:
                    transaction_health_status.labels(status='healthy').set(0)
                    transaction_health_status.labels(status='degraded').set(1)
                    transaction_health_status.labels(status='critical').set(0)
                else:
                    transaction_health_status.labels(status='healthy').set(0)
                    transaction_health_status.labels(status='degraded').set(0)
                    transaction_health_status.labels(status='critical').set(1)

            time.sleep(15)  # Update every 15 seconds

        except Exception as e:
            logger.error(f"Error in monitor_transactions: {e}")
            time.sleep(30)


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'transaction-performance-monitor',
        'timestamp': datetime.now().isoformat()
    })


@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(REGISTRY), mimetype='text/plain; version=0.0.4; charset=utf-8')

@app.route('/simulate-transaction', methods=['POST'])
def simulate_transaction():
    """Endpoint to simulate a transaction for testing"""
    data = request.json or {}

    transaction_type = data.get('type', 'transfer')
    duration = data.get('duration', np.random.uniform(0.1, 0.5))
    status = data.get('status', 'success')
    error_code = data.get('error_code', None)

    # Record metrics
    transaction_requests_total.labels(
        type=transaction_type, status=status).inc()
    transaction_duration_seconds.labels(
        type=transaction_type).observe(duration)

    if status != 'success':
        transaction_failures_total.labels(
            type=transaction_type, error_code=error_code or 'unknown').inc()

    # Check for slow transactions
    for threshold in SLOW_THRESHOLDS:
        if duration > threshold:
            slow_transactions_total.labels(
                threshold=f"{threshold}s", type=transaction_type).inc()

    # Store in memory
    metrics_store.add_transaction(
        transaction_type, duration, status, error_code)

    return jsonify({
        'status': 'recorded',
        'transaction': {
            'type': transaction_type,
            'duration': duration,
            'status': status
        }
    })


@app.route('/stats', methods=['GET'])
def get_stats():
    """Get current statistics"""
    stats = metrics_store.get_stats()
    return jsonify(stats)


def initialize_metrics():
    """Initialize all metrics with zero values so they appear in /metrics"""
    # Initialize counters
    for t in ['deposit', 'withdrawal', 'transfer', 'query']:
        for s in ['success', 'error']:
            transaction_requests_total.labels(type=t, status=s).inc(0)

        transaction_requests_per_minute.labels(type=t).set(0)
        transaction_avg_response_time.labels(type=t).set(0)

    # Initialize slow transaction percentages
    for threshold in ['0.5s', '1.0s', '2.0s']:
        slow_transaction_percentage.labels(threshold=threshold).set(0)

    logger.info("Metrics initialized")


# Call this before starting the Flask app
if __name__ == '__main__':
    # Initialize metrics
    initialize_metrics()

    # Start monitoring thread
    monitor_thread = threading.Thread(target=monitor_transactions, daemon=True)
    monitor_thread.start()

    logger.info("Transaction Performance Monitor starting on port 5003")
    app.run(host='0.0.0.0', port=5003, debug=False)
