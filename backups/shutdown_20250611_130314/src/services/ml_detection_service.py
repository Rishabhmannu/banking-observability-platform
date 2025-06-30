# src/services/ml_detection_service.py
from datetime import datetime, timedelta
import json
import joblib
import numpy as np
import pandas as pd
import requests
import logging
import time
import threading
from prometheus_client import Gauge, Counter, Histogram, generate_latest
from flask import Flask, jsonify, request
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))))


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Prometheus metrics that our ML service will expose
ddos_detection_score = Gauge(
    'ddos_detection_score', 'ML-based DDoS detection score (0-1)')
ddos_confidence = Gauge(
    'ddos_confidence', 'Confidence in DDoS detection (0-1)')
ddos_binary_prediction = Gauge(
    'ddos_binary_prediction', 'Binary DDoS prediction (0 or 1)')
ddos_detection_latency = Histogram(
    'ddos_detection_latency_seconds', 'Time taken for DDoS detection')
ddos_model_predictions_total = Counter(
    'ddos_model_predictions_total', 'Total number of predictions made')
prometheus_query_errors = Counter(
    'prometheus_query_errors_total', 'Failed Prometheus queries')


class BankingDDoSDetector:
    def __init__(self, prometheus_url="http://localhost:9090"):
        self.prometheus_url = prometheus_url
        self.model = None
        self.scaler = None
        self.feature_columns = None
        self.model_metadata = None
        self.is_model_loaded = False

        # Load the trained model
        self._load_model()

        # Start background detection loop
        if self.is_model_loaded:
            self.detection_thread = threading.Thread(
                target=self._detection_loop, daemon=True)
            self.detection_thread.start()
            logger.info("🚀 ML Detection Service started successfully!")
        else:
            logger.error(
                "❌ Failed to load model - service will not start detection loop")

    def _load_model(self):
        """Load the trained ML model and associated files"""
        try:
            model_dir = "data/models"

            # Load model
            self.model = joblib.load(f"{model_dir}/isolation_forest_model.pkl")
            logger.info("✅ Isolation Forest model loaded")

            # Load scaler
            self.scaler = joblib.load(f"{model_dir}/feature_scaler.pkl")
            logger.info("✅ Feature scaler loaded")

            # Load metadata
            with open(f"{model_dir}/model_metadata.json", 'r') as f:
                self.model_metadata = json.load(f)

            self.feature_columns = self.model_metadata['feature_columns']
            logger.info(
                f"✅ Model metadata loaded - {len(self.feature_columns)} features")

            self.is_model_loaded = True

        except Exception as e:
            logger.error(f"❌ Failed to load model: {e}")
            self.is_model_loaded = False

    def _query_prometheus(self, query, time_range_minutes=15):
        """Query Prometheus for metrics"""
        try:
            end_time = datetime.now()
            start_time = end_time - timedelta(minutes=time_range_minutes)

            url = f"{self.prometheus_url}/api/v1/query_range"
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
            logger.error(f"Prometheus query failed for '{query}': {e}")
            prometheus_query_errors.inc()
            return None

    def _collect_banking_metrics(self):
        """Collect banking metrics from Prometheus"""
        # Define the Prometheus queries for banking metrics
        # These should match your banking microservices setup
        metrics_queries = {
            'api_request_rate': 'sum(rate(http_requests_total[1m]))',
            'api_error_rate': 'sum(rate(http_requests_total{status=~"5.."}[1m]))',
            'api_response_time_p50': 'histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))',
            'api_response_time_p95': 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))',
            'api_response_time_p99': 'histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))',
            'cpu_usage_percent': 'avg(100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100))',
            'memory_usage_percent': 'avg((1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100)',
            'network_bytes_in': 'sum(rate(node_network_receive_bytes_total[1m]))',
            'network_bytes_out': 'sum(rate(node_network_transmit_bytes_total[1m]))',
            'active_connections': 'sum(node_netstat_Tcp_CurrEstab)',
        }

        # Additional banking-specific metrics (if available)
        banking_queries = {
            'auth_request_rate': 'sum(rate(banking_auth_requests_total[1m]))',
            'transaction_request_rate': 'sum(rate(banking_transaction_requests_total[1m]))',
            'account_query_rate': 'sum(rate(banking_account_queries_total[1m]))',
            'concurrent_users': 'sum(banking_active_users)',
            'failed_authentication_rate': 'sum(rate(banking_failed_auth_total[1m]))',
        }

        all_queries = {**metrics_queries, **banking_queries}
        collected_data = {}

        for metric_name, query in all_queries.items():
            result = self._query_prometheus(query)
            if result and result.get('status') == 'success' and result['data']['result']:
                # Parse the result and get the most recent value
                try:
                    latest_value = float(
                        result['data']['result'][0]['values'][-1][1])
                    collected_data[metric_name] = latest_value
                except (IndexError, ValueError, KeyError):
                    logger.warning(f"Could not parse result for {metric_name}")
                    collected_data[metric_name] = 0.0
            else:
                # Set default values if metric not available
                collected_data[metric_name] = 0.0

        return collected_data

    def _engineer_features(self, raw_metrics):
        """Engineer features similar to training data"""
        # Convert to DataFrame for feature engineering
        df = pd.DataFrame([raw_metrics])

        # Add basic derived features that the model expects
        # Note: For real-time detection, we simulate some features that require historical data

        # Rate of change features (using simple approximation)
        for col in ['api_request_rate', 'api_error_rate', 'cpu_usage_percent', 'memory_usage_percent']:
            if col in df.columns:
                # Would need historical data for real calculation
                df[f'{col}_change_1min'] = 0.0
                df[f'{col}_change_5min'] = 0.0

        # Rolling statistics (using current values as approximation)
        windows = [5, 15, 30]
        for window in windows:
            for col in ['api_request_rate', 'api_error_rate', 'api_response_time_p95']:
                if col in df.columns:
                    df[f'{col}_rolling_mean_{window}'] = df[col]
                    df[f'{col}_rolling_std_{window}'] = df[col] * \
                        0.1  # Simple approximation
                    df[f'{col}_rolling_max_{window}'] = df[col]
                    # Would need historical data
                    df[f'{col}_zscore_{window}'] = 0.0

        # Ratio features
        if 'api_error_rate' in df.columns and 'api_request_rate' in df.columns:
            df['error_to_request_ratio'] = df['api_error_rate'] / \
                (df['api_request_rate'] + 1e-8)

        if 'network_bytes_in' in df.columns and 'network_bytes_out' in df.columns:
            df['network_in_to_out_ratio'] = df['network_bytes_in'] / \
                (df['network_bytes_out'] + 1e-8)

        if 'auth_request_rate' in df.columns and 'api_request_rate' in df.columns:
            df['auth_to_total_ratio'] = df['auth_request_rate'] / \
                (df['api_request_rate'] + 1e-8)

        # Composite indicators
        if all(col in df.columns for col in ['cpu_usage_percent', 'memory_usage_percent', 'api_response_time_p95']):
            df['infrastructure_stress'] = (
                df['cpu_usage_percent'] / 100 * 0.4 +
                df['memory_usage_percent'] / 100 * 0.3 +
                df['api_response_time_p95'] / 1000 * 0.3
            )

        # Traffic anomaly score (simplified)
        df['traffic_anomaly_score'] = df.get('error_to_request_ratio', 0) * 0.5

        return df

    def predict_ddos(self, raw_metrics):
        """Make DDoS prediction from raw metrics"""
        if not self.is_model_loaded:
            return None

        try:
            with ddos_detection_latency.time():
                # Engineer features
                feature_df = self._engineer_features(raw_metrics)

                # Select only the features that the model was trained on
                available_features = []
                feature_values = []

                for feature in self.feature_columns:
                    if feature in feature_df.columns:
                        available_features.append(feature)
                        value = feature_df[feature].iloc[0]
                        # Handle NaN and infinite values
                        if pd.isna(value) or np.isinf(value):
                            value = 0.0
                        feature_values.append(value)
                    else:
                        # Feature not available, use 0 as default
                        available_features.append(feature)
                        feature_values.append(0.0)

                # Create feature matrix
                X = np.array(feature_values).reshape(1, -1)

                # Scale features
                X_scaled = self.scaler.transform(X)

                # Make prediction
                prediction = self.model.predict(X_scaled)[0]
                anomaly_score = self.model.decision_function(X_scaled)[0]

                # Convert to binary prediction (0=normal, 1=attack)
                binary_pred = 1 if prediction == -1 else 0

                # Convert anomaly score to confidence (0-1 range)
                # Isolation Forest returns negative scores for anomalies
                # Normalize to 0-1
                confidence = max(0, min(1, abs(anomaly_score) / 2))

                # Update counters
                ddos_model_predictions_total.inc()

                return {
                    'binary_prediction': binary_pred,
                    'anomaly_score': float(anomaly_score),
                    'confidence': confidence,
                    'timestamp': datetime.now().isoformat(),
                    'features_used': len(available_features)
                }

        except Exception as e:
            logger.error(f"Prediction error: {e}")
            return None

    def _detection_loop(self):
        """Continuous detection loop"""
        logger.info("🔄 Starting continuous DDoS detection loop...")

        while True:
            try:
                # Collect metrics from Prometheus
                raw_metrics = self._collect_banking_metrics()

                if raw_metrics:
                    # Make prediction
                    result = self.predict_ddos(raw_metrics)

                    if result:
                        # Update Prometheus metrics
                        ddos_binary_prediction.set(result['binary_prediction'])
                        ddos_confidence.set(result['confidence'])
                        ddos_detection_score.set(abs(result['anomaly_score']))

                        # Log significant detections
                        if result['binary_prediction'] == 1:
                            logger.warning(
                                f"🚨 DDoS DETECTED! Score: {result['anomaly_score']:.3f}, "
                                f"Confidence: {result['confidence']:.3f}"
                            )
                        else:
                            logger.debug(
                                f"✅ Normal traffic - Score: {result['anomaly_score']:.3f}")

                # Sleep for 30 seconds before next detection
                time.sleep(30)

            except Exception as e:
                logger.error(f"Error in detection loop: {e}")
                time.sleep(60)  # Wait longer on errors


# Initialize the detector
detector = BankingDDoSDetector()


@app.route('/predict', methods=['POST'])
def predict():
    """Manual prediction endpoint"""
    try:
        if not detector.is_model_loaded:
            return jsonify({"error": "Model not loaded"}), 503

        # Get metrics from request body or collect from Prometheus
        if request.json:
            raw_metrics = request.json
        else:
            raw_metrics = detector._collect_banking_metrics()

        result = detector.predict_ddos(raw_metrics)

        if result:
            return jsonify(result)
        else:
            return jsonify({"error": "Prediction failed"}), 500

    except Exception as e:
        logger.error(f"Prediction endpoint error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()


@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy" if detector.is_model_loaded else "unhealthy",
        "model_loaded": detector.is_model_loaded,
        "timestamp": datetime.now().isoformat(),
        "model_info": detector.model_metadata if detector.model_metadata else None
    })


@app.route('/status')
def status():
    """Detailed status endpoint"""
    try:
        # Test Prometheus connectivity
        test_query = detector._query_prometheus('up')
        prometheus_connected = test_query is not None

        return jsonify({
            "ml_service": {
                "status": "running",
                "model_loaded": detector.is_model_loaded,
                "features": len(detector.feature_columns) if detector.feature_columns else 0
            },
            "prometheus": {
                "connected": prometheus_connected,
                "url": detector.prometheus_url
            },
            "model_info": detector.model_metadata,
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    logger.info("🚀 Starting Banking DDoS Detection Service...")
    app.run(host='0.0.0.0', port=5000, debug=False)
