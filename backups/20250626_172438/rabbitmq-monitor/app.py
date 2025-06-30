#!/usr/bin/env python3
"""
RabbitMQ Queue Depth Monitor
Polls RabbitMQ Management API and exposes queue metrics for Prometheus
"""

import os
import time
import requests
import logging
from datetime import datetime
from flask import Flask, Response
from prometheus_client import Gauge, Counter, generate_latest, REGISTRY
from apscheduler.schedulers.background import BackgroundScheduler

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Flask app
app = Flask(__name__)

# Configuration from environment variables
RABBITMQ_HOST = os.environ.get('RABBITMQ_HOST', 'banking-rabbitmq')
RABBITMQ_USER = os.environ.get('RABBITMQ_USER', 'admin')
RABBITMQ_PASS = os.environ.get('RABBITMQ_PASS', 'bankingdemo')
RABBITMQ_MGMT_PORT = os.environ.get('RABBITMQ_MGMT_PORT', '15672')
POLL_INTERVAL = int(os.environ.get('POLL_INTERVAL', '10'))  # seconds

# RabbitMQ Management API base URL
RABBITMQ_API_BASE = f"http://{RABBITMQ_HOST}:{RABBITMQ_MGMT_PORT}/api"

# Prometheus metrics
rabbitmq_queue_messages_ready = Gauge(
    'rabbitmq_queue_messages_ready',
    'Number of messages ready to be delivered',
    ['queue', 'vhost']
)

rabbitmq_queue_messages_unacked = Gauge(
    'rabbitmq_queue_messages_unacked',
    'Number of messages delivered but not acknowledged',
    ['queue', 'vhost']
)

rabbitmq_queue_messages_total = Gauge(
    'rabbitmq_queue_messages_total',
    'Total number of messages in queue',
    ['queue', 'vhost']
)

rabbitmq_queue_consumers = Gauge(
    'rabbitmq_queue_consumers',
    'Number of consumers for the queue',
    ['queue', 'vhost']
)

rabbitmq_queue_publish_rate = Gauge(
    'rabbitmq_queue_publish_rate',
    'Message publish rate',
    ['queue', 'vhost']
)

rabbitmq_queue_deliver_rate = Gauge(
    'rabbitmq_queue_deliver_rate',
    'Message delivery rate',
    ['queue', 'vhost']
)

# Monitor health metric
rabbitmq_monitor_up = Gauge(
    'rabbitmq_monitor_up',
    'RabbitMQ monitor health status (1 = up, 0 = down)'
)

# Error counter
rabbitmq_monitor_errors = Counter(
    'rabbitmq_monitor_errors',
    'Total number of errors encountered by the monitor',
    ['error_type']
)

# Queues to monitor (matching your existing setup)
MONITORED_QUEUES = [
    'transaction_processing_q',
    'notification_dispatch_q',
    'fraud_check_q',
    'auth_token_q',
    'core_banking_updates_q'
]


class RabbitMQMonitor:
    """Monitors RabbitMQ queue depths via Management API"""
    
    def __init__(self):
        self.session = requests.Session()
        self.session.auth = (RABBITMQ_USER, RABBITMQ_PASS)
        self.session.headers.update({'Content-Type': 'application/json'})
        self.last_successful_poll = None
        
    def get_queues(self):
        """Fetch queue statistics from RabbitMQ Management API"""
        try:
            url = f"{RABBITMQ_API_BASE}/queues"
            response = self.session.get(url, timeout=5)
            response.raise_for_status()
            
            # Update monitor health
            rabbitmq_monitor_up.set(1)
            self.last_successful_poll = datetime.now()
            
            return response.json()
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to fetch queue data: {e}")
            rabbitmq_monitor_errors.labels(error_type='api_request').inc()
            rabbitmq_monitor_up.set(0)
            return []
    
    def update_metrics(self):
        """Update Prometheus metrics with current queue states"""
        try:
            all_queues = self.get_queues()
            
            # Filter to only monitored queues
            for queue_data in all_queues:
                queue_name = queue_data.get('name', '')
                vhost = queue_data.get('vhost', '/')
                
                # Only process monitored queues
                if queue_name in MONITORED_QUEUES:
                    # Update queue depth metrics
                    messages_ready = queue_data.get('messages_ready', 0)
                    messages_unacked = queue_data.get('messages_unacknowledged', 0)
                    messages_total = queue_data.get('messages', 0)
                    consumers = queue_data.get('consumers', 0)
                    
                    # Update gauges
                    rabbitmq_queue_messages_ready.labels(queue=queue_name, vhost=vhost).set(messages_ready)
                    rabbitmq_queue_messages_unacked.labels(queue=queue_name, vhost=vhost).set(messages_unacked)
                    rabbitmq_queue_messages_total.labels(queue=queue_name, vhost=vhost).set(messages_total)
                    rabbitmq_queue_consumers.labels(queue=queue_name, vhost=vhost).set(consumers)
                    
                    # Message rates (if available)
                    message_stats = queue_data.get('message_stats', {})
                    publish_details = message_stats.get('publish_details', {})
                    deliver_details = message_stats.get('deliver_details', {})
                    
                    if publish_details:
                        publish_rate = publish_details.get('rate', 0)
                        rabbitmq_queue_publish_rate.labels(queue=queue_name, vhost=vhost).set(publish_rate)
                    
                    if deliver_details:
                        deliver_rate = deliver_details.get('rate', 0)
                        rabbitmq_queue_deliver_rate.labels(queue=queue_name, vhost=vhost).set(deliver_rate)
                    
                    logger.debug(f"Updated metrics for queue {queue_name}: ready={messages_ready}, "
                               f"unacked={messages_unacked}, total={messages_total}")
            
        except Exception as e:
            logger.error(f"Error updating metrics: {e}")
            rabbitmq_monitor_errors.labels(error_type='metric_update').inc()


# Create monitor instance
monitor = RabbitMQMonitor()


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    health_status = {
        'status': 'UP' if rabbitmq_monitor_up._value.get() == 1 else 'DOWN',
        'service': 'rabbitmq-queue-monitor',
        'timestamp': datetime.utcnow().isoformat(),
        'last_successful_poll': monitor.last_successful_poll.isoformat() if monitor.last_successful_poll else None,
        'monitored_queues': MONITORED_QUEUES
    }
    
    status_code = 200 if health_status['status'] == 'UP' else 503
    return health_status, status_code


@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(REGISTRY), mimetype='text/plain; version=0.0.4; charset=utf-8')


def scheduled_poll():
    """Function called by scheduler to poll RabbitMQ"""
    logger.info("Polling RabbitMQ for queue metrics...")
    monitor.update_metrics()


if __name__ == '__main__':
    # Initial check
    logger.info(f"Starting RabbitMQ Queue Monitor...")
    logger.info(f"Monitoring queues: {', '.join(MONITORED_QUEUES)}")
    logger.info(f"RabbitMQ Management API: {RABBITMQ_API_BASE}")
    
    # Set up scheduler for periodic polling
    scheduler = BackgroundScheduler()
    scheduler.add_job(
        func=scheduled_poll,
        trigger="interval",
        seconds=POLL_INTERVAL,
        id='rabbitmq_poll',
        replace_existing=True
    )
    scheduler.start()
    
    # Do initial poll
    scheduled_poll()
    
    # Start Flask app
    logger.info(f"Starting metrics server on port 9418...")
    app.run(host='0.0.0.0', port=9418, debug=False)