import os
import json
import time
import random
import threading
from datetime import datetime
from flask import Flask, jsonify, request
import pika
from kafka import KafkaProducer
from prometheus_client import Counter, Gauge, Histogram, generate_latest
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)

# Prometheus metrics setup
metrics = PrometheusMetrics(app, defaults_prefix='message_producer')

# Custom metrics for message queue monitoring
messages_published = Counter(
    'banking_messages_published_total',
    'Total messages published',
    ['broker', 'queue_topic', 'message_type']
)

queue_publish_duration = Histogram(
    'banking_queue_publish_duration_seconds',
    'Time taken to publish message',
    ['broker', 'queue_topic']
)

active_publishers = Gauge(
    'banking_active_publishers',
    'Number of active publisher threads',
    ['broker']
)

# RabbitMQ connection setup
rabbitmq_connection = None
rabbitmq_channel = None

# Kafka producer setup
kafka_producer = None

def setup_rabbitmq():
    """Initialize RabbitMQ connection and declare queues"""
    global rabbitmq_connection, rabbitmq_channel
    try:
        credentials = pika.PlainCredentials('admin', 'bankingdemo')
        parameters = pika.ConnectionParameters(
            host='rabbitmq',
            port=5672,
            credentials=credentials,
            heartbeat=600,
            blocked_connection_timeout=300
        )
        rabbitmq_connection = pika.BlockingConnection(parameters)
        rabbitmq_channel = rabbitmq_connection.channel()
        
        # Declare queues for banking operations
        queues = [
            'transaction_processing_q',
            'notification_dispatch_q',
            'fraud_check_q',
            'auth_token_q',
            'core_banking_updates_q'
        ]
        
        for queue in queues:
            rabbitmq_channel.queue_declare(queue=queue, durable=True)
        
        print("RabbitMQ setup completed")
        return True
    except Exception as e:
        print(f"RabbitMQ setup failed: {e}")
        return False

def setup_kafka():
    """Initialize Kafka producer"""
    global kafka_producer
    try:
        kafka_producer = KafkaProducer(
            bootstrap_servers=['kafka:29092'],
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            acks='all',
            retries=3
        )
        print("Kafka setup completed")
        return True
    except Exception as e:
        print(f"Kafka setup failed: {e}")
        return False

def publish_to_rabbitmq(queue_name, message, message_type):
    """Publish message to RabbitMQ queue"""
    if not rabbitmq_channel:
        return False
    
    try:
        with queue_publish_duration.labels('rabbitmq', queue_name).time():
            rabbitmq_channel.basic_publish(
                exchange='',
                routing_key=queue_name,
                body=json.dumps(message),
                properties=pika.BasicProperties(
                    delivery_mode=2,  # make message persistent
                    content_type='application/json'
                )
            )
        messages_published.labels('rabbitmq', queue_name, message_type).inc()
        return True
    except Exception as e:
        print(f"RabbitMQ publish error: {e}")
        setup_rabbitmq()  # Try to reconnect
        return False

def publish_to_kafka(topic, message, message_type):
    """Publish message to Kafka topic"""
    if not kafka_producer:
        return False
    
    try:
        with queue_publish_duration.labels('kafka', topic).time():
            kafka_producer.send(topic, value=message)
            kafka_producer.flush(timeout=10)
        messages_published.labels('kafka', topic, message_type).inc()
        return True
    except Exception as e:
        print(f"Kafka publish error: {e}")
        setup_kafka()  # Try to reconnect
        return False

def generate_transaction_message():
    """Generate a sample transaction message"""
    return {
        'transaction_id': f"TXN{random.randint(100000, 999999)}",
        'account_from': f"ACC{random.randint(1000, 9999)}",
        'account_to': f"ACC{random.randint(1000, 9999)}",
        'amount': round(random.uniform(10, 5000), 2),
        'currency': 'USD',
        'type': random.choice(['transfer', 'payment', 'withdrawal']),
        'timestamp': datetime.utcnow().isoformat()
    }

def generate_notification_message():
    """Generate a sample notification message"""
    return {
        'notification_id': f"NOTIF{random.randint(100000, 999999)}",
        'user_id': f"USER{random.randint(1000, 9999)}",
        'type': random.choice(['transaction_alert', 'login_alert', 'fraud_warning']),
        'channel': random.choice(['email', 'sms', 'push']),
        'timestamp': datetime.utcnow().isoformat()
    }

def generate_fraud_check_message():
    """Generate a sample fraud check message"""
    return {
        'check_id': f"FRAUD{random.randint(100000, 999999)}",
        'transaction_id': f"TXN{random.randint(100000, 999999)}",
        'risk_score': round(random.uniform(0, 100), 2),
        'check_type': random.choice(['velocity', 'pattern', 'amount']),
        'timestamp': datetime.utcnow().isoformat()
    }

def generate_auth_token_message():
    """Generate a sample auth token message"""
    return {
        'token_id': f"TOKEN{random.randint(100000, 999999)}",
        'user_id': f"USER{random.randint(1000, 9999)}",
        'action': random.choice(['login', 'refresh', 'logout']),
        'ip_address': f"192.168.{random.randint(1, 255)}.{random.randint(1, 255)}",
        'timestamp': datetime.utcnow().isoformat()
    }

def background_message_generator():
    """Background thread that generates messages continuously"""
    active_publishers.labels('rabbitmq').inc()
    active_publishers.labels('kafka').inc()
    
    while True:
        try:
            # Generate and publish transaction messages (RabbitMQ - primary)
            if random.random() < 0.7:  # 70% chance
                msg = generate_transaction_message()
                publish_to_rabbitmq('transaction_processing_q', msg, 'transaction')
            
            # Generate and publish notification messages (RabbitMQ - primary)
            if random.random() < 0.5:  # 50% chance
                msg = generate_notification_message()
                publish_to_rabbitmq('notification_dispatch_q', msg, 'notification')
            
            # Generate and publish fraud check messages (RabbitMQ - primary)
            if random.random() < 0.3:  # 30% chance
                msg = generate_fraud_check_message()
                publish_to_rabbitmq('fraud_check_q', msg, 'fraud_check')
            
            # Generate and publish auth token messages (RabbitMQ - primary)
            if random.random() < 0.4:  # 40% chance
                msg = generate_auth_token_message()
                publish_to_rabbitmq('auth_token_q', msg, 'auth_token')
            
            # Kafka - Moderate use for audit logs and events
            if random.random() < 0.2:  # 20% chance - less frequent
                # Transaction event to Kafka
                event = {
                    'event_type': 'transaction_completed',
                    'data': generate_transaction_message(),
                    'timestamp': datetime.utcnow().isoformat()
                }
                publish_to_kafka('transaction-events', event, 'transaction_event')
            
            if random.random() < 0.1:  # 10% chance - audit logs
                # Audit log to Kafka
                audit = {
                    'action': random.choice(['login', 'transfer', 'account_update']),
                    'user_id': f"USER{random.randint(1000, 9999)}",
                    'result': random.choice(['success', 'failure']),
                    'timestamp': datetime.utcnow().isoformat()
                }
                publish_to_kafka('audit-logs', audit, 'audit_log')
            
            # Sleep between message generations
            time.sleep(random.uniform(0.5, 2.0))
            
        except Exception as e:
            print(f"Background generator error: {e}")
            time.sleep(5)

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    health = {
        'status': 'UP',
        'rabbitmq': 'connected' if rabbitmq_connection and not rabbitmq_connection.is_closed else 'disconnected',
        'kafka': 'connected' if kafka_producer else 'disconnected'
    }
    return jsonify(health)

@app.route('/publish/transaction', methods=['POST'])
def publish_transaction():
    """Manually publish a transaction message"""
    msg = generate_transaction_message()
    success = publish_to_rabbitmq('transaction_processing_q', msg, 'transaction')
    return jsonify({'success': success, 'message': msg})

@app.route('/publish/notification', methods=['POST'])
def publish_notification():
    """Manually publish a notification message"""
    msg = generate_notification_message()
    success = publish_to_rabbitmq('notification_dispatch_q', msg, 'notification')
    return jsonify({'success': success, 'message': msg})

@app.route('/metrics')
def metrics_endpoint():
    """Expose metrics for Prometheus"""
    return generate_latest()

if __name__ == '__main__':
    # Wait for services to be ready
    time.sleep(10)
    
    # Setup connections
    setup_rabbitmq()
    setup_kafka()
    
    # Start background message generator
    generator_thread = threading.Thread(target=background_message_generator)
    generator_thread.daemon = True
    generator_thread.start()
    
    # Start Flask app
    app.run(host='0.0.0.0', port=5007, debug=False)