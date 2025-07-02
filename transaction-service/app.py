import os
import time
import random
import threading
from flask import Flask, jsonify, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
import requests

app = Flask(__name__)

# Simulated transactions data
transactions = [
    {"id": 1, "accountId": 1, "amount": 500.00, "type": "DEPOSIT",    "status": "COMPLETED",  "timestamp": "2025-05-01T10:30:00Z"},
    {"id": 2, "accountId": 2, "amount": -200.00,"type": "WITHDRAWAL", "status": "COMPLETED",  "timestamp": "2025-05-01T11:45:00Z"},
    {"id": 3, "accountId": 1, "amount": -150.00,"type": "PAYMENT",    "status": "COMPLETED",  "timestamp": "2025-05-02T09:15:00Z"}
]

# CPU load simulator
def cpu_load():
    while True:
        x = 0
        for i in range(10000000):
            x += i
        time.sleep(0.01)

if os.environ.get('SIMULATE_HIGH_LOAD', 'false').lower() == 'true':
    for _ in range(4):
        t = threading.Thread(target=cpu_load, daemon=True)
        t.start()

@app.route('/transactions', methods=['GET'], strict_slashes=False)
def get_all_transactions():
    return jsonify(transactions)

@app.route('/transactions/<int:transaction_id>', methods=['GET'], strict_slashes=False)
def get_transaction(transaction_id):
    tx = next((t for t in transactions if t['id'] == transaction_id), None)
    if not tx:
        return jsonify({"error": "Transaction not found"}), 404
    return jsonify(tx)

@app.route('/transactions', methods=['POST'], strict_slashes=False)
def create_transaction():
    if not request.is_json:
        return jsonify({"error": "Invalid request"}), 400
    account_id = request.json.get('accountId')
    account_service_url = os.environ.get('ACCOUNT_SERVICE_URL', 'http://localhost:8081')
    try:
        resp = requests.get(f"{account_service_url}/accounts/{account_id}")
        if resp.status_code != 200:
            return jsonify({"error": "Account not found"}), 404
    except requests.RequestException as e:
        app.logger.error(f"Account service unavailable: {e}")
        return jsonify({"error": "Account service unavailable"}), 503

    new_tx = {
        "id": len(transactions) + 1,
        "accountId": account_id,
        "amount": request.json.get('amount', 0),
        "type": request.json.get('type', 'UNKNOWN'),
        "status": "COMPLETED",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }
    transactions.append(new_tx)
    return jsonify(new_tx), 201

@app.route('/health', methods=['GET'], strict_slashes=False)
def health_check():
    return jsonify({"status": "UP"})

@app.route('/metrics', methods=['GET'], strict_slashes=False)
def metrics():
    data = generate_latest()
    return data, 200, {'Content-Type': CONTENT_TYPE_LATEST}

# Alias under /transaction prefix (REMOVED - not needed)
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8082, debug=True)