"""
Cache Rules Configuration
Defines caching patterns and TTL for banking operations
"""
import re
from typing import Dict, List, Optional, Tuple

class CacheRule:
    """Represents a single cache rule"""
    def __init__(self, pattern: str, ttl: int, methods: List[str], invalidate_on: List[str] = None):
        self.pattern = re.compile(pattern)
        self.ttl = ttl  # Time to live in seconds
        self.methods = methods  # HTTP methods to cache (usually GET)
        self.invalidate_on = invalidate_on or []  # Patterns that invalidate this cache
        
    def matches(self, path: str, method: str) -> bool:
        """Check if this rule matches the given path and method"""
        return method in self.methods and self.pattern.match(path) is not None
    
    def should_invalidate(self, path: str, method: str) -> bool:
        """Check if this request should invalidate the cache"""
        invalidation_key = f"{method} {path}"
        for pattern in self.invalidate_on:
            if re.match(pattern.replace('*', '.*'), invalidation_key):
                return True
        return False

# Define caching rules for banking operations
CACHE_RULES = {
    'account_list': CacheRule(
        pattern=r'^/accounts/?$',
        ttl=300,  # 5 minutes
        methods=['GET'],
        invalidate_on=['POST /accounts.*', 'PUT /accounts.*', 'DELETE /accounts.*']
    ),
    
    'account_detail': CacheRule(
        pattern=r'^/accounts/\d+/?$',
        ttl=60,  # 1 minute
        methods=['GET'],
        invalidate_on=[
            'PUT /accounts/\\d+.*',
            'POST /transactions.*',  # Transactions affect account balance
            'POST /transfer.*'
        ]
    ),
    
    'account_balance': CacheRule(
        pattern=r'^/accounts/\d+/balance/?$',
        ttl=30,  # 30 seconds - balance changes frequently
        methods=['GET'],
        invalidate_on=[
            'POST /transactions.*',
            'POST /transfer.*',
            'POST /deposit.*',
            'POST /withdraw.*'
        ]
    ),
    
    'transaction_list': CacheRule(
        pattern=r'^/transactions/?$',
        ttl=60,  # 1 minute
        methods=['GET'],
        invalidate_on=['POST /transactions.*']
    ),
    
    'transaction_detail': CacheRule(
        pattern=r'^/transactions/\d+/?$',
        ttl=3600,  # 1 hour - transactions don't change once created
        methods=['GET'],
        invalidate_on=[]  # Transactions are immutable
    ),
    
    'customer_profile': CacheRule(
        pattern=r'^/customers/\d+/?$',
        ttl=1800,  # 30 minutes
        methods=['GET'],
        invalidate_on=['PUT /customers/\\d+.*', 'PATCH /customers/\\d+.*']
    ),
    
    'fraud_alerts': CacheRule(
        pattern=r'^/fraud/alerts/?$',
        ttl=120,  # 2 minutes - fraud data is sensitive
        methods=['GET'],
        invalidate_on=['POST /fraud/.*']
    ),
    
    'auth_check': CacheRule(
        pattern=r'^/auth/verify/?$',
        ttl=300,  # 5 minutes
        methods=['GET'],
        invalidate_on=['POST /auth/logout.*', 'POST /auth/revoke.*']
    )
}

def get_cache_rule(path: str, method: str) -> Optional[CacheRule]:
    """Find the cache rule that matches the given path and method"""
    for rule_name, rule in CACHE_RULES.items():
        if rule.matches(path, method):
            return rule
    return None

def get_invalidation_patterns(path: str, method: str) -> List[str]:
    """Get all cache patterns that should be invalidated by this request"""
    patterns_to_invalidate = []
    
    for rule_name, rule in CACHE_RULES.items():
        if rule.should_invalidate(path, method):
            # Convert the rule pattern to a Redis key pattern
            redis_pattern = rule.pattern.pattern.replace(r'\d+', '*')
            patterns_to_invalidate.append(redis_pattern)
    
    return patterns_to_invalidate