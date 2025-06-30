import os
import time
import random
from flask import Flask, jsonify, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from flask_restful import Api

app = Flask(__name__)
api = Api(app)

# Simulated notification history
notifications = [
    {"id": 1, "userId": 1, "message": "Your account has been credited with $500",
        "sentAt": "2025-05-01T10:35:00Z", "status": "DELIVERED"},
    {"id": 2, "userId": 2, "message": "Withdrawal of $200 completed",
        "sentAt": "2025-05-01T11:50:00Z", "status": "DELIVERED"},
    {"id": 3, "userId": 1, "message": "Payment of $150 completed",
        "sentAt": "2025-05-02T09:20:00Z", "status": "DELIVERED"}
]


@app.route('/send', methods=['POST'])
def send_notification():
    # Simulate network latency if enabled
    if os.environ.get('SIMULATE_LATENCY', 'false').lower() == 'true':
        time.sleep(random.uniform(3, 8))  # Simulate 3-8 second latency

    if not request.json:
        return jsonify({"error": "Invalid request"}), 400

    new_notification = {
        "id": len(notifications) + 1,
        "userId": request.json.get('userId'),
        "message": request.json.get('message'),
        "sentAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "status": "DELIVERED"
    }

    notifications.append(new_notification)
    return jsonify(new_notification), 201


@app.route('/history/<int:user_id>', methods=['GET'])
def get_notification_history(user_id):
    # Simulate network latency if enabled
    if os.environ.get('SIMULATE_LATENCY', 'false').lower() == 'true':
        time.sleep(random.uniform(3, 8))  # Simulate 3-8 second latency

    user_notifications = [n for n in notifications if n['userId'] == user_id]
    return jsonify(user_notifications)


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "UP"})



@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8084)
