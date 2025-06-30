import os
import time
import jwt
import threading
from flask import Flask, jsonify, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from flask_restful import Api

app = Flask(__name__)
api = Api(app)

# Global list to simulate memory leak
memory_leak_storage = []

# Function to simulate memory leak


def simulate_memory_leak():
    while True:
        # Create large objects and add to global list (never freed)
        if os.environ.get('SIMULATE_MEMORY_LEAK', 'false').lower() == 'true':
            # Each item is about 1MB
            memory_leak_storage.append('x' * 1024 * 1024)
            app.logger.warning(
                f"Memory leak simulation: {len(memory_leak_storage)} MB allocated")
        time.sleep(5)  # Add 1MB every 5 seconds


# Start memory leak thread if simulation is enabled
if os.environ.get('SIMULATE_MEMORY_LEAK', 'false').lower() == 'true':
    thread = threading.Thread(target=simulate_memory_leak)
    thread.daemon = True
    thread.start()

# Simulated users data
users = [
    {"id": 1, "username": "john.doe", "password": "password123", "role": "CUSTOMER"},
    {"id": 2, "username": "jane.smith", "password": "password456", "role": "CUSTOMER"},
    {"id": 3, "username": "admin", "password": "admin123", "role": "ADMIN"}
]


@app.route('/login', methods=['POST'])
def login():
    if not request.json:
        return jsonify({"error": "Invalid request"}), 400

    username = request.json.get('username')
    password = request.json.get('password')

    user = next((u for u in users if u['username'] ==
                username and u['password'] == password), None)
    if not user:
        return jsonify({"error": "Invalid credentials"}), 401

    # Generate JWT token
    token = jwt.encode(
        {"user_id": user['id'], "username": user['username'],
            "role": user['role']},
        "banking-demo-secret",
        algorithm="HS256"
    )

    return jsonify({"token": token, "user": {"id": user['id'], "username": user['username'], "role": user['role']}}), 200


@app.route('/verify', methods=['POST'])
def verify_token():
    if not request.json or 'token' not in request.json:
        return jsonify({"error": "Token required"}), 400

    token = request.json.get('token')

    try:
        payload = jwt.decode(token, "banking-demo-secret",
                             algorithms=["HS256"])
        return jsonify({"valid": True, "user": payload}), 200
    except jwt.ExpiredSignatureError:
        return jsonify({"valid": False, "error": "Token expired"}), 401
    except jwt.InvalidTokenError:
        return jsonify({"valid": False, "error": "Invalid token"}), 401


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "UP", "memory_usage": len(memory_leak_storage) if memory_leak_storage else 0})



@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8083)
