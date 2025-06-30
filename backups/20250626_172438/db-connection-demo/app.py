import os
import time
import random
import threading
import psycopg2
from psycopg2 import pool
from datetime import datetime
from flask import Flask, jsonify, request
from prometheus_client import Counter, Gauge, Histogram, generate_latest
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)

# Prometheus metrics setup
metrics = PrometheusMetrics(app, defaults_prefix='db_connection_demo')

# Custom metrics for connection pool monitoring
db_pool_size = Gauge(
    'banking_db_pool_size',
    'Maximum size of the connection pool',
    ['service']
)

db_pool_active = Gauge(
    'banking_db_pool_connections_active',
    'Number of active connections in the pool',
    ['service']
)

db_pool_idle = Gauge(
    'banking_db_pool_connections_idle',
    'Number of idle connections in the pool',
    ['service']
)

db_pool_utilization = Gauge(
    'banking_db_pool_utilization_percent',
    'Percentage of pool connections in use',
    ['service']
)

db_connection_wait_time = Histogram(
    'banking_db_connection_acquisition_duration_seconds',
    'Time waiting to acquire a connection from the pool',
    ['service', 'operation'],
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0)
)

db_query_duration = Histogram(
    'banking_db_query_duration_seconds',
    'Database query execution time',
    ['service', 'query_type']
)

db_connection_errors = Counter(
    'banking_db_connection_errors_total',
    'Total number of database connection errors',
    ['service', 'error_type']
)

db_queries_total = Counter(
    'banking_db_queries_total',
    'Total number of database queries executed',
    ['service', 'query_type', 'status']
)

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DATABASE_URL', 'postgres').split('@')[-1].split(':')[0] if '@' in os.getenv('DATABASE_URL', 'postgres') else 'postgres',
    'port': 5432,
    'database': 'bankingdb',
    'user': 'bankinguser',
    'password': 'bankingpass'
}

# Connection pool configuration
POOL_MIN_SIZE = int(os.getenv('POOL_MIN_SIZE', '5'))
POOL_MAX_SIZE = int(os.getenv('POOL_MAX_SIZE', '20'))

# Global connection pool
connection_pool = None

def init_connection_pool():
    """Initialize the connection pool"""
    global connection_pool
    try:
        connection_pool = psycopg2.pool.ThreadedConnectionPool(
            POOL_MIN_SIZE,
            POOL_MAX_SIZE,
            **DB_CONFIG
        )
        print(f"Connection pool initialized: min={POOL_MIN_SIZE}, max={POOL_MAX_SIZE}")
        
        # Set initial metrics
        db_pool_size.labels('db-demo').set(POOL_MAX_SIZE)
        update_pool_metrics()
        
        return True
    except Exception as e:
        print(f"Failed to initialize connection pool: {e}")
        db_connection_errors.labels('db-demo', 'pool_init').inc()
        return False

def update_pool_metrics():
    """Update connection pool metrics"""
    if not connection_pool:
        return
    
    try:
        # This is a simplified metric update
        # In production, you'd use the actual pool stats
        used_connections = len(connection_pool._used)
        idle_connections = len(connection_pool._pool)
        
        db_pool_active.labels('db-demo').set(used_connections)
        db_pool_idle.labels('db-demo').set(idle_connections)
        
        utilization = (used_connections / POOL_MAX_SIZE) * 100 if POOL_MAX_SIZE > 0 else 0
        db_pool_utilization.labels('db-demo').set(utilization)
        
    except Exception as e:
        print(f"Error updating pool metrics: {e}")

def get_connection():
    """Get a connection from the pool with timing"""
    start_time = time.time()
    conn = None
    
    try:
        conn = connection_pool.getconn()
        wait_time = time.time() - start_time
        db_connection_wait_time.labels('db-demo', 'acquire').observe(wait_time)
        update_pool_metrics()
        return conn
    except Exception as e:
        db_connection_errors.labels('db-demo', 'acquire').inc()
        raise e

def return_connection(conn):
    """Return a connection to the pool"""
    if conn:
        connection_pool.putconn(conn)
        update_pool_metrics()

def execute_query(query_type, query, params=None):
    """Execute a database query with metrics"""
    conn = None
    cursor = None
    
    try:
        # Get connection
        conn = get_connection()
        cursor = conn.cursor()
        
        # Execute query with timing
        with db_query_duration.labels('db-demo', query_type).time():
            cursor.execute(query, params)
            
            if query_type in ['select', 'count']:
                result = cursor.fetchall()
            else:
                conn.commit()
                result = cursor.rowcount
        
        db_queries_total.labels('db-demo', query_type, 'success').inc()
        return result
        
    except Exception as e:
        if conn:
            conn.rollback()
        db_queries_total.labels('db-demo', query_type, 'error').inc()
        db_connection_errors.labels('db-demo', query_type).inc()
        raise e
        
    finally:
        if cursor:
            cursor.close()
        if conn:
            return_connection(conn)

def simulate_banking_operations():
    """Background thread simulating various banking database operations"""
    operations = [
        ('account_balance', "SELECT balance FROM demo_accounts WHERE account_number = %s"),
        ('transaction_history', "SELECT * FROM demo_transactions WHERE from_account = %s OR to_account = %s LIMIT 10"),
        ('insert_transaction', "INSERT INTO demo_transactions (from_account, to_account, amount) VALUES (%s, %s, %s)"),
        ('update_balance', "UPDATE demo_accounts SET balance = balance + %s WHERE account_number = %s"),
        ('audit_log', "INSERT INTO demo_audit_log (action, user_id, details) VALUES (%s, %s, %s)")
    ]
    
    account_numbers = ['ACC1001', 'ACC1002', 'ACC1003', 'ACC1004', 'ACC1005']
    
    while True:
        try:
            # Randomly select an operation
            op_name, query = random.choice(operations)
            
            if op_name == 'account_balance':
                account = random.choice(account_numbers)
                execute_query('select', query, (account,))
                
            elif op_name == 'transaction_history':
                account = random.choice(account_numbers)
                execute_query('select', query, (account, account))
                
            elif op_name == 'insert_transaction':
                from_acc = random.choice(account_numbers)
                to_acc = random.choice([a for a in account_numbers if a != from_acc])
                amount = round(random.uniform(10, 1000), 2)
                execute_query('insert', query, (from_acc, to_acc, amount))
                
            elif op_name == 'update_balance':
                account = random.choice(account_numbers)
                amount = round(random.uniform(-100, 100), 2)
                execute_query('update', query, (amount, account))
                
            elif op_name == 'audit_log':
                action = random.choice(['login', 'transfer', 'balance_check'])
                user_id = f"USER{random.randint(1000, 9999)}"
                details = {'timestamp': datetime.utcnow().isoformat()}
                execute_query('insert', query, (action, user_id, json.dumps(details)))
            
            # Vary the load
            sleep_time = random.uniform(0.1, 1.0)
            time.sleep(sleep_time)
            
        except Exception as e:
            print(f"Operation error: {e}")
            time.sleep(5)

def stress_test_connections():
    """Simulate connection pool stress"""
    connections = []
    
    try:
        # Try to acquire many connections quickly
        for i in range(POOL_MAX_SIZE + 5):  # Try to exceed pool size
            try:
                conn = get_connection()
                connections.append(conn)
                print(f"Acquired connection {i+1}")
                time.sleep(0.1)
            except Exception as e:
                print(f"Failed to acquire connection {i+1}: {e}")
                db_connection_errors.labels('db-demo', 'pool_exhausted').inc()
                break
        
        # Hold connections for a bit
        time.sleep(5)
        
    finally:
        # Release all connections
        for conn in connections:
            return_connection(conn)
        print(f"Released {len(connections)} connections")

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        # Test database connection
        result = execute_query('select', "SELECT 1")
        db_status = 'connected'
    except:
        db_status = 'disconnected'
    
    return jsonify({
        'status': 'UP' if db_status == 'connected' else 'DOWN',
        'database': db_status,
        'pool_size': POOL_MAX_SIZE,
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/pool/status', methods=['GET'])
def pool_status():
    """Get current connection pool status"""
    if not connection_pool:
        return jsonify({'error': 'Pool not initialized'}), 500
    
    try:
        used = len(connection_pool._used)
        idle = len(connection_pool._pool)
        utilization = (used / POOL_MAX_SIZE) * 100 if POOL_MAX_SIZE > 0 else 0
        
        # Get database connection stats
        result = execute_query('select', """
            SELECT state, count(*) 
            FROM pg_stat_activity 
            WHERE datname = current_database() 
            GROUP BY state
        """)
        
        db_states = dict(result) if result else {}
        
        return jsonify({
            'pool': {
                'max_size': POOL_MAX_SIZE,
                'min_size': POOL_MIN_SIZE,
                'active_connections': used,
                'idle_connections': idle,
                'utilization_percent': round(utilization, 2)
            },
            'database': {
                'total_connections': sum(db_states.values()),
                'states': db_states
            }
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/pool/stress-test', methods=['POST'])
def trigger_stress_test():
    """Trigger a connection pool stress test"""
    thread = threading.Thread(target=stress_test_connections)
    thread.daemon = True
    thread.start()
    
    return jsonify({
        'message': 'Stress test started',
        'pool_size': POOL_MAX_SIZE
    })

@app.route('/metrics')
def metrics_endpoint():
    """Expose metrics for Prometheus"""
    return generate_latest()

if __name__ == '__main__':
    # Wait for PostgreSQL to be ready
    time.sleep(10)
    
    # Initialize connection pool
    if init_connection_pool():
        # Start background operations
        ops_thread = threading.Thread(target=simulate_banking_operations)
        ops_thread.daemon = True
        ops_thread.start()
        
        # Start metrics updater
        def update_metrics_loop():
            while True:
                update_pool_metrics()
                time.sleep(5)
        
        metrics_thread = threading.Thread(target=update_metrics_loop)
        metrics_thread.daemon = True
        metrics_thread.start()
    
    # Import json for audit log
    import json
    
    # Start Flask app
    app.run(host='0.0.0.0', port=5006, debug=False)