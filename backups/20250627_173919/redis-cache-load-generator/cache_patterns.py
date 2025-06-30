"""
Cache Pattern Definitions for Banking Operations
Defines different cache access patterns to simulate realistic banking workloads
"""
import random
import json
from datetime import datetime, timedelta
from faker import Faker

fake = Faker()

class CachePatterns:
    """Defines various cache access patterns for banking operations"""
    
    @staticmethod
    def generate_account_id():
        """Generate realistic account ID"""
        return f"ACC{random.randint(100000, 999999)}"
    
    @staticmethod
    def generate_customer_id():
        """Generate realistic customer ID"""
        return f"CUST{random.randint(10000, 99999)}"
    
    @staticmethod
    def generate_transaction_id():
        """Generate realistic transaction ID"""
        return f"TXN{datetime.now().strftime('%Y%m%d')}{random.randint(10000, 99999)}"
    
    @staticmethod
    def generate_session_id():
        """Generate realistic session ID"""
        return fake.uuid4()

class NormalTrafficPattern:
    """Normal banking traffic pattern"""
    
    def __init__(self):
        self.name = "normal_traffic"
        # Create a pool of frequently accessed accounts (80/20 rule)
        self.hot_accounts = [CachePatterns.generate_account_id() for _ in range(20)]
        self.warm_accounts = [CachePatterns.generate_account_id() for _ in range(80)]
    
    def generate_operations(self, count=100):
        """Generate normal cache operations"""
        operations = []
        
        for _ in range(count):
            op_type = random.choices(
                ['balance_check', 'profile_view', 'transaction_history', 'session_check'],
                weights=[40, 20, 25, 15]
            )[0]
            
            if op_type == 'balance_check':
                # 80% hot accounts, 20% warm accounts
                if random.random() < 0.8:
                    account_id = random.choice(self.hot_accounts)
                else:
                    account_id = random.choice(self.warm_accounts)
                
                operations.append({
                    'operation': 'get',
                    'key': f'account:{account_id}:balance',
                    'ttl': 60,
                    'data': {
                        'balance': round(random.uniform(100, 100000), 2),
                        'currency': 'USD',
                        'last_updated': datetime.now().isoformat()
                    }
                })
            
            elif op_type == 'profile_view':
                customer_id = CachePatterns.generate_customer_id()
                operations.append({
                    'operation': 'get',
                    'key': f'customer:{customer_id}:profile',
                    'ttl': 3600,
                    'data': {
                        'name': fake.name(),
                        'email': fake.email(),
                        'phone': fake.phone_number(),
                        'member_since': fake.date_between(start_date='-5y').isoformat()
                    }
                })
            
            elif op_type == 'transaction_history':
                account_id = random.choice(self.hot_accounts + self.warm_accounts)
                operations.append({
                    'operation': 'get',
                    'key': f'transaction:{account_id}:history',
                    'ttl': 300,
                    'data': {
                        'transactions': [
                            {
                                'id': CachePatterns.generate_transaction_id(),
                                'amount': round(random.uniform(-500, 1000), 2),
                                'date': fake.date_time_between(start_date='-30d').isoformat()
                            } for _ in range(10)
                        ]
                    }
                })
            
            else:  # session_check
                session_id = CachePatterns.generate_session_id()
                operations.append({
                    'operation': 'get',
                    'key': f'session:{session_id}',
                    'ttl': 1800,
                    'data': {
                        'user_id': CachePatterns.generate_customer_id(),
                        'created_at': datetime.now().isoformat(),
                        'last_activity': datetime.now().isoformat()
                    }
                })
        
        return operations

class CacheStampedePattern:
    """Simulates cache stampede scenario"""
    
    def __init__(self):
        self.name = "cache_stampede"
        self.popular_key = f"account:{CachePatterns.generate_account_id()}:balance"
    
    def generate_operations(self, count=100):
        """Generate operations that cause cache stampede"""
        operations = []
        
        # 70% requests for the same popular key
        for _ in range(int(count * 0.7)):
            operations.append({
                'operation': 'get',
                'key': self.popular_key,
                'ttl': 10,  # Short TTL to increase stampede likelihood
                'data': {
                    'balance': 50000.00,
                    'currency': 'USD',
                    'last_updated': datetime.now().isoformat()
                }
            })
        
        # 30% normal traffic
        normal = NormalTrafficPattern()
        operations.extend(normal.generate_operations(int(count * 0.3)))
        
        return operations

class HighEvictionPattern:
    """Simulates scenario causing high eviction rate"""
    
    def __init__(self):
        self.name = "high_eviction"
    
    def generate_operations(self, count=100):
        """Generate operations with unique keys to cause evictions"""
        operations = []
        
        for i in range(count):
            # Generate mostly unique keys
            unique_id = f"{CachePatterns.generate_account_id()}_{i}"
            operations.append({
                'operation': 'set',
                'key': f'temp:large_data:{unique_id}',
                'ttl': 3600,
                'data': {
                    'large_field': 'x' * 1000,  # 1KB of data
                    'metadata': {
                        'created': datetime.now().isoformat(),
                        'index': i
                    }
                }
            })
        
        return operations

class BurstTrafficPattern:
    """Simulates burst traffic (e.g., during market open)"""
    
    def __init__(self):
        self.name = "burst_traffic"
        self.accounts = [CachePatterns.generate_account_id() for _ in range(100)]
    
    def generate_operations(self, count=100):
        """Generate burst of cache operations"""
        operations = []
        
        # 90% balance checks during burst
        for _ in range(int(count * 0.9)):
            account_id = random.choice(self.accounts)
            operations.append({
                'operation': 'get',
                'key': f'account:{account_id}:balance',
                'ttl': 30,  # Shorter TTL during high activity
                'data': {
                    'balance': round(random.uniform(100, 100000), 2),
                    'currency': 'USD',
                    'last_updated': datetime.now().isoformat()
                }
            })
        
        # 10% fraud checks
        for _ in range(int(count * 0.1)):
            account_id = random.choice(self.accounts)
            operations.append({
                'operation': 'get',
                'key': f'fraud:{account_id}:score',
                'ttl': 120,
                'data': {
                    'score': round(random.uniform(0, 100), 2),
                    'last_checked': datetime.now().isoformat()
                }
            })
        
        return operations

class CacheMissPattern:
    """Simulates high cache miss scenario"""
    
    def __init__(self):
        self.name = "cache_miss"
    
    def generate_operations(self, count=100):
        """Generate operations that mostly miss cache"""
        operations = []
        
        for i in range(count):
            # Always use new keys to ensure cache misses
            operations.append({
                'operation': 'get',
                'key': f'missing:key:{fake.uuid4()}',
                'ttl': None,  # Won't be cached
                'data': None   # Miss
            })
        
        return operations

# Pattern registry
AVAILABLE_PATTERNS = {
    'normal': NormalTrafficPattern,
    'stampede': CacheStampedePattern,
    'eviction': HighEvictionPattern,
    'burst': BurstTrafficPattern,
    'miss': CacheMissPattern
}