"""
Cache Proxy Service
Transparent caching layer for banking services
"""
import os
import json
import time
import logging
import hashlib
import re  # Added as per instructions
from flask import Flask, request, jsonify, Response
import requests
import redis
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from cache_rules import get_cache_rule, get_invalidation_patterns

# Configuration
SERVICE_PORT = int(os.getenv('SERVICE_PORT', '5020'))
REDIS_HOST = os.getenv('REDIS_HOST', 'banking-redis')
REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))
API_GATEWAY_URL = os.getenv('API_GATEWAY_URL', 'http://banking-api-gateway:8080')
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

# Service mapping (path prefix to backend service)
SERVICE_MAPPING = {
    '/accounts': os.getenv('ACCOUNT_SERVICE_URL', 'http://banking-account-service:8081'),
    '/transactions': os.getenv('TRANSACTION_SERVICE_URL', 'http://banking-transaction-service:8082'),
    '/auth': os.getenv('AUTH_SERVICE_URL', 'http://banking-auth-service:8083'),
    '/notifications': os.getenv('NOTIFICATION_SERVICE_URL', 'http://banking-notification-service:8084'),
    '/fraud': os.getenv('FRAUD_SERVICE_URL', 'http://banking-fraud-detection:8085'),
}

# Configure logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask
app = Flask(__name__)

# Prometheus metrics - Updated with 'operation' label as per instructions
cache_hits_total = Counter(
    'banking_cache_hits_total',
    'Total number of cache hits',
    ['service', 'endpoint', 'method', 'operation']  # Added operation label
)

cache_misses_total = Counter(
    'banking_cache_misses_total',
    'Total number of cache misses',
    ['service', 'endpoint', 'method', 'operation']  # Added operation label
)

cache_invalidations_total = Counter(
    'banking_cache_invalidations_total',
    'Total number of cache invalidations',
    ['service', 'pattern']
)

proxy_request_duration = Histogram(
    'banking_proxy_request_duration_seconds',
    'Proxy request duration',
    ['service', 'method', 'cache_status']
)

active_cache_entries = Gauge(
    'banking_cache_active_entries',
    'Number of active cache entries'
)

class CacheProxy:
    """Handles caching logic for the proxy"""
    
    def __init__(self):
        self.redis_client = None
        self.connect_redis()
        
    def connect_redis(self):
        """Connect to Redis"""
        try:
            self.redis_client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                decode_responses=True
            )
            self.redis_client.ping()
            logger.info(f"✅ Connected to Redis at {REDIS_HOST}:{REDIS_PORT}")
        except Exception as e:
            logger.error(f"❌ Failed to connect to Redis: {e}")
            self.redis_client = None
    
    def generate_cache_key(self, method: str, path: str, params: dict = None) -> str:
        """Generate a unique cache key for the request"""
        # Include query parameters in the cache key
        param_str = ""
        if params:
            sorted_params = sorted(params.items())
            param_str = "&".join([f"{k}={v}" for k, v in sorted_params])
        
        key_source = f"{method}:{path}:{param_str}"
        # Use a hash for shorter keys
        key_hash = hashlib.md5(key_source.encode()).hexdigest()[:16]
        return f"proxy:{method}:{path.replace('/', ':')}:{key_hash}"
    
    def get_from_cache(self, key: str) -> tuple:
        """Get response from cache"""
        if not self.redis_client:
            return None, None
        
        try:
            cached_data = self.redis_client.get(key)
            if cached_data:
                data = json.loads(cached_data)
                return data.get('body'), data.get('status_code', 200)
        except Exception as e:
            logger.error(f"Cache get error: {e}")
        
        return None, None
    
    def set_in_cache(self, key: str, body: str, status_code: int, ttl: int):
        """Store response in cache"""
        if not self.redis_client:
            return
        
        try:
            cache_data = {
                'body': body,
                'status_code': status_code,
                'cached_at': time.time()
            }
            self.redis_client.setex(
                key,
                ttl,
                json.dumps(cache_data)
            )
        except Exception as e:
            logger.error(f"Cache set error: {e}")
    
    def invalidate_cache(self, patterns: list):
        """Invalidate cache entries matching patterns"""
        if not self.redis_client:
            return
        
        try:
            for pattern in patterns:
                # Convert path pattern to Redis key pattern
                redis_pattern = f"proxy:*:{pattern.replace('/', ':').replace('*', '*')}:*"
                keys = self.redis_client.keys(redis_pattern)
                
                if keys:
                    self.redis_client.delete(*keys)
                    logger.info(f"Invalidated {len(keys)} cache entries for pattern: {pattern}")
                    
                    # Update metrics
                    service = pattern.split('/')[1] if '/' in pattern else 'unknown'
                    cache_invalidations_total.labels(
                        service=service,
                        pattern=pattern
                    ).inc()
                    
        except Exception as e:
            logger.error(f"Cache invalidation error: {e}")
    
    def update_cache_metrics(self):
        """Update cache entry count metric"""
        if not self.redis_client:
            return
        
        try:
            keys = self.redis_client.keys("proxy:*")
            active_cache_entries.set(len(keys))
        except Exception:
            pass

# Initialize cache proxy
cache_proxy = CacheProxy()

def get_backend_url(path: str) -> str:
    """Determine backend service URL based on path"""
    for prefix, service_url in SERVICE_MAPPING.items():
        if path.startswith(prefix):
            return service_url
    
    # Default to API gateway
    return API_GATEWAY_URL

# Added function as per instructions
def get_operation_from_path(path):
    """Extract operation type from path"""
    if '/balance' in path:
        return 'balance_check'
    elif re.match(r'/accounts/\d+$', path):
        return 'account_lookup'
    elif path == '/accounts' or path == '/accounts/':
        return 'account_list'
    elif re.match(r'/transactions/\d+$', path):
        return 'transaction_detail'
    elif path == '/transactions' or path == '/transactions/':
        return 'transaction_list'
    elif '/transfer' in path:
        return 'transfer'
    elif '/auth' in path:
        return 'authentication'
    elif '/fraud' in path:
        return 'fraud_check'
    elif '/customers' in path:
        return 'customer_profile'
    else:
        return 'other'

@app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
def proxy_request(path):
    """Main proxy handler"""
    start_time = time.time()
    method = request.method
    full_path = f"/{path}"
    
    # Determine backend service
    backend_url = get_backend_url(full_path)
    service_name = full_path.split('/')[1] if '/' in full_path else 'unknown'
    
    # Check if this request should be cached
    cache_rule = get_cache_rule(full_path, method)
    cache_status = 'bypass'
    
    if cache_rule and method == 'GET':
        # Try to get from cache
        cache_key = cache_proxy.generate_cache_key(
            method, 
            full_path, 
            dict(request.args)
        )
        
        cached_body, cached_status = cache_proxy.get_from_cache(cache_key)
        
        if cached_body is not None:
            # Cache hit
            cache_status = 'hit'
            # Added operation extraction and updated labels as per instructions
            operation = get_operation_from_path(full_path)
            cache_hits_total.labels(
                service=service_name,
                endpoint=full_path,
                method=method,
                operation=operation  # Added operation label
            ).inc()
            
            # Record duration
            duration = time.time() - start_time
            proxy_request_duration.labels(
                service=service_name,
                method=method,
                cache_status=cache_status
            ).observe(duration)
            
            # Return cached response
            response = Response(
                cached_body,
                status=cached_status,
                content_type='application/json'
            )
            response.headers['X-Cache-Status'] = 'HIT'
            return response
        else:
            # Cache miss
            cache_status = 'miss'
            # Added operation extraction and updated labels as per instructions
            operation = get_operation_from_path(full_path)
            cache_misses_total.labels(
                service=service_name,
                endpoint=full_path,
                method=method,
                operation=operation  # Added operation label
            ).inc()
    
    # Forward request to backend
    try:
        # Prepare request
        url = f"{backend_url}{full_path}"
        headers = {key: value for key, value in request.headers if key != 'Host'}
        
        # Make request
        backend_response = requests.request(
            method=method,
            url=url,
            headers=headers,
            params=request.args,
            json=request.get_json() if request.is_json else None,
            data=request.data if not request.is_json else None,
            timeout=30
        )
        
        # Cache successful GET responses
        if cache_rule and method == 'GET' and backend_response.status_code == 200:
            cache_proxy.set_in_cache(
                cache_key,
                backend_response.text,
                backend_response.status_code,
                cache_rule.ttl
            )
            cache_status = 'miss-stored'
        
        # Check if this request should invalidate cache
        invalidation_patterns = get_invalidation_patterns(full_path, method)
        if invalidation_patterns:
            cache_proxy.invalidate_cache(invalidation_patterns)
        
        # Record duration
        duration = time.time() - start_time
        proxy_request_duration.labels(
            service=service_name,
            method=method,
            cache_status=cache_status
        ).observe(duration)
        
        # Return response
        response = Response(
            backend_response.content,
            status=backend_response.status_code,
            headers=dict(backend_response.headers)
        )
        response.headers['X-Cache-Status'] = cache_status.upper()
        return response
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Backend request failed: {e}")
        
        # Record duration even for errors
        duration = time.time() - start_time
        proxy_request_duration.labels(
            service=service_name,
            method=method,
            cache_status='error'
        ).observe(duration)
        
        return jsonify({
            'error': 'Backend service unavailable',
            'service': service_name,
            'details': str(e)
        }), 503

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    redis_status = 'connected' if cache_proxy.redis_client else 'disconnected'
    
    # Update metrics
    cache_proxy.update_cache_metrics()
    
    return jsonify({
        'status': 'UP',
        'service': 'cache-proxy',
        'redis': redis_status,
        'timestamp': time.time()
    })

@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return Response(
        generate_latest(),
        mimetype=CONTENT_TYPE_LATEST
    )

@app.route('/cache/stats', methods=['GET'])
def cache_stats():
    """Get cache statistics"""
    stats = {
        'redis_connected': cache_proxy.redis_client is not None,
        'rules_configured': len(CACHE_RULES),
        'services_proxied': list(SERVICE_MAPPING.keys())
    }
    
    # Get cache entry count if Redis is connected
    if cache_proxy.redis_client:
        try:
            stats['cache_entries'] = len(cache_proxy.redis_client.keys("proxy:*"))
        except:
            stats['cache_entries'] = 0
    
    return jsonify(stats)

if __name__ == '__main__':
    logger.info("🚀 Starting Cache Proxy Service...")
    logger.info(f"📊 Metrics available at /metrics")
    logger.info(f"🏥 Health check at /health")
    logger.info(f"📈 Cache stats at /cache/stats")
    
    app.run(host='0.0.0.0', port=SERVICE_PORT, debug=False)