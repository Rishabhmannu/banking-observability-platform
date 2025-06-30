"""
Redis Cache Load Generator Service
Generates various cache access patterns for testing banking cache performance
"""
import time
import logging
import json
import threading
from datetime import datetime
from flask import Flask, jsonify, request
import redis
from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST
from apscheduler.schedulers.background import BackgroundScheduler
from cache_patterns import AVAILABLE_PATTERNS, NormalTrafficPattern

# Configuration
SERVICE_NAME = "redis-cache-load-generator"
SERVICE_PORT = 5013
REDIS_HOST = 'banking-redis'
REDIS_PORT = 6379
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
cache_operations_total = Counter(
    'cache_load_operations_total',
    'Total cache operations generated',
    ['operation', 'pattern', 'result']
)

cache_operation_duration = Histogram(
    'cache_load_operation_duration_seconds',
    'Cache operation duration',
    ['operation', 'pattern']
)

active_pattern_gauge = Gauge(
    'cache_load_active_pattern',
    'Currently active load pattern',
    ['pattern']
)

load_generation_rate = Gauge(
    'cache_load_generation_rate_ops',
    'Current load generation rate (ops/sec)'
)

class RedisCacheLoadGenerator:
    """Generates cache load with various patterns"""
    
    def __init__(self):
        self.redis_client = None
        self.is_connected = False
        self.scheduler = BackgroundScheduler()
        self.current_pattern = None
        self.pattern_instance = None
        self.is_generating = False
        self.generation_thread = None
        self.ops_per_second = 10
        self.total_operations = 0
        self.start_time = None
        
    def connect_redis(self):
        """Establish Redis connection"""
        try:
            self.redis_client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                decode_responses=False  # We'll handle encoding
            )
            self.redis_client.ping()
            self.is_connected = True
            logger.info(f"✅ Connected to Redis at {REDIS_HOST}:{REDIS_PORT}")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to connect to Redis: {e}")
            self.is_connected = False
            return False
    
    def set_pattern(self, pattern_name, ops_per_second=10):
        """Set the load generation pattern"""
        if pattern_name not in AVAILABLE_PATTERNS:
            raise ValueError(f"Unknown pattern: {pattern_name}")
        
        # Stop current generation if active
        if self.is_generating:
            self.stop_generation()
        
        # Reset pattern gauges
        for pattern in AVAILABLE_PATTERNS:
            active_pattern_gauge.labels(pattern=pattern).set(0)
        
        # Set new pattern
        self.current_pattern = pattern_name
        self.pattern_instance = AVAILABLE_PATTERNS[pattern_name]()
        self.ops_per_second = ops_per_second
        active_pattern_gauge.labels(pattern=pattern_name).set(1)
        load_generation_rate.set(ops_per_second)
        
        logger.info(f"Pattern set to: {pattern_name} at {ops_per_second} ops/sec")
    
    def generate_load(self):
        """Generate cache load based on current pattern"""
        if not self.pattern_instance:
            logger.error("No pattern set")
            return
        
        logger.info(f"Starting load generation with pattern: {self.current_pattern}")
        self.start_time = time.time()
        self.total_operations = 0
        
        while self.is_generating:
            try:
                # Generate batch of operations
                operations = self.pattern_instance.generate_operations(
                    count=max(1, int(self.ops_per_second))
                )
                
                # Execute operations
                for op in operations:
                    if not self.is_generating:
                        break
                    
                    start_time = time.time()
                    result = self._execute_operation(op)
                    duration = time.time() - start_time
                    
                    # Record metrics
                    cache_operations_total.labels(
                        operation=op['operation'],
                        pattern=self.current_pattern,
                        result=result
                    ).inc()
                    
                    cache_operation_duration.labels(
                        operation=op['operation'],
                        pattern=self.current_pattern
                    ).observe(duration)
                    
                    self.total_operations += 1
                
                # Sleep to maintain rate
                time.sleep(1.0)
                
            except Exception as e:
                logger.error(f"Error during load generation: {e}")
                time.sleep(1)
    
    def _execute_operation(self, operation):
        """Execute a single cache operation"""
        try:
            op_type = operation['operation']
            key = operation['key']
            
            if op_type == 'get':
                # Try to get from cache
                value = self.redis_client.get(key)
                if value is None and operation.get('data'):
                    # Cache miss - set the value
                    data = json.dumps(operation['data'])
                    if operation.get('ttl'):
                        self.redis_client.setex(key, operation['ttl'], data)
                    else:
                        self.redis_client.set(key, data)
                    return 'miss'
                return 'hit' if value else 'miss'
            
            elif op_type == 'set':
                # Always set the value
                data = json.dumps(operation['data'])
                if operation.get('ttl'):
                    self.redis_client.setex(key, operation['ttl'], data)
                else:
                    self.redis_client.set(key, data)
                return 'success'
            
            else:
                return 'unknown'
                
        except Exception as e:
            logger.error(f"Operation execution error: {e}")
            return 'error'
    
    def start_generation(self):
        """Start load generation in background thread"""
        if self.is_generating:
            logger.warning("Load generation already active")
            return
        
        if not self.is_connected:
            if not self.connect_redis():
                raise RuntimeError("Cannot connect to Redis")
        
        if not self.pattern_instance:
            # Default to normal pattern
            self.set_pattern('normal')
        
        self.is_generating = True
        self.generation_thread = threading.Thread(target=self.generate_load)
        self.generation_thread.daemon = True
        self.generation_thread.start()
        
        logger.info("✅ Load generation started")
    
    def stop_generation(self):
        """Stop load generation"""
        self.is_generating = False
        if self.generation_thread:
            self.generation_thread.join(timeout=5)
        
        # Reset gauges
        for pattern in AVAILABLE_PATTERNS:
            active_pattern_gauge.labels(pattern=pattern).set(0)
        load_generation_rate.set(0)
        
        logger.info("⏹️ Load generation stopped")
    
    def get_stats(self):
        """Get current generation statistics"""
        if self.start_time:
            elapsed = time.time() - self.start_time
            actual_rate = self.total_operations / elapsed if elapsed > 0 else 0
        else:
            actual_rate = 0
        
        return {
            'is_generating': self.is_generating,
            'current_pattern': self.current_pattern,
            'target_ops_per_second': self.ops_per_second,
            'actual_ops_per_second': round(actual_rate, 2),
            'total_operations': self.total_operations,
            'uptime_seconds': int(time.time() - self.start_time) if self.start_time else 0
        }

# Initialize generator
generator = RedisCacheLoadGenerator()

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy' if generator.is_connected else 'unhealthy',
        'service': SERVICE_NAME,
        'redis_connected': generator.is_connected,
        'is_generating': generator.is_generating,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/patterns')
def list_patterns():
    """List available patterns"""
    patterns = {}
    for name, pattern_class in AVAILABLE_PATTERNS.items():
        instance = pattern_class()
        patterns[name] = {
            'name': instance.name,
            'description': pattern_class.__doc__.strip()
        }
    
    return jsonify({
        'patterns': patterns,
        'current': generator.current_pattern
    })

@app.route('/start', methods=['POST'])
def start_generation():
    """Start load generation"""
    try:
        data = request.get_json() or {}
        pattern = data.get('pattern', 'normal')
        ops_per_second = data.get('ops_per_second', 10)
        
        generator.set_pattern(pattern, ops_per_second)
        generator.start_generation()
        
        return jsonify({
            'status': 'started',
            'pattern': pattern,
            'ops_per_second': ops_per_second
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/stop', methods=['POST'])
def stop_generation():
    """Stop load generation"""
    generator.stop_generation()
    return jsonify({'status': 'stopped'})

@app.route('/stats')
def get_stats():
    """Get generation statistics"""
    return jsonify(generator.get_stats())

@app.route('/simulate/<scenario>', methods=['POST'])
def simulate_scenario(scenario):
    """Quick simulation endpoints for testing"""
    scenarios = {
        'stampede': ('stampede', 50),
        'eviction': ('eviction', 20),
        'burst': ('burst', 100),
        'normal': ('normal', 10),
        'miss': ('miss', 30)
    }
    
    if scenario not in scenarios:
        return jsonify({'error': 'Unknown scenario'}), 400
    
    pattern, ops = scenarios[scenario]
    generator.set_pattern(pattern, ops)
    generator.start_generation()
    
    return jsonify({
        'status': 'started',
        'scenario': scenario,
        'pattern': pattern,
        'ops_per_second': ops
    })

if __name__ == '__main__':
    # Connect to Redis on startup
    generator.connect_redis()
    
    # Run Flask app
    logger.info(f"Starting {SERVICE_NAME} on port {SERVICE_PORT}")
    app.run(host='0.0.0.0', port=SERVICE_PORT, debug=False)