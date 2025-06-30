#!/usr/bin/env python3
"""
Simplified ML Detection Service for DDoS Detection
Works with existing Prometheus from banking-demo
"""

from flask import Flask, jsonify, request
from prometheus_client import Gauge, Counter, generate_latest
import threading
import time
import logging
import requests
import pandas as pd
import numpy as np
import joblib
import json
from datetime import datetime, timedelta
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Prometheus metrics
ddos_detection_score = Gauge('ddos_detection_score', 'ML-based DDoS detection score (0-1)')
ddos_confidence = Gauge('ddos_confidence', 'Confidence in DDoS detection (0-1)')
ddos_binary_prediction = Gauge('ddos_binary_prediction', 'Binary DDoS prediction (0 or 1)')
ml_service_requests = Counter('ml_service_requests_total', 'Total requests to ML service')

class SimpleDDoSDetector:
    def __init__(self):
        # Try to find Prometheus (could be on 9090 from banking-demo or 9091 standalone)
        self.prometheus_url = self._find_prometheus()
        self.model = None
        self.scaler = None
        self.is_model_loaded = False
        
        # Load model if available
        self._load_model()
        
        # Start detection loop if model is loaded
        if self.is_model_loaded:
            self.detection_thread = threading.Thread(target=self._detection_loop, daemon=True)
            self.detection_thread.start()
            logger.info("🚀 ML Detection Service started!")
        else:
            logger.error("❌ Model not loaded - service running in demo mode")
    
    def _find_prometheus(self):
        """Find which port Prometheus is running on"""
        for port in [9090, 9091]:  # Try banking-demo first, then standalone
            try:
                url = f"http://localhost:{port}"
                response = requests.get(f"{url}/-/healthy", timeout=2)
                if response.status_code == 200:
                    logger.info(f"✅ Found Prometheus on port {port}")
                    return url
            except:
                continue
        
        logger.warning("⚠️ Prometheus not found, using default port 9090")
        return "http://localhost:9090"
    
    def _load_model(self):
        """Load model if available"""
        try:
            model_path = "data/models/isolation_forest_model.pkl"
            scaler_path = "data/models/feature_scaler.pkl"
            
            if os.path.exists(model_path) and os.path.exists(scaler_path):
                self.model = joblib.load(model_path)
                self.scaler = joblib.load(scaler_path)
                self.is_model_loaded = True
                logger.info("✅ Model loaded successfully")
            else:
                logger.warning("⚠️ Model files not found, running in demo mode")
                self.is_model_loaded = False
        except Exception as e:
            logger.error(f"❌ Failed to load model: {e}")
            self.is_model_loaded = False
    
    def _get_metrics_from_prometheus(self):
        """Get basic metrics from Prometheus"""
        try:
            # Simple metrics that should be available
            queries = {
                'request_rate': 'sum(rate(http_requests_total[1m]))',
                'error_rate': 'sum(rate(http_requests_total{status=~"5.."}[1m]))',
                'up_services': 'count(up == 1)'
            }
            
            metrics = {}
            for name, query in queries.items():
                try:
                    url = f"{self.prometheus_url}/api/v1/query"
                    response = requests.get(url, params={'query': query}, timeout=5)
                    data = response.json()
                    
                    if (data.get('status') == 'success' and 
                        data.get('data', {}).get('result')):
                        value = float(data['data']['result'][0]['value'][1])
                        metrics[name] = value
                    else:
                        metrics[name] = 0.0
                except:
                    metrics[name] = 0.0
            
            return metrics
        except Exception as e:
            logger.error(f"Failed to get Prometheus metrics: {e}")
            return {'request_rate': 0, 'error_rate': 0, 'up_services': 0}
    
    def _simple_anomaly_detection(self, metrics):
        """Simple rule-based anomaly detection (when ML model not available)"""
        request_rate = metrics.get('request_rate', 0)
        error_rate = metrics.get('error_rate', 0)
        
        # Simple thresholds (adjust based on your normal traffic)
        high_request_threshold = 100  # requests/second
        high_error_threshold = 10     # errors/second
        
        # Calculate anomaly score
        request_score = min(1.0, request_rate / high_request_threshold)
        error_score = min(1.0, error_rate / high_error_threshold)
        
        # Combined score
        anomaly_score = (request_score * 0.6 + error_score * 0.4)
        
        # Binary prediction
        binary_pred = 1 if anomaly_score > 0.7 else 0
        
        return {
            'binary_prediction': binary_pred,
            'anomaly_score': anomaly_score,
            'confidence': min(0.9, anomaly_score + 0.1),  # Simple confidence
            'method': 'rule_based'
        }
    
    def _ml_prediction(self, metrics):
        """ML-based prediction (when model is available)"""
        try:
            # Create simple feature vector
            features = np.array([
                metrics.get('request_rate', 0),
                metrics.get('error_rate', 0),
                metrics.get('up_services', 0),
                metrics.get('request_rate', 0) / max(1, metrics.get('up_services', 1))  # rate per service
            ]).reshape(1, -1)
            
            # Scale features
            features_scaled = self.scaler.transform(features)
            
            # Predict
            prediction = self.model.predict(features_scaled)[0]
            anomaly_score = abs(self.model.decision_function(features_scaled)[0])
            
            binary_pred = 1 if prediction == -1 else 0
            confidence = min(1.0, anomaly_score / 2)
            
            return {
                'binary_prediction': binary_pred,
                'anomaly_score': anomaly_score,
                'confidence': confidence,
                'method': 'machine_learning'
            }
        except Exception as e:
            logger.error(f"ML prediction failed: {e}")
            return self._simple_anomaly_detection(metrics)
    
    def predict(self):
        """Make prediction based on current metrics"""
        # Get metrics from Prometheus
        metrics = self._get_metrics_from_prometheus()
        
        # Choose prediction method
        if self.is_model_loaded:
            result = self._ml_prediction(metrics)
        else:
            result = self._simple_anomaly_detection(metrics)
        
        result['timestamp'] = datetime.now().isoformat()
        result['metrics'] = metrics
        
        return result
    
    def _detection_loop(self):
        """Continuous detection loop"""
        logger.info("🔄 Starting detection loop...")
        
        while True:
            try:
                result = self.predict()
                
                # Update Prometheus metrics
                ddos_binary_prediction.set(result['binary_prediction'])
                ddos_confidence.set(result['confidence'])
                ddos_detection_score.set(result['anomaly_score'])
                
                # Log significant detections
                if result['binary_prediction'] == 1:
                    logger.warning(
                        f"🚨 DDoS DETECTED! Score: {result['anomaly_score']:.3f}, "
                        f"Method: {result['method']}"
                    )
                else:
                    logger.debug(f"✅ Normal - Score: {result['anomaly_score']:.3f}")
                
                time.sleep(30)  # Check every 30 seconds
                
            except Exception as e:
                logger.error(f"Detection loop error: {e}")
                time.sleep(60)

# Initialize detector
detector = SimpleDDoSDetector()

@app.route('/predict', methods=['GET', 'POST'])
def predict():
    """Prediction endpoint"""
    ml_service_requests.inc()
    try:
        result = detector.predict()
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.route('/health')
def health():
    """Health check"""
    return jsonify({
        "status": "healthy",
        "model_loaded": detector.is_model_loaded,
        "prometheus_url": detector.prometheus_url,
        "timestamp": datetime.now().isoformat()
    })

@app.route('/status')
def status():
    """Detailed status"""
    try:
        # Test connectivity
        prometheus_ok = False
        try:
            response = requests.get(f"{detector.prometheus_url}/-/healthy", timeout=2)
            prometheus_ok = response.status_code == 200
        except:
            pass
        
        return jsonify({
            "service": "DDoS Detection ML Service",
            "status": "running",
            "model_loaded": detector.is_model_loaded,
            "prometheus": {
                "url": detector.prometheus_url,
                "connected": prometheus_ok
            },
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("🚀 Starting Simple DDoS Detection Service...")
    logger.info(f"Prometheus URL: {detector.prometheus_url}")
    logger.info(f"Model loaded: {detector.is_model_loaded}")
    app.run(host='0.0.0.0', port=5000, debug=False)