"""
Redis Cache Analyzer Configuration
Manages all configuration settings for the cache analysis service
"""
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class Config:
    """Configuration settings for Redis Cache Analyzer"""
    
    # Service Settings
    SERVICE_NAME = "redis-cache-analyzer"
    SERVICE_PORT = int(os.getenv('SERVICE_PORT', '5012'))
    
    # Redis Connection
    REDIS_HOST = os.getenv('REDIS_HOST', 'banking-redis')
    REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))
    REDIS_PASSWORD = os.getenv('REDIS_PASSWORD', '')
    REDIS_DB = int(os.getenv('REDIS_DB', '0'))
    
    # Analysis Settings
    ANALYSIS_INTERVAL_SECONDS = int(os.getenv('ANALYSIS_INTERVAL', '30'))
    CACHE_KEY_PATTERNS = {
        'account_balance': 'account:*:balance',
        'customer_profile': 'customer:*:profile',
        'transaction_history': 'transaction:*:history',
        'auth_session': 'session:*',
        'fraud_score': 'fraud:*:score'
    }
    
    # Metrics Settings
    METRICS_PREFIX = "redis_cache_"
    
    # Performance Thresholds
    CACHE_HIT_RATIO_WARNING = float(os.getenv('HIT_RATIO_WARNING', '0.7'))
    CACHE_HIT_RATIO_CRITICAL = float(os.getenv('HIT_RATIO_CRITICAL', '0.5'))
    EVICTION_RATE_WARNING = int(os.getenv('EVICTION_WARNING', '100'))  # per minute
    
    # Banking-specific TTL recommendations (in seconds)
    TTL_RECOMMENDATIONS = {
        'account_balance': 60,      # 1 minute
        'customer_profile': 3600,   # 1 hour
        'transaction_history': 300, # 5 minutes
        'auth_session': 1800,       # 30 minutes
        'fraud_score': 120          # 2 minutes
    }
    
    # Logging
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    
    @classmethod
    def get_redis_url(cls):
        """Generate Redis connection URL"""
        if cls.REDIS_PASSWORD:
            return f"redis://:{cls.REDIS_PASSWORD}@{cls.REDIS_HOST}:{cls.REDIS_PORT}/{cls.REDIS_DB}"
        return f"redis://{cls.REDIS_HOST}:{cls.REDIS_PORT}/{cls.REDIS_DB}"