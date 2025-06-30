"""
Redis Cache Analyzer Service
Monitors Redis cache performance for banking operations
"""
import time
import logging
import json
from datetime import datetime, timedelta
from threading import Thread
from flask import Flask, jsonify
import redis
from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST
from apscheduler.schedulers.background import BackgroundScheduler
from config import Config

# Configure logging
logging.basicConfig(
    level=getattr(logging, Config.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Prometheus metrics
cache_hit_ratio = Gauge(
    f'{Config.METRICS_PREFIX}hit_ratio',
    'Cache hit ratio by operation type',
    ['operation']
)

cache_eviction_rate = Gauge(
    f'{Config.METRICS_PREFIX}eviction_rate',
    'Number of keys evicted per minute'
)

cache_memory_usage = Gauge(
    f'{Config.METRICS_PREFIX}memory_usage_bytes',
    'Current Redis memory usage in bytes'
)

cache_key_count = Gauge(
    f'{Config.METRICS_PREFIX}key_count',
    'Number of keys by pattern',
    ['pattern']
)

cache_operation_latency = Histogram(
    f'{Config.METRICS_PREFIX}operation_latency_seconds',
    'Cache operation latency by type',
    ['operation', 'status']
)

cache_efficiency_score = Gauge(
    f'{Config.METRICS_PREFIX}efficiency_score',
    'Overall cache efficiency score (0-100)'
)

analysis_errors = Counter(
    f'{Config.METRICS_PREFIX}analysis_errors_total',
    'Total number of analysis errors'
)

class RedisCacheAnalyzer:
    """Analyzes Redis cache patterns for banking operations"""
    
    def __init__(self):
        self.redis_client = None
        self.previous_stats = {}
        self.cache_stats = {}
        self.scheduler = BackgroundScheduler()
        self.is_connected = False
        
    def connect_redis(self):
        """Establish Redis connection"""
        try:
            self.redis_client = redis.Redis(
                host=Config.REDIS_HOST,
                port=Config.REDIS_PORT,
                password=Config.REDIS_PASSWORD,
                db=Config.REDIS_DB,
                decode_responses=True
            )
            # Test connection
            self.redis_client.ping()
            self.is_connected = True
            logger.info(f"✅ Connected to Redis at {Config.REDIS_HOST}:{Config.REDIS_PORT}")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to connect to Redis: {e}")
            self.is_connected = False
            return False
    
    def analyze_cache_patterns(self):
        """Analyze cache usage patterns"""
        if not self.is_connected:
            if not self.connect_redis():
                analysis_errors.inc()
                return
        
        try:
            # Get Redis INFO stats
            info = self.redis_client.info()
            memory_info = self.redis_client.info('memory')
            stats = self.redis_client.info('stats')
            
            # Update memory usage
            cache_memory_usage.set(memory_info.get('used_memory', 0))
            
            # Calculate hit ratio
            hits = stats.get('keyspace_hits', 0)
            misses = stats.get('keyspace_misses', 0)
            total_ops = hits + misses
            
            if total_ops > 0:
                hit_ratio = hits / total_ops
                cache_hit_ratio.labels(operation='overall').set(hit_ratio)
            
            # Calculate eviction rate
            current_evictions = stats.get('evicted_keys', 0)
            if 'evicted_keys' in self.previous_stats:
                eviction_delta = current_evictions - self.previous_stats['evicted_keys']
                eviction_rate_per_min = eviction_delta * 2  # Since we check every 30 seconds
                cache_eviction_rate.set(eviction_rate_per_min)
            
            self.previous_stats['evicted_keys'] = current_evictions
            
            # Analyze keys by pattern
            self._analyze_key_patterns()
            
            # Calculate efficiency score
            self._calculate_efficiency_score(hit_ratio if total_ops > 0 else 0)
            
        except Exception as e:
            logger.error(f"Error during cache analysis: {e}")
            analysis_errors.inc()
    
    def _analyze_key_patterns(self):
        """Analyze keys by banking operation patterns"""
        try:
            for pattern_name, pattern in Config.CACHE_KEY_PATTERNS.items():
                # Count keys matching pattern
                keys = list(self.redis_client.scan_iter(match=pattern, count=1000))
                count = len(keys)
                cache_key_count.labels(pattern=pattern_name).set(count)
                
                # Sample some keys to check TTL
                sample_size = min(10, count)
                if sample_size > 0:
                    for i in range(sample_size):
                        key = keys[i]
                        ttl = self.redis_client.ttl(key)
                        # Log if TTL differs significantly from recommendation
                        recommended_ttl = Config.TTL_RECOMMENDATIONS.get(pattern_name, 300)
                        if ttl > 0 and abs(ttl - recommended_ttl) > recommended_ttl * 0.5:
                            logger.warning(
                                f"TTL mismatch for {pattern_name}: "
                                f"key={key}, current_ttl={ttl}s, recommended={recommended_ttl}s"
                            )
        except Exception as e:
            logger.error(f"Error analyzing key patterns: {e}")
    
    def _calculate_efficiency_score(self, hit_ratio):
        """Calculate overall cache efficiency score"""
        score = 0.0
        
        # Hit ratio contributes 50% to score
        score += hit_ratio * 50
        
        # Low eviction rate contributes 30%
        current_eviction = cache_eviction_rate._value.get() or 0
        if current_eviction < Config.EVICTION_RATE_WARNING:
            eviction_score = 30
        else:
            eviction_score = max(0, 30 - (current_eviction / 10))
        score += eviction_score
        
        # Memory usage efficiency contributes 20%
        memory_used = cache_memory_usage._value.get() or 0
        memory_limit = 1073741824  # 1GB in bytes
        memory_efficiency = min(memory_used / memory_limit, 1.0)
        if 0.3 < memory_efficiency < 0.8:  # Optimal range
            score += 20
        else:
            score += 10
        
        cache_efficiency_score.set(score)
        
        # Log warnings if score is low
        if score < 70:
            logger.warning(f"Low cache efficiency score: {score:.1f}")
            if hit_ratio < Config.CACHE_HIT_RATIO_WARNING:
                logger.warning(f"Cache hit ratio below warning threshold: {hit_ratio:.2%}")
    
    def start(self):
        """Start the analyzer"""
        if self.connect_redis():
            # Schedule periodic analysis
            self.scheduler.add_job(
                func=self.analyze_cache_patterns,
                trigger="interval",
                seconds=Config.ANALYSIS_INTERVAL_SECONDS,
                id='cache_analysis'
            )
            self.scheduler.start()
            logger.info("✅ Redis Cache Analyzer started")
            
            # Run initial analysis
            self.analyze_cache_patterns()
    
    def stop(self):
        """Stop the analyzer"""
        self.scheduler.shutdown()
        if self.redis_client:
            self.redis_client.close()

# Initialize analyzer
analyzer = RedisCacheAnalyzer()

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy' if analyzer.is_connected else 'unhealthy',
        'service': Config.SERVICE_NAME,
        'redis_connected': analyzer.is_connected,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/cache-stats')
def cache_stats():
    """Get current cache statistics"""
    try:
        if not analyzer.is_connected:
            return jsonify({'error': 'Redis not connected'}), 503
        
        info = analyzer.redis_client.info('stats')
        memory = analyzer.redis_client.info('memory')
        
        return jsonify({
            'hit_ratio': cache_hit_ratio._value.get() or 0,
            'eviction_rate': cache_eviction_rate._value.get() or 0,
            'memory_usage_mb': round(memory.get('used_memory', 0) / 1048576, 2),
            'total_keys': info.get('keys', 0),
            'efficiency_score': cache_efficiency_score._value.get() or 0,
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/recommendations')
def recommendations():
    """Get cache optimization recommendations"""
    recommendations = []
    
    # Check hit ratio
    hit_ratio = cache_hit_ratio._value.get() or 0
    if hit_ratio < Config.CACHE_HIT_RATIO_CRITICAL:
        recommendations.append({
            'severity': 'critical',
            'issue': 'Very low cache hit ratio',
            'current': f"{hit_ratio:.1%}",
            'recommendation': 'Review cache key patterns and TTL settings'
        })
    elif hit_ratio < Config.CACHE_HIT_RATIO_WARNING:
        recommendations.append({
            'severity': 'warning',
            'issue': 'Low cache hit ratio',
            'current': f"{hit_ratio:.1%}",
            'recommendation': 'Consider increasing cache TTL for frequently accessed data'
        })
    
    # Check eviction rate
    eviction_rate = cache_eviction_rate._value.get() or 0
    if eviction_rate > Config.EVICTION_RATE_WARNING:
        recommendations.append({
            'severity': 'warning',
            'issue': 'High eviction rate',
            'current': f"{eviction_rate:.0f} keys/min",
            'recommendation': 'Consider increasing Redis memory limit'
        })
    
    return jsonify({
        'recommendations': recommendations,
        'ttl_recommendations': Config.TTL_RECOMMENDATIONS,
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    # Start the analyzer
    analyzer.start()
    
    # Run Flask app
    logger.info(f"Starting {Config.SERVICE_NAME} on port {Config.SERVICE_PORT}")
    app.run(host='0.0.0.0', port=Config.SERVICE_PORT, debug=False)