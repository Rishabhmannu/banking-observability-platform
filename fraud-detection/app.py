import os
import time
import random
import threading
from flask import Flask, jsonify, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
import requests
from flask_restful import Api

app = Flask(__name__)
api = Api(app)

# Function to generate fraud alerts


def generate_fraud_alerts():
    while True:
        if os.environ.get('SIMULATE_ALERT_STORM', 'false').lower() == 'true':
            # Generate a random transaction ID
            transaction_id = random.randint(1000, 9999)

            # Log fraud alert
            app.logger.warning(
                f"FRAUD ALERT: Suspicious transaction detected: {transaction_id}")

            # Sleep briefly between alerts to avoid overwhelming the system
            time.sleep(0.2)  # 5 alerts per second
        else:
            # Check flag every 5 seconds when not generating alerts
            time.sleep(5)


# Start alert generator thread
alert_thread = threading.Thread(target=generate_fraud_alerts)
alert_thread.daemon = True
alert_thread.start()


@app.route('/check', methods=['POST'])
def check_transaction():
    if not request.json:
        return jsonify({"error": "Invalid request"}), 400

    transaction = request.json

    # Simple fraud detection logic
    is_suspicious = False
    risk_score = random.randint(1, 100)

    # Transactions over $1000 have higher risk score
    if transaction.get('amount', 0) > 1000:
        risk_score += 20

    # Mark as suspicious if risk score is high
    if risk_score > 80:
        is_suspicious = True

    return jsonify({
        "transactionId": transaction.get('id'),
        "suspicious": is_suspicious,
        "riskScore": risk_score,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    })


@app.route('/alerts', methods=['GET'])
def get_recent_alerts():
    # Simulate some alerts
    alerts = []

    for i in range(10):
        alerts.append({
            "id": i + 1,
            "transactionId": random.randint(1000, 9999),
            "accountId": random.randint(1, 100),
            "riskScore": random.randint(80, 100),
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        })

    return jsonify(alerts)


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "UP"})



@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8085)
