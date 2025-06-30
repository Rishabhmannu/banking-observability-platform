#!/usr/bin/env python3
"""
Minimal ML Detection Service - Just to get things working
Uses port 5001 to avoid macOS AirPlay conflict on port 5000
"""

from flask import Flask, jsonify
import random
from datetime import datetime
import threading
import time

app = Flask(__name__)

# Simple global variables to simulate detection
current_prediction = 0
current_score = 0.0
current_confidence = 0.0


def detection_loop():
    """Simple detection loop that generates random values"""
    global current_prediction, current_score, current_confidence

    while True:
        try:
            # Generate some random but realistic values
            current_score = random.uniform(0.0, 1.0)
            current_confidence = random.uniform(0.5, 0.9)

            # Simple threshold for binary prediction
            current_prediction = 1 if current_score > 0.7 else 0

            # Log if attack detected
            if current_prediction == 1:
                print(
                    f"🚨 SIMULATED ATTACK DETECTED! Score: {current_score:.3f}")
            else:
                print(f"✅ Normal traffic - Score: {current_score:.3f}")

            time.sleep(30)  # Check every 30 seconds

        except Exception as e:
            print(f"Detection loop error: {e}")
            time.sleep(60)


# Start detection loop in background
detection_thread = threading.Thread(target=detection_loop, daemon=True)
detection_thread.start()


@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "Minimal DDoS Detection Service",
        "port": 5001,
        "timestamp": datetime.now().isoformat(),
        "message": "Service is running in demo mode"
    })


@app.route('/predict')
def predict():
    """Prediction endpoint"""
    return jsonify({
        "binary_prediction": current_prediction,
        "anomaly_score": current_score,
        "confidence": current_confidence,
        "timestamp": datetime.now().isoformat(),
        "method": "demo_random",
        "message": "This is a demo prediction"
    })


@app.route('/status')
def status():
    """Status endpoint"""
    return jsonify({
        "service": "Minimal DDoS Detection Service",
        "status": "running",
        "port": 5001,
        "mode": "demo",
        "current_prediction": current_prediction,
        "current_score": current_score,
        "prometheus_integration": "not_connected",
        "timestamp": datetime.now().isoformat()
    })


@app.route('/metrics')
def metrics():
    """Simple metrics endpoint"""
    return f"""# HELP ddos_detection_score Current DDoS detection score
# TYPE ddos_detection_score gauge
ddos_detection_score {current_score}

# HELP ddos_binary_prediction Binary DDoS prediction
# TYPE ddos_binary_prediction gauge
ddos_binary_prediction {current_prediction}

# HELP ddos_confidence Detection confidence
# TYPE ddos_confidence gauge
ddos_confidence {current_confidence}
"""


@app.route('/')
def home():
    """Home endpoint"""
    return jsonify({
        "service": "DDoS Detection Service",
        "port": 5001,
        "endpoints": {
            "health": "/health",
            "predict": "/predict",
            "status": "/status",
            "metrics": "/metrics"
        },
        "timestamp": datetime.now().isoformat()
    })


if __name__ == '__main__':
    print("🚀 Starting Minimal DDoS Detection Service...")
    print("📍 Service will be available at: http://localhost:5001")
    print("🔗 Endpoints:")
    print("   - Health: http://localhost:5001/health")
    print("   - Predict: http://localhost:5001/predict")
    print("   - Status: http://localhost:5001/status")
    print("   - Metrics: http://localhost:5001/metrics")
    print("")
    print("ℹ️  Using port 5001 to avoid macOS AirPlay conflict on port 5000")

    # Run the Flask app
    app.run(
        host='0.0.0.0',  # Accept connections from any IP
        port=5001,  # Changed from 5000 to avoid macOS AirPlay conflict
        debug=False,
        threaded=True
    )
