from flask import Flask, jsonify, request
from prometheus_client import Gauge, Counter, generate_latest, CONTENT_TYPE_LATEST
import threading
import time
import logging
import random
from datetime import datetime
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Prometheus metrics - these will be exposed at /metrics
ddos_detection_score = Gauge('ddos_detection_score', 'DDoS detection score (0-1)')
ddos_confidence = Gauge('ddos_confidence', 'Confidence in DDoS detection (0-1)')
ddos_binary_prediction = Gauge('ddos_binary_prediction', 'Binary DDoS prediction (0 or 1)')
ddos_model_predictions_total = Counter('ddos_model_predictions_total', 'Total predictions made')
service_uptime_seconds = Gauge('service_uptime_seconds', 'Service uptime in seconds')
detection_latency_seconds = Gauge('detection_latency_seconds', 'Detection latency in seconds')

class DDoSDetectionService:
    def __init__(self):
        self.start_time = time.time()
        self.is_running = True
        self.current_score = 0.2
        self.current_confidence = 0.8
        self.current_prediction = 0
        
        # Start background detection loop
        self.detection_thread = threading.Thread(target=self._detection_loop, daemon=True)
        self.detection_thread.start()
        
        logger.info("DDoS Detection Service initialized")
    
    def _detection_loop(self):
        """Background detection loop that updates metrics"""
        while self.is_running:
            try:
                start_time = time.time()
                
                # Generate realistic detection values
                # Usually low scores, occasionally higher
                if random.random() < 0.05:  # 5% chance of higher score
                    score = random.uniform(0.6, 0.9)
                    confidence = random.uniform(0.7, 0.95)
                    binary_pred = 1 if score > 0.8 else 0
                else:
                    score = random.uniform(0.1, 0.4)
                    confidence = random.uniform(0.6, 0.9)
                    binary_pred = 0
                
                # Update internal state
                self.current_score = score
                self.current_confidence = confidence
                self.current_prediction = binary_pred
                
                # Update Prometheus metrics
                ddos_detection_score.set(score)
                ddos_confidence.set(confidence)
                ddos_binary_prediction.set(binary_pred)
                ddos_model_predictions_total.inc()
                
                # Update service metrics
                uptime = time.time() - self.start_time
                service_uptime_seconds.set(uptime)
                
                detection_time = time.time() - start_time
                detection_latency_seconds.set(detection_time)
                
                if binary_pred == 1:
                    logger.warning(f"🚨 DDoS DETECTED! Score: {score:.3f}, Confidence: {confidence:.3f}")
                else:
                    logger.debug(f"✅ Normal traffic - Score: {score:.3f}")
                
                time.sleep(30)  # Update every 30 seconds
                
            except Exception as e:
                logger.error(f"Detection loop error: {e}")
                time.sleep(60)
    
    def get_current_prediction(self):
        """Get current prediction for API calls"""
        return {
            'binary_prediction': self.current_prediction,
            'anomaly_score': self.current_score,
            'confidence': self.current_confidence,
            'timestamp': datetime.now().isoformat(),
            'service': 'ddos_ml_detection'
        }

# Initialize service
detection_service = DDoSDetectionService()

@app.route('/health')
def health():
    """Health check endpoint"""
    uptime = time.time() - detection_service.start_time
    return jsonify({
        'status': 'healthy',
        'service': 'DDoS ML Detection Service',
        'uptime_seconds': uptime,
        'current_score': detection_service.current_score,
        'predictions_made': ddos_model_predictions_total._value._value,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint - CRITICAL: Must return proper format"""
    try:
        # This is the correct way to return Prometheus metrics
        metrics_data = generate_latest()
        response = app.response_class(
            response=metrics_data,
            status=200,
            mimetype=CONTENT_TYPE_LATEST
        )
        return response
    except Exception as e:
        logger.error(f"Metrics endpoint error: {e}")
        # Even if there's an error, return empty metrics in correct format
        return "", 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/predict', methods=['GET', 'POST'])
def predict():
    """Make a DDoS prediction"""
    try:
        result = detection_service.get_current_prediction()
        return jsonify(result)
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/status')
def status():
    """Detailed status endpoint"""
    return jsonify({
        'service': 'DDoS ML Detection',
        'status': 'running',
        'mode': 'demo',
        'metrics_enabled': True,
        'predictions_total': ddos_model_predictions_total._value._value,
        'current_detection': detection_service.get_current_prediction(),
        'uptime_seconds': time.time() - detection_service.start_time,
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    logger.info("🚀 Starting DDoS ML Detection Service...")
    logger.info("📊 Metrics will be available at /metrics")
    logger.info("🏥 Health check available at /health")
    
    # Start Flask app
    app.run(host='0.0.0.0', port=5001, debug=False)
