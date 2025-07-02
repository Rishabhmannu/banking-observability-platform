# === notification-service/app.py ===
import os
import time
import random
from flask import Flask, jsonify, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# Simulated notification history
notifications = [
    {"id": 1, "userId": 1, "message": "Your account has been credited with $500", "sentAt": "2025-05-01T10:35:00Z", "status": "DELIVERED"},
    {"id": 2, "userId": 2, "message": "Withdrawal of $200 completed",      "sentAt": "2025-05-01T11:50:00Z", "status": "DELIVERED"},
    {"id": 3, "userId": 1, "message": "Payment of $150 completed",        "sentAt": "2025-05-02T09:20:00Z", "status": "DELIVERED"}
]

@app.route('/send', methods=['POST'], strict_slashes=False)
def send_notification():
    if os.environ.get('SIMULATE_LATENCY', 'false').lower() == 'true':
        time.sleep(random.uniform(3, 8))
    if not request.is_json:
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

@app.route('/history/<int:user_id>', methods=['GET'], strict_slashes=False)
def get_notification_history(user_id):
    if os.environ.get('SIMULATE_LATENCY', 'false').lower() == 'true':
        time.sleep(random.uniform(3, 8))
    user_notifications = [n for n in notifications if n['userId'] == user_id]
    return jsonify(user_notifications)

@app.route('/health', methods=['GET'], strict_slashes=False)
def health_check():
    return jsonify({"status": "UP"})

@app.route('/metrics', methods=['GET'], strict_slashes=False)
def metrics():
    data = generate_latest()
    return data, 200, {'Content-Type': CONTENT_TYPE_LATEST}

# Alias under /notification prefix
app.add_url_rule('/notification/send',           'send_alias',           send_notification,        methods=['POST'], strict_slashes=False)
app.add_url_rule('/notification/history/<int:user_id>', 'history_alias',        get_notification_history,  methods=['GET'],  strict_slashes=False)
app.add_url_rule('/notification/health',         'health_alias',         health_check,            methods=['GET'],  strict_slashes=False)
app.add_url_rule('/notification/metrics',        'metrics_alias',        metrics,                 methods=['GET'],  strict_slashes=False)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8084, debug=True)
