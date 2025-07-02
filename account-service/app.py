# === account-service/app.py ===
import os
import time
import random
from flask import Flask, jsonify, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
import mysql.connector

app = Flask(__name__)

# Database connection (stubbed)
def get_db_connection():
    if os.environ.get('SIMULATE_SLOW_QUERY', 'false').lower() == 'true':
        time.sleep(random.uniform(1, 5))
    try:
        host = os.environ.get('SPRING_DATASOURCE_URL', 'localhost') \
                     .split('/')[-1] \
                     .split(':')[0]
        return mysql.connector.connect(
            host=host,
            user=os.environ.get('SPRING_DATASOURCE_USERNAME', 'root'),
            password=os.environ.get('SPRING_DATASOURCE_PASSWORD', 'bankingdemo'),
            database="accountdb"
        )
    except Exception as e:
        app.logger.error(f"DB connection error: {e}")
        return None

# In-memory accounts
accounts = [
    {"id": 1, "customerNumber": "CUST001", "name": "John Doe",    "balance": 5000.00,  "type": "Savings"},
    {"id": 2, "customerNumber": "CUST002", "name": "Jane Smith",  "balance":12500.00,  "type": "Checking"},
    {"id": 3, "customerNumber": "CUST003", "name": "Bob Johnson", "balance":25000.00,  "type": "Investment"}
]

@app.route('/accounts', methods=['GET'], strict_slashes=False)
def get_all_accounts():
    return jsonify(accounts)

@app.route('/accounts/<int:account_id>', methods=['GET'], strict_slashes=False)
def get_account(account_id):
    a = next((a for a in accounts if a['id'] == account_id), None)
    if not a:
        return jsonify({"error": "Account not found"}), 404
    return jsonify(a)

@app.route('/accounts/<int:account_id>/balance', methods=['GET'], strict_slashes=False)
def get_account_balance(account_id):
    a = next((a for a in accounts if a['id'] == account_id), None)
    if not a:
        return jsonify({"error": "Account not found"}), 404
    return jsonify({
        "accountId": account_id,
        "balance": a['balance'],
        "currency": "USD"
    })

@app.route('/transactions', methods=['GET'], strict_slashes=False)
def get_transactions():
    txns = [
        {"transactionId": 1, "accountId": 1, "amount": -200.00, "description": "ATM Withdrawal"},
        {"transactionId": 2, "accountId": 1, "amount": 1500.00, "description": "Paycheck Deposit"},
        {"transactionId": 3, "accountId": 2, "amount": -50.25, "description": "Coffee Shop"},
    ]
    return jsonify(txns)

@app.route('/health', methods=['GET'], strict_slashes=False)
def health_check():
    return jsonify({"status": "UP"})

@app.route('/metrics', methods=['GET'], strict_slashes=False)
def metrics():
    data = generate_latest()
    return data, 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081, debug=True)
