import os
import json
import time
import random
import threading
from datetime import datetime
from flask import Flask, jsonify
import pika
from kafka import KafkaConsumer
from prometheus_client import Counter, Gauge, Histogram, generate_latest
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)

# Prometheus metrics setup
metrics = PrometheusMetrics(app, defaults_prefix='message_consumer')

# Custom metrics for queue consumption monitoring
messages_consumed = Counter(
    'banking_messages_consumed_total',
    'Total messages consumed',
    ['broker', 'queue_topic', 'message_type', 'status']
)

message_processing_duration = Histogram(
    'banking_message_processing_duration_seconds',
    'Time taken to process message',
    ['broker', 'queue_topic', 'message_type']
)

queue_consumer_lag = Gauge(
    'banking_queue_consumer_lag',
    'Number of messages behind the latest',
    ['broker', 'queue_topic']
)

active_consumers = Gauge(
    'banking_active_consumers',
    'Number of active consumer threads',
    ['broker', 'queue_topic']
)

unprocessed_messages = Gauge(
    'banking_unprocessed_messages',
    'Current number of unprocessed messages in queue',
    ['broker', 'queue_topic']
)

# Track processing delays to simulate real banking operations
processing_delays = {
    'transaction': (0.1, 0.5),    # Transaction processing takes 100-500ms
    'notification': (0.05, 0.2),   # Notifications are faster
    'fraud_check': (0.5, 2.0),     # Fraud checks take longer
    'auth_token': (0.05, 0.1),     # Auth is quick
    'audit_log': (0.01, 0.05)      # Audit logs are very fast
}

# RabbitMQ connections
rabbitmq_consumers = {}

def connect_rabbitmq():
    """Create RabbitMQ connection"""
    try:
        credentials = pika.PlainCredentials('admin', 'bankingdemo')
        parameters = pika.ConnectionParameters(
            host='rabbitmq',
            port=5672,
            credentials=credentials,
            heartbeat=600,
            blocked_connection_timeout=300
        )
        connection = pika.BlockingConnection(parameters)
        return connection
    except Exception as e:
        print(f"RabbitMQ connection failed: {e}")
        return None

def process_message(message_type, message_body):
    """Simulate message processing with realistic delays"""
    delay_min, delay_max = processing_delays.get(message_type, (0.1, 0.5))
    processing_time = random.uniform(delay_min, delay_max)
    
    with message_processing_duration.labels('rabbitmq', f'{message_type}_q', message_type).time():
        time.sleep(processing_time)
        
        # Simulate occasional processing failures
        if random.random() < 0.05:  # 5% failure rate
            return 'failed'
        return 'success'

def consume_rabbitmq_queue(queue_name, message_type):
    """Consumer for a specific RabbitMQ queue"""
    active_consumers.labels('rabbitmq', queue_name).inc()
    
    while True:
        connection = None
        try:
            connection = connect_rabbitmq()
            if not connection:
                time.sleep(5)
                continue
                
            channel = connection.channel()
            channel.queue_declare(queue=queue_name, durable=True)
            channel.basic_qos(prefetch_count=1)
            
            def callback(ch, method, properties, body):
                try:
                    message = json.loads(body)
                    status = process_message(message_type, message)
                    messages_consumed.labels('rabbitmq', queue_name, message_type, status).inc()
                    ch.basic_ack(delivery_tag=method.delivery_tag)
                except Exception as e:
                    print(f"Error processing message: {e}")
                    ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
                    messages_consumed.labels('rabbitmq', queue_name, message_type, 'error').inc()
            
            # Get queue statistics
            method = channel.queue_declare(queue=queue_name, durable=True, passive=True)
            message_count = method.method.message_count
            unprocessed_messages.labels('rabbitmq', queue_name).set(message_count)
            
            channel.basic_consume(queue=queue_name, on_message_callback=callback)
            print(f"Started consuming from {queue_name}")
            channel.start_consuming()
            
        except Exception as e:
            print(f"Consumer error for {queue_name}: {e}")
            time.sleep(5)
        finally:
            if connection and not connection.is_closed:
                connection.close()

def consume_kafka_topic(topic_name, consumer_group):
    """Consumer for Kafka topics"""
    active_consumers.labels('kafka', topic_name).inc()
    
    while True:
        try:
            consumer = KafkaConsumer(
                topic_name,
                bootstrap_servers=['kafka:29092'],
                group_id=consumer_group,
                value_deserializer=lambda m: json.loads(m.decode('utf-8')),
                enable_auto_commit=True,
                auto_offset_reset='earliest'
            )
            
            print(f"Started consuming from Kafka topic: {topic_name}")
            
            for message in consumer:
                try:
                    # Get consumer lag
                    partitions = consumer.assignment()
                    for partition in partitions:
                        end_offset = consumer.end_offsets([partition])[partition]
                        current_offset = consumer.position(partition)
                        lag = end_offset - current_offset
                        queue_consumer_lag.labels('kafka', topic_name).set(lag)
                    
                    # Process message
                    message_type = 'audit_log' if 'audit' in topic_name else 'transaction_event'
                    status = process_message(message_type, message.value)
                    messages_consumed.labels('kafka', topic_name, message_type, status).inc()
                    
                except Exception as e:
                    print(f"Error processing Kafka message: {e}")
                    messages_consumed.labels('kafka', topic_name, 'unknown', 'error').inc()
                    
        except Exception as e:
            print(f"Kafka consumer error: {e}")
            time.sleep(5)

def start_consumers():
    """Start all consumer threads"""
    # RabbitMQ consumers
    rabbitmq_queues = [
        ('transaction_processing_q', 'transaction'),
        ('notification_dispatch_q', 'notification'),
        ('fraud_check_q', 'fraud_check'),
        ('auth_token_q', 'auth_token')
    ]
    
    for queue_name, message_type in rabbitmq_queues:
        thread = threading.Thread(
            target=consume_rabbitmq_queue,
            args=(queue_name, message_type)
        )
        thread.daemon = True
        thread.start()
        rabbitmq_consumers[queue_name] = thread
    
    # Kafka consumers (moderate use)
    kafka_topics = [
        ('transaction-events', 'banking-consumer-group'),
        ('audit-logs', 'banking-audit-group')
    ]
    
    for topic_name, consumer_group in kafka_topics:
        thread = threading.Thread(
            target=consume_kafka_topic,
            args=(topic_name, consumer_group)
        )
        thread.daemon = True
        thread.start()

def update_queue_metrics():
    """Background thread to update queue depth metrics"""
    while True:
        try:
            connection = connect_rabbitmq()
            if connection:
                channel = connection.channel()
                
                queues = [
                    'transaction_processing_q',
                    'notification_dispatch_q',
                    'fraud_check_q',
                    'auth_token_q',
                    'core_banking_updates_q'
                ]
                
                for queue in queues:
                    try:
                        method = channel.queue_declare(queue=queue, durable=True, passive=True)
                        message_count = method.method.message_count
                        consumer_count = method.method.consumer_count
                        
                        unprocessed_messages.labels('rabbitmq', queue).set(message_count)
                        
                        # Simulate consumer lag for RabbitMQ
                        if consumer_count > 0 and message_count > 0:
                            estimated_lag = message_count / consumer_count
                            queue_consumer_lag.labels('rabbitmq', queue).set(estimated_lag)
                            
                    except Exception as e:
                        print(f"Error checking queue {queue}: {e}")
                
                connection.close()
                
        except Exception as e:
            print(f"Metrics update error: {e}")
            
        time.sleep(10)  # Update every 10 seconds

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'UP',
        'consumers': len(rabbitmq_consumers),
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/consumer/status', methods=['GET'])
def consumer_status():
    """Get detailed consumer status"""
    status = {}
    
    try:
        connection = connect_rabbitmq()
        if connection:
            channel = connection.channel()
            
            queues = [
                'transaction_processing_q',
                'notification_dispatch_q',
                'fraud_check_q',
                'auth_token_q'
            ]
            
            for queue in queues:
                try:
                    method = channel.queue_declare(queue=queue, durable=True, passive=True)
                    status[queue] = {
                        'messages': method.method.message_count,
                        'consumers': method.method.consumer_count
                    }
                except Exception as e:
                    status[queue] = {'error': str(e)}
            
            connection.close()
            
    except Exception as e:
        status['error'] = str(e)
    
    return jsonify(status)

@app.route('/metrics')
def metrics_endpoint():
    """Expose metrics for Prometheus"""
    return generate_latest()

if __name__ == '__main__':
    # Wait for services to be ready
    time.sleep(15)
    
    # Start consumer threads
    start_consumers()
    
    # Start metrics update thread
    metrics_thread = threading.Thread(target=update_queue_metrics)
    metrics_thread.daemon = True
    metrics_thread.start()
    
    # Start Flask app
    app.run(host='0.0.0.0', port=5008, debug=False)