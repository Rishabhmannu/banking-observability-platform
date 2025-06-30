from flask import Flask, jsonify, request
from prometheus_client import Gauge, Counter, generate_latest, CONTENT_TYPE_LATEST
import threading
import time
import logging
import requests
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from sklearn.ensemble import IsolationForest
from sklearn.svm import OneClassSVM
import warnings
warnings.filterwarnings('ignore')

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Prometheus metrics
threshold_recommendations_total = Counter('threshold_recommendations_total', 'Total threshold recommendations generated')
algorithm_execution_time = Gauge('algorithm_execution_seconds', 'Time taken to execute algorithms', ['algorithm'])
active_metrics_count = Gauge('active_metrics_being_monitored', 'Number of metrics being actively monitored')

class AutoBaselineService:
    def __init__(self, prometheus_url="http://prometheus:9090"):
        self.prometheus_url = prometheus_url
        self.algorithms = {
            'rolling_statistics': self._rolling_statistics_threshold,
            'quantile_based': self._quantile_based_threshold,
            'isolation_forest': self._isolation_forest_threshold,
            'one_class_svm': self._svm_threshold
        }
        self.recommendations = {
            'api_request_rate': {},
            'api_error_rate': {},
            'api_response_time_p95': {},
            'cpu_usage_percent': {}
        }
        self.is_running = True
        
        # Start background processing
        self.processing_thread = threading.Thread(target=self._processing_loop, daemon=True)
        self.processing_thread.start()
        logger.info("Auto-baselining service initialized with 4 algorithms")
    
    def _query_prometheus(self, query, hours=1):
        """Query Prometheus for historical data"""
        try:
            end_time = datetime.now()
            start_time = end_time - timedelta(hours=hours)
            
            url = f"{self.prometheus_url}/api/v1/query_range"
            params = {
                'query': query,
                'start': start_time.timestamp(),
                'end': end_time.timestamp(),
                'step': '30s'
            }
            
            response = requests.get(url, params=params, timeout=10)
            if response.status_code == 200:
                data = response.json()
                if data['status'] == 'success' and data['data']['result']:
                    # Convert to pandas DataFrame
                    values = []
                    for series in data['data']['result']:
                        for timestamp, value in series['values']:
                            try:
                                values.append(float(value))
                            except ValueError:
                                continue
                    return np.array(values) if values else np.array([])
            return np.array([])
        except Exception as e:
            logger.error(f"Prometheus query failed: {e}")
            return np.array([])
    
    def _rolling_statistics_threshold(self, data):
        """Calculate threshold using rolling statistics"""
        if len(data) < 10:
            return None
        
        mean = np.mean(data)
        std = np.std(data)
        threshold = mean + (3 * std)  # 3-sigma rule
        
        return {
            'threshold': float(threshold),
            'method': 'rolling_statistics',
            'confidence': 0.85,
            'parameters': {'mean': float(mean), 'std': float(std)}
        }
    
    def _quantile_based_threshold(self, data):
        """Calculate threshold using quantiles"""
        if len(data) < 10:
            return None
        
        threshold = np.percentile(data, 95)  # 95th percentile
        
        return {
            'threshold': float(threshold),
            'method': 'quantile_based',
            'confidence': 0.90,
            'parameters': {'percentile': 95}
        }
    
    def _isolation_forest_threshold(self, data):
        """Calculate threshold using Isolation Forest"""
        if len(data) < 20:
            return None
        
        try:
            # Reshape data for sklearn
            X = data.reshape(-1, 1)
            
            # Fit Isolation Forest
            iso_forest = IsolationForest(contamination=0.1, random_state=42)
            predictions = iso_forest.fit_predict(X)
            
            # Find threshold at boundary between normal and anomalous
            scores = iso_forest.decision_function(X)
            threshold_idx = np.where(predictions == -1)[0]
            
            if len(threshold_idx) > 0:
                threshold = float(np.min(data[threshold_idx]))
            else:
                threshold = float(np.percentile(data, 90))
            
            return {
                'threshold': threshold,
                'method': 'isolation_forest',
                'confidence': 0.80,
                'parameters': {'contamination': 0.1}
            }
        except Exception as e:
            logger.error(f"Isolation Forest error: {e}")
            return None
    
    def _svm_threshold(self, data):
        """Calculate threshold using One-Class SVM"""
        if len(data) < 20:
            return None
        
        try:
            # Reshape data for sklearn
            X = data.reshape(-1, 1)
            
            # Fit One-Class SVM
            svm = OneClassSVM(nu=0.1, kernel="rbf", gamma='scale')
            predictions = svm.fit_predict(X)
            
            # Find threshold
            anomaly_indices = np.where(predictions == -1)[0]
            if len(anomaly_indices) > 0:
                threshold = float(np.min(data[anomaly_indices]))
            else:
                threshold = float(np.percentile(data, 88))
            
            return {
                'threshold': threshold,
                'method': 'one_class_svm',
                'confidence': 0.75,
                'parameters': {'nu': 0.1, 'kernel': 'rbf'}
            }
        except Exception as e:
            logger.error(f"SVM error: {e}")
            return None
    
    def _processing_loop(self):
        """Background processing loop"""
        while self.is_running:
            try:
                self._update_recommendations()
                time.sleep(60)  # Update every minute
            except Exception as e:
                logger.error(f"Processing loop error: {e}")
                time.sleep(30)
    
    def _update_recommendations(self):
        """Update threshold recommendations for all metrics"""
        metrics_queries = {
            'api_request_rate': 'sum(rate(http_requests_total[1m]))',
            'api_error_rate': 'sum(rate(http_requests_total{status=~"5.."}[1m]))',
            'api_response_time_p95': 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))',
            'cpu_usage_percent': 'avg(100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100))'
        }
        
        for metric_name, query in metrics_queries.items():
            data = self._query_prometheus(query, hours=2)
            
            if len(data) > 0:
                # Apply all algorithms
                metric_recommendations = {}
                for algo_name, algo_func in self.algorithms.items():
                    start_time = time.time()
                    result = algo_func(data)
                    execution_time = time.time() - start_time
                    
                    algorithm_execution_time.labels(algorithm=algo_name).set(execution_time)
                    
                    if result:
                        metric_recommendations[algo_name] = result
                
                self.recommendations[metric_name] = metric_recommendations
                threshold_recommendations_total.inc()
        
        active_metrics_count.set(len([r for r in self.recommendations.values() if r]))

# Initialize service
baseline_service = AutoBaselineService()

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'algorithms': list(baseline_service.algorithms.keys()),
        'recommendations_count': len([r for r in baseline_service.recommendations.values() if r]),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint - FIXED"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/threshold-recommendations')
def get_recommendations():
    """Get current threshold recommendations"""
    return jsonify({
        'recommendations': baseline_service.recommendations,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/calculate-threshold')
def calculate_threshold():
    """Calculate threshold for a specific metric"""
    metric_query = request.args.get('metric', '')
    
    if not metric_query:
        return jsonify({'error': 'No metric specified'}), 400
    
    try:
        # Get data from Prometheus
        data = baseline_service._query_prometheus(metric_query, hours=1)
        
        if len(data) == 0:
            return jsonify({'error': 'No data available for metric'}), 404
        
        # Calculate thresholds using all algorithms
        results = {}
        for algo_name, algo_func in baseline_service.algorithms.items():
            result = algo_func(data)
            if result:
                results[algo_name] = result
        
        return jsonify({
            'metric': metric_query,
            'data_points': len(data),
            'thresholds': results,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Threshold calculation error: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting Auto-Baselining Service...")
    app.run(host='0.0.0.0', port=5002, debug=False)
