# === fraud-detection/app.py ===
import os
import time
import random
import threading
from flask import Flask, jsonify, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# Fraud alert generator
def generate_fraud_alerts():
    while True:
        if os.environ.get('SIMULATE_ALERT_STORM', 'false').lower() == 'true':
            tx_id = random.randint(1000, 9999)
            app.logger.warning(f"FRAUD ALERT: Suspicious tx {tx_id}")
            time.sleep(0.2)
        else:
            time.sleep(5)

threading.Thread(target=generate_fraud_alerts, daemon=True).start()

@app.route('/check', methods=['POST'], strict_slashes=False)
def check_transaction():
    if not request.is_json:
        return jsonify({"error": "Invalid request"}), 400
    tx = request.get_json()
    risk = random.randint(1, 100)
    if tx.get('amount', 0) > 1000:
        risk += 20
    suspicious = risk > 80
    return jsonify({
        "transactionId": tx.get('id'),
        "suspicious": suspicious,
        "riskScore": risk,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    })

@app.route('/alerts', methods=['GET'], strict_slashes=False)
def get_recent_alerts():
    alerts = []
    for i in range(10):
        alerts.append({
            "id": i+1,
            "transactionId": random.randint(1000, 9999),
            "accountId": random.randint(1, 100),
            "riskScore": random.randint(80, 100),
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        })
    return jsonify(alerts)

@app.route('/health', methods=['GET'], strict_slashes=False)
def health_check():
    return jsonify({"status": "UP"})

@app.route('/metrics', methods=['GET'], strict_slashes=False)
def metrics():
    data = generate_latest()
    return data, 200, {'Content-Type': CONTENT_TYPE_LATEST}

# Alias under /fraud prefix
app.add_url_rule('/fraud/check',   'check_alias',   check_transaction, methods=['POST'], strict_slashes=False)
app.add_url_rule('/fraud/alerts',  'alerts_alias',  get_recent_alerts, methods=['GET'],  strict_slashes=False)
app.add_url_rule('/fraud/health',  'health_alias',  health_check,    methods=['GET'],  strict_slashes=False)
app.add_url_rule('/fraud/metrics', 'metrics_alias', metrics,         methods=['GET'],  strict_slashes=False)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8085, debug=True)
