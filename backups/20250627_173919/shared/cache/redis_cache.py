"""
Redis Cache Integration Module for Banking Services
Provides caching functionality with monitoring support
"""
import json
import time
import logging
from functools import wraps
from typing import Optional, Any, Callable
import redis
from prometheus_client import Counter, Histogram, Gauge

logger = logging.getLogger(__name__)

# Prometheus metrics for cache operations
cache_hits = Counter(
    'banking_cache_hits_total',
    'Total number of cache hits',
    ['service', 'operation']
)

cache_misses = Counter(
    'banking_cache_misses_total',
    'Total number of cache misses',
    ['service', 'operation']
)

cache_operation_duration = Histogram(
    'banking_cache_operation_duration_seconds',
    'Cache operation duration',
    ['service', 'operation', 'action']
)

cache_errors = Counter(
    'banking_cache_errors_total',
    'Total number of cache errors',
    ['service', 'operation', 'error_type']
)

class BankingRedisCache:
    """Redis cache client for banking services"""
    
    def __init__(self, 
                 host='banking-redis',
                 port=6379,
                 db=0,
                 password=None,
                 service_name='unknown',
                 default_ttl=300):
        """
        Initialize Redis cache client
        
        Args:
            host: Redis host
            port: Redis port
            db: Redis database number
            password: Redis password (if any)
            service_name: Name of the service using the cache
            default_ttl: Default TTL in seconds
        """
        self.service_name = service_name
        self.default_ttl = default_ttl
        
        try:
            self.client = redis.Redis(
                host=host,
                port=port,
                db=db,
                password=password,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_keepalive=True,
                socket_keepalive_options={}
            )
            # Test connection
            self.client.ping()
            logger.info(f"Connected to Redis cache at {host}:{port}")
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            self.client = None
    
    def is_connected(self):
        """Check if Redis is connected"""
        if not self.client:
            return False
        try:
            self.client.ping()
            return True
        except:
            return False
    
    def get(self, key: str, operation: str = 'generic') -> Optional[Any]:
        """
        Get value from cache
        
        Args:
            key: Cache key
            operation: Operation name for metrics
            
        Returns:
            Cached value or None if not found
        """
        if not self.client:
            return None
        
        with cache_operation_duration.labels(
            service=self.service_name,
            operation=operation,
            action='get'
        ).time():
            try:
                value = self.client.get(key)
                if value is not None:
                    cache_hits.labels(
                        service=self.service_name,
                        operation=operation
                    ).inc()
                    # Deserialize JSON data
                    try:
                        return json.loads(value)
                    except json.JSONDecodeError:
                        return value
                else:
                    cache_misses.labels(
                        service=self.service_name,
                        operation=operation
                    ).inc()
                    return None
            except Exception as e:
                logger.error(f"Cache get error for key {key}: {e}")
                cache_errors.labels(
                    service=self.service_name,
                    operation=operation,
                    error_type=type(e).__name__
                ).inc()
                return None
    
    def set(self, key: str, value: Any, ttl: Optional[int] = None, 
            operation: str = 'generic') -> bool:
        """
        Set value in cache
        
        Args:
            key: Cache key
            value: Value to cache
            ttl: Time to live in seconds
            operation: Operation name for metrics
            
        Returns:
            True if successful, False otherwise
        """
        if not self.client:
            return False
        
        ttl = ttl or self.default_ttl
        
        with cache_operation_duration.labels(
            service=self.service_name,
            operation=operation,
            action='set'
        ).time():
            try:
                # Serialize data as JSON
                if isinstance(value, (dict, list)):
                    value = json.dumps(value)
                
                result = self.client.setex(key, ttl, value)
                return result
            except Exception as e:
                logger.error(f"Cache set error for key {key}: {e}")
                cache_errors.labels(
                    service=self.service_name,
                    operation=operation,
                    error_type=type(e).__name__
                ).inc()
                return False
    
    def delete(self, key: str, operation: str = 'generic') -> bool:
        """
        Delete key from cache
        
        Args:
            key: Cache key
            operation: Operation name for metrics
            
        Returns:
            True if key was deleted, False otherwise
        """
        if not self.client:
            return False
        
        with cache_operation_duration.labels(
            service=self.service_name,
            operation=operation,
            action='delete'
        ).time():
            try:
                result = self.client.delete(key)
                return result > 0
            except Exception as e:
                logger.error(f"Cache delete error for key {key}: {e}")
                cache_errors.labels(
                    service=self.service_name,
                    operation=operation,
                    error_type=type(e).__name__
                ).inc()
                return False
    
    def invalidate_pattern(self, pattern: str, operation: str = 'generic') -> int:
        """
        Invalidate all keys matching a pattern
        
        Args:
            pattern: Key pattern (e.g., 'account:*:balance')
            operation: Operation name for metrics
            
        Returns:
            Number of keys deleted
        """
        if not self.client:
            return 0
        
        with cache_operation_duration.labels(
            service=self.service_name,
            operation=operation,
            action='invalidate_pattern'
        ).time():
            try:
                keys = list(self.client.scan_iter(match=pattern, count=1000))
                if keys:
                    return self.client.delete(*keys)
                return 0
            except Exception as e:
                logger.error(f"Cache invalidate pattern error for {pattern}: {e}")
                cache_errors.labels(
                    service=self.service_name,
                    operation=operation,
                    error_type=type(e).__name__
                ).inc()
                return 0

# Cache decorator for methods
def cache_result(
    key_pattern: str,
    ttl: int = 300,
    operation: str = 'generic',
    invalidate_on: Optional[list] = None
):
    """
    Decorator to cache function results
    
    Args:
        key_pattern: Pattern for cache key (can include {arg_name} placeholders)
        ttl: Time to live in seconds
        operation: Operation name for metrics
        invalidate_on: List of method names that should invalidate this cache
        
    Example:
        @cache_result("account:{account_id}:balance", ttl=60, operation="get_balance")
        def get_account_balance(self, account_id):
            return self.db.query(...)
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(self, *args, **kwargs):
            # Check if self has cache attribute
            if not hasattr(self, '_cache') or not self._cache:
                # No cache available, execute function directly
                return func(self, *args, **kwargs)
            
            # Build cache key
            func_args = func.__code__.co_varnames[1:func.__code__.co_argcount]
            arg_dict = dict(zip(func_args, args))
            arg_dict.update(kwargs)
            
            try:
                cache_key = key_pattern.format(**arg_dict)
            except KeyError as e:
                logger.error(f"Invalid key pattern {key_pattern}: {e}")
                return func(self, *args, **kwargs)
            
            # Try to get from cache
            cached_value = self._cache.get(cache_key, operation)
            if cached_value is not None:
                # Add cache hit header if response object
                if hasattr(self, '_add_cache_header'):
                    self._add_cache_header('HIT')
                return cached_value
            
            # Execute function and cache result
            result = func(self, *args, **kwargs)
            
            # Cache the result
            if result is not None:
                self._cache.set(cache_key, result, ttl, operation)
            
            # Add cache miss header if response object
            if hasattr(self, '_add_cache_header'):
                self._add_cache_header('MISS')
            
            return result
        
        # Store metadata for cache invalidation
        wrapper._cache_config = {
            'key_pattern': key_pattern,
            'operation': operation,
            'invalidate_on': invalidate_on or []
        }
        
        return wrapper
    return decorator

def invalidate_cache(patterns: list):
    """
    Decorator to invalidate cache entries when a method is called
    
    Args:
        patterns: List of cache key patterns to invalidate
        
    Example:
        @invalidate_cache(["account:{account_id}:balance", "account:{account_id}:*"])
        def transfer_money(self, account_id, amount):
            # This will invalidate balance cache when transfer happens
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(self, *args, **kwargs):
            # Execute the function first
            result = func(self, *args, **kwargs)
            
            # Then invalidate cache if available
            if hasattr(self, '_cache') and self._cache:
                func_args = func.__code__.co_varnames[1:func.__code__.co_argcount]
                arg_dict = dict(zip(func_args, args))
                arg_dict.update(kwargs)
                
                for pattern in patterns:
                    try:
                        invalidate_pattern = pattern.format(**arg_dict)
                        count = self._cache.invalidate_pattern(
                            invalidate_pattern, 
                            operation=f"invalidate_{func.__name__}"
                        )
                        if count > 0:
                            logger.debug(f"Invalidated {count} cache entries for pattern: {invalidate_pattern}")
                    except KeyError as e:
                        logger.error(f"Invalid invalidation pattern {pattern}: {e}")
            
            return result
        return wrapper
    return decorator

# Example usage in a banking service:
"""
from shared.cache.redis_cache import BankingRedisCache, cache_result, invalidate_cache

class AccountService:
    def __init__(self):
        self._cache = BankingRedisCache(
            host='banking-redis',
            port=6379,
            service_name='account-service',
            default_ttl=300
        )
    
    @cache_result("account:{account_id}:balance", ttl=60, operation="get_balance")
    def get_account_balance(self, account_id: str):
        # This will be cached for 60 seconds
        return self.db.query_balance(account_id)
    
    @cache_result("customer:{customer_id}:profile", ttl=3600, operation="get_profile")
    def get_customer_profile(self, customer_id: str):
        # This will be cached for 1 hour
        return self.db.query_profile(customer_id)
    
    @invalidate_cache(["account:{from_account}:balance", "account:{to_account}:balance"])
    def transfer_money(self, from_account: str, to_account: str, amount: float):
        # This will invalidate balance cache for both accounts
        return self.db.execute_transfer(from_account, to_account, amount)
"""