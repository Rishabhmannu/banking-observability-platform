"""
Resource Anomaly Generator Service
Simulates various resource anomalies to test container optimization
"""
import os
import time
import logging
import psutil
from datetime import datetime
from flask import Flask, jsonify, request
from prometheus_client import Counter, Gauge, generate_latest, CONTENT_TYPE_LATEST
from anomaly_patterns import ANOMALY_PATTERNS

# Configuration
SERVICE_NAME = "resource-anomaly-generator"
SERVICE_PORT = 5011
LOG_LEVEL = 'INFO'

# Configure logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Prometheus metrics
anomaly_active = Gauge(
    'resource_anomaly_active',
    'Currently active anomaly patterns',
    ['pattern']
)

anomaly_activations = Counter(
    'resource_anomaly_activations_total',
    'Total number of anomaly activations',
    ['pattern']
)

system_cpu_percent = Gauge(
    'anomaly_generator_cpu_percent',
    'Current CPU usage percentage'
)

system_memory_percent = Gauge(
    'anomaly_generator_memory_percent',
    'Current memory usage percentage'
)

system_memory_mb = Gauge(
    'anomaly_generator_memory_mb',
    'Current memory usage in MB'
)

class ResourceAnomalyGenerator:
    """Manages resource anomaly generation"""
    
    def __init__(self):
        self.active_patterns = {}
        self.start_time = time.time()
        
    def start_anomaly(self, pattern_name, **kwargs):
        """Start an anomaly pattern"""
        if pattern_name not in ANOMALY_PATTERNS:
            raise ValueError(f"Unknown pattern: {pattern_name}")
        
        # Stop existing instance if running
        if pattern_name in self.active_patterns:
            self.stop_anomaly(pattern_name)
        
        # Create and start new instance
        pattern_class = ANOMALY_PATTERNS[pattern_name]
        pattern_instance = pattern_class(**kwargs)
        pattern_instance.start()
        
        self.active_patterns[pattern_name] = pattern_instance
        
        # Update metrics
        anomaly_active.labels(pattern=pattern_name).set(1)
        anomaly_activations.labels(pattern=pattern_name).inc()
        
        logger.info(f"Started anomaly pattern: {pattern_name}")
        return True
    
    def stop_anomaly(self, pattern_name):
        """Stop an anomaly pattern"""
        if pattern_name in self.active_patterns:
            pattern = self.active_patterns[pattern_name]
            pattern.stop()
            del self.active_patterns[pattern_name]
            
            # Update metrics
            anomaly_active.labels(pattern=pattern_name).set(0)
            
            logger.info(f"Stopped anomaly pattern: {pattern_name}")
            return True
        
        return False
    
    def stop_all_anomalies(self):
        """Stop all active anomalies"""
        patterns = list(self.active_patterns.keys())
        for pattern_name in patterns:
            self.stop_anomaly(pattern_name)
    
    def get_status(self):
        """Get current status"""
        # Update system metrics
        cpu_percent = psutil.cpu_percent(interval=1)
        memory_info = psutil.virtual_memory()
        
        system_cpu_percent.set(cpu_percent)
        system_memory_percent.set(memory_info.percent)
        system_memory_mb.set(memory_info.used / 1024 / 1024)
        
        return {
            'active_patterns': list(self.active_patterns.keys()),
            'system': {
                'cpu_percent': cpu_percent,
                'memory_percent': memory_info.percent,
                'memory_used_mb': round(memory_info.used / 1024 / 1024, 2),
                'memory_available_mb': round(memory_info.available / 1024 / 1024, 2)
            },
            'uptime_seconds': int(time.time() - self.start_time)
        }

# Initialize generator
generator = ResourceAnomalyGenerator()

# Initialize pattern metrics
for pattern in ANOMALY_PATTERNS:
    anomaly_active.labels(pattern=pattern).set(0)

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': SERVICE_NAME,
        'active_anomalies': len(generator.active_patterns),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    # Update system metrics before serving
    generator.get_status()
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/patterns')
def list_patterns():
    """List available anomaly patterns"""
    patterns = {}
    for name, pattern_class in ANOMALY_PATTERNS.items():
        patterns[name] = {
            'name': name,
            'description': pattern_class.__doc__.strip(),
            'active': name in generator.active_patterns
        }
    
    return jsonify({'patterns': patterns})

@app.route('/start/<pattern>', methods=['POST'])
def start_pattern(pattern):
    """Start an anomaly pattern"""
    try:
        # Get optional parameters
        data = request.get_json() or {}
        
        # Pattern-specific parameters
        params = {}
        if pattern == 'memory_leak':
            params['leak_rate_mb'] = data.get('leak_rate_mb', 10)
            params['max_leak_mb'] = data.get('max_leak_mb', 500)
        elif pattern == 'cpu_spike':
            params['spike_duration'] = data.get('spike_duration', 10)
            params['spike_intensity'] = data.get('spike_intensity', 0.8)
            params['interval'] = data.get('interval', 30)
        elif pattern == 'memory_churn':
            params['churn_size_mb'] = data.get('churn_size_mb', 50)
            params['churn_rate'] = data.get('churn_rate', 10)
        elif pattern == 'io_intensive':
            params['file_size_mb'] = data.get('file_size_mb', 10)
            params['operations_per_second'] = data.get('operations_per_second', 5)
        
        generator.start_anomaly(pattern, **params)
        
        return jsonify({
            'status': 'started',
            'pattern': pattern,
            'parameters': params
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/stop/<pattern>', methods=['POST'])
def stop_pattern(pattern):
    """Stop an anomaly pattern"""
    if generator.stop_anomaly(pattern):
        return jsonify({'status': 'stopped', 'pattern': pattern})
    else:
        return jsonify({'error': f'Pattern {pattern} not active'}), 404

@app.route('/stop-all', methods=['POST'])
def stop_all():
    """Stop all anomaly patterns"""
    generator.stop_all_anomalies()
    return jsonify({'status': 'all patterns stopped'})

@app.route('/status')
def get_status():
    """Get current generator status"""
    return jsonify(generator.get_status())

@app.route('/scenarios/<scenario>', methods=['POST'])
def run_scenario(scenario):
    """Run predefined anomaly scenarios"""
    scenarios = {
        'memory_pressure': [
            ('memory_leak', {'leak_rate_mb': 20, 'max_leak_mb': 1000}),
            ('memory_churn', {'churn_size_mb': 100, 'churn_rate': 20})
        ],
        'cpu_stress': [
            ('cpu_spike', {'spike_duration': 15, 'spike_intensity': 0.9, 'interval': 20})
        ],
        'unstable_container': [
            ('memory_leak', {'leak_rate_mb': 50, 'max_leak_mb': 2000}),
            ('cpu_spike', {'spike_duration': 5, 'spike_intensity': 1.0, 'interval': 15}),
            ('restart_trigger', {})
        ],
        'resource_fluctuation': [
            ('fluctuation', {})
        ],
        'io_bottleneck': [
            ('io_intensive', {'file_size_mb': 50, 'operations_per_second': 10})
        ]
    }
    
    if scenario not in scenarios:
        return jsonify({'error': f'Unknown scenario: {scenario}'}), 400
    
    # Stop all current anomalies
    generator.stop_all_anomalies()
    
    # Start scenario patterns
    started_patterns = []
    for pattern_name, params in scenarios[scenario]:
        try:
            generator.start_anomaly(pattern_name, **params)
            started_patterns.append(pattern_name)
        except Exception as e:
            logger.error(f"Failed to start {pattern_name}: {e}")
    
    return jsonify({
        'status': 'scenario started',
        'scenario': scenario,
        'patterns': started_patterns
    })

@app.route('/cleanup', methods=['POST'])
def cleanup():
    """Clean up all resources and reset"""
    generator.stop_all_anomalies()
    
    # Force garbage collection
    import gc
    gc.collect()
    
    return jsonify({
        'status': 'cleaned up',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    # Log startup info
    logger.info(f"Starting {SERVICE_NAME} on port {SERVICE_PORT}")
    logger.info(f"Available patterns: {list(ANOMALY_PATTERNS.keys())}")
    
    # Cleanup handler for shutdown
    import atexit
    atexit.register(generator.stop_all_anomalies)
    
    # Run Flask app
    app.run(host='0.0.0.0', port=SERVICE_PORT, debug=False)