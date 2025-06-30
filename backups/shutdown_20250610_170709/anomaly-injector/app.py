from flask import Flask, jsonify, request, Response
from prometheus_client import Counter, Gauge, Histogram, generate_latest, REGISTRY
import requests
import time
import threading
import logging
import numpy as np
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
import uuid

# Initialize Flask app
app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics for anomaly injection
anomaly_injections_total = Counter(
    'anomaly_injections_total',
    'Total number of anomaly injections',
    ['type', 'target']
)

active_anomalies = Gauge(
    'active_anomalies',
    'Currently active anomaly injections',
    ['type']
)

injection_duration_seconds = Histogram(
    'injection_duration_seconds',
    'Duration of anomaly injections',
    ['type'],
    buckets=(60, 300, 600, 1800, 3600)
)

anomaly_intensity = Gauge(
    'anomaly_intensity',
    'Current intensity of anomaly injection',
    ['type', 'injection_id']
)

# Configuration
BANKING_SERVICES = {
    'api-gateway': 'http://api-gateway:8080',
    'account-service': 'http://account-service:8081',
    'transaction-service': 'http://transaction-service:8082',
    'auth-service': 'http://auth-service:8083',
    'notification-service': 'http://notification-service:8084',
    'fraud-detection': 'http://fraud-detection:8085'
}

# Active injections tracking


class InjectionManager:
    def __init__(self):
        self.active_injections = {}
        self.scheduler = BackgroundScheduler()
        self.scheduler.start()
        self.lock = threading.Lock()

    def add_injection(self, injection_id, injection_type, config):
        """Add a new injection"""
        with self.lock:
            self.active_injections[injection_id] = {
                'type': injection_type,
                'config': config,
                'start_time': datetime.now(),
                'status': 'active'
            }
            active_anomalies.labels(type=injection_type).inc()

    def remove_injection(self, injection_id):
        """Remove an injection"""
        with self.lock:
            if injection_id in self.active_injections:
                injection = self.active_injections[injection_id]
                duration = (datetime.now() -
                            injection['start_time']).total_seconds()
                injection_duration_seconds.labels(
                    type=injection['type']).observe(duration)
                active_anomalies.labels(type=injection['type']).dec()
                del self.active_injections[injection_id]

    def get_active_injections(self):
        """Get all active injections"""
        with self.lock:
            return dict(self.active_injections)


injection_manager = InjectionManager()

# Injection implementations


class LatencyInjector:
    """Inject latency into service responses"""

    @staticmethod
    def inject(target_service, delay_ms, probability, duration_minutes, injection_id):
        """Inject latency by making delayed requests"""
        end_time = datetime.now() + timedelta(minutes=duration_minutes)

        def injection_loop():
            while datetime.now() < end_time:
                try:
                    if np.random.random() < probability:
                        # Make a request with artificial delay
                        service_url = BANKING_SERVICES.get(target_service)
                        if service_url:
                            # Add delay before request
                            time.sleep(delay_ms / 1000.0)

                            # Make various types of requests
                            endpoints = ['/health', '/']
                            endpoint = np.random.choice(endpoints)

                            try:
                                requests.get(
                                    f"{service_url}{endpoint}", timeout=5)
                            except:
                                pass  # Ignore errors during injection

                            # Update intensity metric
                            anomaly_intensity.labels(
                                type='latency',
                                injection_id=injection_id
                            ).set(delay_ms)

                    # Small delay between injection attempts
                    time.sleep(0.1)

                except Exception as e:
                    logger.error(f"Error in latency injection: {e}")

            # Cleanup after injection
            injection_manager.remove_injection(injection_id)
            anomaly_intensity.remove(type='latency', injection_id=injection_id)

        # Start injection in background thread
        thread = threading.Thread(target=injection_loop, daemon=True)
        thread.start()


class FailureInjector:
    """Inject failures into service responses"""

    @staticmethod
    def inject(target_service, error_code, probability, duration_minutes, injection_id):
        """Inject failures by making requests that will fail"""
        end_time = datetime.now() + timedelta(minutes=duration_minutes)

        def injection_loop():
            while datetime.now() < end_time:
                try:
                    if np.random.random() < probability:
                        service_url = BANKING_SERVICES.get(target_service)
                        if service_url:
                            # Make requests to non-existent endpoints to generate errors
                            fake_endpoints = [
                                '/trigger-error-500',
                                '/trigger-error-503',
                                '/trigger-timeout',
                                '/invalid-endpoint-12345'
                            ]

                            endpoint = np.random.choice(fake_endpoints)

                            try:
                                requests.get(
                                    f"{service_url}{endpoint}", timeout=2)
                            except:
                                pass  # Expected to fail

                            # Update intensity metric
                            anomaly_intensity.labels(
                                type='failure',
                                injection_id=injection_id
                            ).set(error_code)

                    time.sleep(0.2)

                except Exception as e:
                    logger.error(f"Error in failure injection: {e}")

            # Cleanup
            injection_manager.remove_injection(injection_id)
            anomaly_intensity.remove(type='failure', injection_id=injection_id)

        thread = threading.Thread(target=injection_loop, daemon=True)
        thread.start()


class LoadInjector:
    """Inject load patterns into the system"""

    @staticmethod
    def inject(pattern, intensity, duration_minutes, injection_id):
        """Inject various load patterns"""
        end_time = datetime.now() + timedelta(minutes=duration_minutes)
        start_time = datetime.now()

        # Define intensity levels
        intensities = {
            'low': {'threads': 5, 'delay': 1.0},
            'medium': {'threads': 20, 'delay': 0.5},
            'high': {'threads': 50, 'delay': 0.1}
        }

        config = intensities.get(intensity, intensities['medium'])

        def generate_load():
            while datetime.now() < end_time:
                try:
                    # Calculate current intensity based on pattern
                    elapsed = (datetime.now() - start_time).total_seconds()

                    if pattern == 'spike':
                        # Sudden spike pattern
                        current_multiplier = 3.0 if elapsed % 120 < 30 else 1.0
                    elif pattern == 'gradual':
                        # Gradual increase
                        progress = elapsed / (duration_minutes * 60)
                        current_multiplier = 1.0 + (2.0 * progress)
                    elif pattern == 'wave':
                        # Sine wave pattern
                        current_multiplier = 1.0 + np.sin(elapsed / 30) * 0.5
                    else:
                        current_multiplier = 1.0

                    # Make requests based on pattern
                    for service_name, service_url in BANKING_SERVICES.items():
                        if np.random.random() < (0.1 * current_multiplier):
                            try:
                                # Simulate different transaction types
                                if 'transaction' in service_name:
                                    data = {
                                        'type': np.random.choice(['deposit', 'withdrawal', 'transfer']),
                                        'amount': np.random.uniform(10, 1000)
                                    }
                                    requests.post(
                                        f"{service_url}/transactions", json=data, timeout=2)
                                elif 'account' in service_name:
                                    requests.get(
                                        f"{service_url}/accounts/123", timeout=2)
                                elif 'auth' in service_name:
                                    requests.post(f"{service_url}/login",
                                                  json={'username': 'test',
                                                        'password': 'test'},
                                                  timeout=2)
                                else:
                                    requests.get(
                                        f"{service_url}/health", timeout=2)
                            except:
                                pass

                    # Update intensity metric
                    anomaly_intensity.labels(
                        type='load',
                        injection_id=injection_id
                    ).set(current_multiplier * 100)

                    time.sleep(config['delay'])

                except Exception as e:
                    logger.error(f"Error in load injection: {e}")

            # Cleanup
            injection_manager.remove_injection(injection_id)
            anomaly_intensity.remove(type='load', injection_id=injection_id)

        # Start multiple threads for load generation
        for i in range(config['threads']):
            thread = threading.Thread(target=generate_load, daemon=True)
            thread.start()

# API Endpoints


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    active = injection_manager.get_active_injections()
    return jsonify({
        'status': 'healthy',
        'service': 'anomaly-injector',
        'timestamp': datetime.now().isoformat(),
        'active_injections': len(active)
    })


@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(REGISTRY), mimetype='text/plain; version=0.0.4; charset=utf-8')

@app.route('/inject/latency', methods=['POST'])
def inject_latency():
    """Inject latency anomaly"""
    try:
        data = request.json
        target = data.get('target', 'transaction-service')
        delay_ms = data.get('delay_ms', 1000)
        probability = data.get('probability', 0.3)
        duration_minutes = data.get('duration_minutes', 10)

        # Validate inputs
        if target not in BANKING_SERVICES:
            return jsonify({'error': f'Invalid target. Valid targets: {list(BANKING_SERVICES.keys())}'}), 400

        if not 0 <= probability <= 1:
            return jsonify({'error': 'Probability must be between 0 and 1'}), 400

        # Create injection
        injection_id = str(uuid.uuid4())
        injection_config = {
            'target': target,
            'delay_ms': delay_ms,
            'probability': probability,
            'duration_minutes': duration_minutes
        }

        injection_manager.add_injection(
            injection_id, 'latency', injection_config)
        anomaly_injections_total.labels(type='latency', target=target).inc()

        # Start injection
        LatencyInjector.inject(target, delay_ms, probability,
                               duration_minutes, injection_id)

        return jsonify({
            'status': 'started',
            'injection_id': injection_id,
            'type': 'latency',
            'config': injection_config,
            'end_time': (datetime.now() + timedelta(minutes=duration_minutes)).isoformat()
        })

    except Exception as e:
        logger.error(f"Error starting latency injection: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/inject/failure', methods=['POST'])
def inject_failure():
    """Inject failure anomaly"""
    try:
        data = request.json
        target = data.get('target', 'transaction-service')
        error_code = data.get('error_code', 500)
        probability = data.get('probability', 0.1)
        duration_minutes = data.get('duration_minutes', 5)

        # Validate
        if target not in BANKING_SERVICES:
            return jsonify({'error': f'Invalid target. Valid targets: {list(BANKING_SERVICES.keys())}'}), 400

        # Create injection
        injection_id = str(uuid.uuid4())
        injection_config = {
            'target': target,
            'error_code': error_code,
            'probability': probability,
            'duration_minutes': duration_minutes
        }

        injection_manager.add_injection(
            injection_id, 'failure', injection_config)
        anomaly_injections_total.labels(type='failure', target=target).inc()

        # Start injection
        FailureInjector.inject(
            target, error_code, probability, duration_minutes, injection_id)

        return jsonify({
            'status': 'started',
            'injection_id': injection_id,
            'type': 'failure',
            'config': injection_config,
            'end_time': (datetime.now() + timedelta(minutes=duration_minutes)).isoformat()
        })

    except Exception as e:
        logger.error(f"Error starting failure injection: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/inject/load', methods=['POST'])
def inject_load():
    """Inject load anomaly"""
    try:
        data = request.json
        pattern = data.get('pattern', 'spike')  # spike, gradual, wave
        intensity = data.get('intensity', 'medium')  # low, medium, high
        duration_minutes = data.get('duration_minutes', 15)

        # Validate
        valid_patterns = ['spike', 'gradual', 'wave']
        valid_intensities = ['low', 'medium', 'high']

        if pattern not in valid_patterns:
            return jsonify({'error': f'Invalid pattern. Valid: {valid_patterns}'}), 400

        if intensity not in valid_intensities:
            return jsonify({'error': f'Invalid intensity. Valid: {valid_intensities}'}), 400

        # Create injection
        injection_id = str(uuid.uuid4())
        injection_config = {
            'pattern': pattern,
            'intensity': intensity,
            'duration_minutes': duration_minutes
        }

        injection_manager.add_injection(injection_id, 'load', injection_config)
        anomaly_injections_total.labels(type='load', target='all').inc()

        # Start injection
        LoadInjector.inject(pattern, intensity, duration_minutes, injection_id)

        return jsonify({
            'status': 'started',
            'injection_id': injection_id,
            'type': 'load',
            'config': injection_config,
            'end_time': (datetime.now() + timedelta(minutes=duration_minutes)).isoformat()
        })

    except Exception as e:
        logger.error(f"Error starting load injection: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/injections', methods=['GET'])
def list_injections():
    """List all active injections"""
    active = injection_manager.get_active_injections()

    # Format for response
    formatted = []
    for inj_id, details in active.items():
        formatted.append({
            'injection_id': inj_id,
            'type': details['type'],
            'config': details['config'],
            'start_time': details['start_time'].isoformat(),
            'status': details['status']
        })

    return jsonify({
        'active_injections': formatted,
        'count': len(formatted)
    })


@app.route('/injections/<injection_id>', methods=['DELETE'])
def stop_injection(injection_id):
    """Stop a specific injection"""
    if injection_id in injection_manager.active_injections:
        injection_manager.remove_injection(injection_id)
        return jsonify({
            'status': 'stopped',
            'injection_id': injection_id
        })
    else:
        return jsonify({'error': 'Injection not found'}), 404


if __name__ == '__main__':
    logger.info("Anomaly Injector starting on port 5005")
    app.run(host='0.0.0.0', port=5005, debug=False)
