# === auth-service/app.py ===
import os
import time
import threading
import jwt
from flask import Flask, jsonify, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# Memory leak simulator (optional)
memory_leak_storage = []

def simulate_memory_leak():
    while True:
        if os.environ.get('SIMULATE_MEMORY_LEAK', 'false').lower() == 'true':
            memory_leak_storage.append('x' * 1024 * 1024)
            app.logger.warning(f"Leaked {len(memory_leak_storage)} MB")
        time.sleep(5)

if os.environ.get('SIMULATE_MEMORY_LEAK', 'false').lower() == 'true':
    t = threading.Thread(target=simulate_memory_leak, daemon=True)
    t.start()

users = [
    {"id": 1, "username": "john.doe",   "password": "password123", "role": "CUSTOMER"},
    {"id": 2, "username": "jane.smith", "password": "password456", "role": "CUSTOMER"},
    {"id": 3, "username": "admin",      "password": "admin123",   "role": "ADMIN"}
]

@app.route('/login', methods=['POST'], strict_slashes=False)
def login():
    if not request.is_json:
        return jsonify({"error": "JSON body required"}), 400
    data = request.get_json()
    user = next((u for u in users if u['username'] == data.get('username') and u['password'] == data.get('password')), None)
    if not user:
        return jsonify({"error": "Invalid credentials"}), 401
    token = jwt.encode(
        {"user_id": user['id'], "username": user['username'], "role": user['role']},
        "banking-demo-secret", algorithm="HS256"
    )
    return jsonify({"token": token, "user": user}), 200

@app.route('/verify', methods=['GET', 'POST'], strict_slashes=False)
def verify():
    if request.method == 'GET':
        return jsonify({
            "service": "Auth Service",
            "status": "Running",
            "instruction": "POST JSON {\"token\": \"<your_jwt>\"} to this same URL"
        })
    data = request.get_json()
    if not data or 'token' not in data:
        return jsonify({"error": "JSON body with 'token' required"}), 400
    token = data['token']
    try:
        payload = jwt.decode(token, "banking-demo-secret", algorithms=["HS256"])
        return jsonify({"valid": True, "user": payload}), 200
    except jwt.ExpiredSignatureError:
        return jsonify({"valid": False, "error": "Token expired"}), 401
    except jwt.InvalidTokenError:
        return jsonify({"valid": False, "error": "Invalid token"}), 401

@app.route('/health', methods=['GET'], strict_slashes=False)
def health_check():
    return jsonify({"status": "UP", "memory_usage_mb": len(memory_leak_storage)})

@app.route('/metrics', methods=['GET'], strict_slashes=False)
def metrics():
    data = generate_latest()
    return data, 200, {'Content-Type': CONTENT_TYPE_LATEST}

# Alias routes under /auth prefix
app.add_url_rule('/auth/login',   'login_alias',   login,        methods=['POST'],           strict_slashes=False)
app.add_url_rule('/auth/verify',  'verify_alias',  verify,       methods=['GET', 'POST'],    strict_slashes=False)
app.add_url_rule('/auth/health',  'health_alias',  health_check, methods=['GET'],            strict_slashes=False)
app.add_url_rule('/auth/metrics', 'metrics_alias', metrics,      methods=['GET'],            strict_slashes=False)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8083, debug=True)
