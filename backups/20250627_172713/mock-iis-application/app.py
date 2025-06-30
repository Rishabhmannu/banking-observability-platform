from flask import Flask, jsonify, request
import random
import time
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Simulate IIS application behavior


@app.route('/')
def home():
    # Simulate variable processing time
    processing_time = random.gauss(0.05, 0.02)
    time.sleep(max(0, processing_time))
    return jsonify({'status': 'ok', 'site': 'BankingApp'})


@app.route('/api/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def api_endpoint(path):
    # Simulate API calls with occasional errors
    if random.random() < 0.001:  # 0.1% chance of 500 error
        return jsonify({'error': 'Internal Server Error'}), 500
    elif random.random() < 0.005:  # 0.5% chance of 404
        return jsonify({'error': 'Not Found'}), 404
    elif random.random() < 0.002:  # 0.2% chance of 403
        return jsonify({'error': 'Forbidden'}), 403

    # Normal response
    return jsonify({'result': 'success', 'path': path})


@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'mock-iis-application'})


if __name__ == '__main__':
    logger.info("Starting Mock IIS Application on port 8090")
    app.run(host='0.0.0.0', port=8090, debug=False)
