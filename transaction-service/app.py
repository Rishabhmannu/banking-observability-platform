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

# Simulated transactions data
transactions = [
    {"id": 1, "accountId": 1, "amount": 500.00, "type": "DEPOSIT",
        "status": "COMPLETED", "timestamp": "2025-05-01T10:30:00Z"},
    {"id": 2, "accountId": 2, "amount": -200.00, "type": "WITHDRAWAL",
        "status": "COMPLETED", "timestamp": "2025-05-01T11:45:00Z"},
    {"id": 3, "accountId": 1, "amount": -150.00, "type": "PAYMENT",
        "status": "COMPLETED", "timestamp": "2025-05-02T09:15:00Z"}
]

# Function to simulate high CPU load


def cpu_load():
    while True:
        x = 0
        for i in range(10000000):
            x += i
        time.sleep(0.01)


# Start high CPU load if simulation is enabled
if os.environ.get('SIMULATE_HIGH_LOAD', 'false').lower() == 'true':
    for _ in range(4):  # Create 4 threads to simulate high CPU load
        thread = threading.Thread(target=cpu_load)
        thread.daemon = True
        thread.start()


@app.route('/transactions', methods=['GET'])
def get_all_transactions():
    return jsonify(transactions)


@app.route('/transactions/<int:transaction_id>', methods=['GET'])
def get_transaction(transaction_id):
    transaction = next(
        (t for t in transactions if t['id'] == transaction_id), None)
    if transaction:
        return jsonify(transaction)
    return jsonify({"error": "Transaction not found"}), 404


@app.route('/transactions', methods=['POST'])
def create_transaction():
    if not request.json:
        return jsonify({"error": "Invalid request"}), 400

    # Validate account exists
    account_id = request.json.get('accountId')
    account_service_url = os.environ.get(
        'ACCOUNT_SERVICE_URL', 'http://localhost:8081')

    try:
        response = requests.get(f"{account_service_url}/accounts/{account_id}")
        if response.status_code != 200:
            return jsonify({"error": "Account not found"}), 404
    except requests.exceptions.RequestException as e:
        app.logger.error(f"Account service error: {e}")
        return jsonify({"error": "Account service unavailable"}), 503

    # Process transaction
    new_transaction = {
        "id": len(transactions) + 1,
        "accountId": account_id,
        "amount": request.json.get('amount', 0),
        "type": request.json.get('type', 'UNKNOWN'),
        "status": "COMPLETED",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }

    transactions.append(new_transaction)
    return jsonify(new_transaction), 201


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "UP"})



@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8082)
