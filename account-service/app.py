import os
import time
import random
from flask import Flask, jsonify, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
import mysql.connector
from flask_restful import Api

app = Flask(__name__)
api = Api(app)

# Simulated database connection
def get_db_connection():
    # Simulate slow query if enabled
    if os.environ.get('SIMULATE_SLOW_QUERY', 'false').lower() == 'true':
        time.sleep(random.uniform(1, 5))  # Simulate slow query

    try:
        return mysql.connector.connect(
            host=os.environ.get('SPRING_DATASOURCE_URL', 'localhost').split('/')[-1].split(':')[0],
            user=os.environ.get('SPRING_DATASOURCE_USERNAME', 'root'),
            password=os.environ.get('SPRING_DATASOURCE_PASSWORD', 'bankingdemo'),
            database="accountdb"
        )
    except Exception as e:
        app.logger.error(f"Database connection error: {e}")
        return None

# Simulated accounts data
accounts = [
    {"id": 1, "customerNumber": "CUST001", "name": "John Doe", "balance": 5000.00, "type": "Savings"},
    {"id": 2, "customerNumber": "CUST002", "name": "Jane Smith", "balance": 12500.00, "type": "Checking"},
    {"id": 3, "customerNumber": "CUST003", "name": "Bob Johnson", "balance": 25000.00, "type": "Investment"}
]

@app.route('/accounts', methods=['GET'])
def get_all_accounts():
    conn = get_db_connection()
    if not conn:
        return jsonify(accounts)
    # In a real app, would query DB here
    return jsonify(accounts)

@app.route('/accounts/<int:account_id>', methods=['GET'])
def get_account(account_id):
    conn = get_db_connection()
    if not conn:
        account = next((a for a in accounts if a['id'] == account_id), None)
        if account:
            return jsonify(account)
        return jsonify({"error": "Account not found"}), 404
    # In a real app, would query DB here
    account = next((a for a in accounts if a['id'] == account_id), None)
    if account:
        return jsonify(account)
    return jsonify({"error": "Account not found"}), 404

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "UP"})


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081)