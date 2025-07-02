"""
Container Resource Monitor Service - Docker API Version
Monitors container resource usage using Docker API directly
"""
import time
import logging
import json
import docker
from datetime import datetime
from collections import defaultdict
from flask import Flask, jsonify
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

# Prometheus metrics - Simplified for usage only
container_cpu_usage_cores = Gauge(
    f'{Config.METRICS_PREFIX}cpu_usage_cores',
    'Current CPU usage in cores',
    ['container_name']
)

container_memory_usage_mb = Gauge(
    f'{Config.METRICS_PREFIX}memory_usage_mb',
    'Current memory usage in MB',
    ['container_name']
)

container_cpu_percent = Gauge(
    f'{Config.METRICS_PREFIX}cpu_usage_percent',
    'CPU usage percentage',
    ['container_name']
)

container_memory_percent = Gauge(
    f'{Config.METRICS_PREFIX}memory_usage_percent',
    'Memory usage percentage of container',
    ['container_name']
)

container_network_rx_mb = Gauge(
    f'{Config.METRICS_PREFIX}network_rx_mb',
    'Network received in MB',
    ['container_name']
)

container_network_tx_mb = Gauge(
    f'{Config.METRICS_PREFIX}network_tx_mb',
    'Network transmitted in MB',
    ['container_name']
)

containers_monitored_total = Gauge(
    f'{Config.METRICS_PREFIX}monitored_total',
    'Total number of containers being monitored'
)

analysis_duration = Histogram(
    f'{Config.METRICS_PREFIX}analysis_duration_seconds',
    'Time taken to analyze containers'
)

analysis_errors = Counter(
    f'{Config.METRICS_PREFIX}analysis_errors_total',
    'Total number of analysis errors'
)


class ContainerResourceMonitor:
    """Monitors container resource usage using Docker API"""

    def __init__(self):
        self.scheduler = BackgroundScheduler()
        self.is_running = False
        self.container_stats = defaultdict(list)

        # Initialize Docker client
        try:
            self.docker_client = docker.from_env()
            logger.info("✅ Docker client initialized successfully")
        except Exception as e:
            logger.error(f"❌ Failed to initialize Docker client: {e}")
            raise

    def fetch_container_metrics(self):
        """Fetch metrics directly from Docker API"""
        try:
            logger.info("Fetching containers from Docker API...")

            # Get all running containers
            all_containers = self.docker_client.containers.list()
            containers = []

            for container in all_containers:
                try:
                    # Get container name (try different sources)
                    container_name = self._extract_container_name(container)

                    if container_name and Config.should_monitor_container(container_name):
                        # Get container stats
                        stats = container.stats(stream=False)

                        containers.append({
                            'name': container_name,
                            'id': container.id,
                            'stats': stats,
                            'container': container
                        })
                        logger.debug(f"Monitoring container: {container_name}")

                except Exception as e:
                    logger.error(
                        f"Error processing container {container.name}: {e}")
                    continue

            logger.info(f"Found {len(containers)} containers to monitor")
            return containers

        except Exception as e:
            logger.error(f"Error fetching container metrics: {e}")
            return []

    def _extract_container_name(self, container):
        """Extract container name from Docker container object"""
        try:
            # Method 1: From Docker Compose labels
            labels = container.labels or {}
            compose_service = labels.get('com.docker.compose.service', '')
            if compose_service:
                return compose_service

            # Method 2: From container name (remove leading slash)
            name = container.name
            if name.startswith('/'):
                name = name[1:]

            return name

        except Exception as e:
            logger.error(f"Error extracting container name: {e}")
            return None

    def update_metrics(self, containers):
        """Update Prometheus metrics with container data"""
        try:
            monitored_count = 0

            for container_data in containers:
                name = container_data['name']
                stats = container_data['stats']
                container = container_data['container']

                # CPU metrics
                cpu_usage = self._calculate_cpu_usage(stats)
                container_cpu_usage_cores.labels(
                    container_name=name).set(cpu_usage)

                # CPU percentage (calculate based on system CPU count)
                cpu_percent = self._calculate_cpu_percentage(stats)
                container_cpu_percent.labels(
                    container_name=name).set(cpu_percent)

                # Memory metrics
                memory_usage = stats.get('memory_stats', {}).get('usage', 0)
                memory_mb = memory_usage / (1024 * 1024)
                container_memory_usage_mb.labels(
                    container_name=name).set(memory_mb)

                # Memory percentage
                memory_limit = stats.get('memory_stats', {}).get('limit', 0)
                if memory_limit > 0:
                    memory_percent = (memory_usage / memory_limit) * 100
                    container_memory_percent.labels(
                        container_name=name).set(memory_percent)

                # Network metrics
                networks = stats.get('networks', {})
                total_rx = sum(net.get('rx_bytes', 0)
                               for net in networks.values()) / (1024 * 1024)
                total_tx = sum(net.get('tx_bytes', 0)
                               for net in networks.values()) / (1024 * 1024)

                container_network_rx_mb.labels(
                    container_name=name).set(total_rx)
                container_network_tx_mb.labels(
                    container_name=name).set(total_tx)

                monitored_count += 1

            containers_monitored_total.set(monitored_count)
            logger.info(f"Updated metrics for {monitored_count} containers")

        except Exception as e:
            logger.error(f"Error updating metrics: {e}")
            analysis_errors.inc()

    def _calculate_cpu_usage(self, stats):
        """Calculate CPU usage in cores from Docker stats"""
        try:
            cpu_stats = stats.get('cpu_stats', {})
            precpu_stats = stats.get('precpu_stats', {})

            # Get CPU usage
            cpu_usage = cpu_stats.get('cpu_usage', {})
            precpu_usage = precpu_stats.get('cpu_usage', {})

            total_usage = cpu_usage.get('total_usage', 0)
            prev_total_usage = precpu_usage.get('total_usage', 0)

            # Get system CPU usage
            system_usage = cpu_stats.get('system_cpu_usage', 0)
            prev_system_usage = precpu_stats.get('system_cpu_usage', 0)

            # Calculate CPU usage percentage
            cpu_delta = total_usage - prev_total_usage
            system_delta = system_usage - prev_system_usage

            if system_delta > 0:
                # Get number of online CPUs
                online_cpus = cpu_stats.get('online_cpus', 1)
                cpu_usage_percent = (
                    cpu_delta / system_delta) * online_cpus * 100
                # Convert percentage to cores (e.g., 50% of 4 cores = 2 cores)
                return (cpu_usage_percent / 100) * online_cpus

            return 0

        except Exception as e:
            logger.error(f"Error calculating CPU usage: {e}")
            return 0

    def _calculate_cpu_percentage(self, stats):
        """Calculate CPU usage percentage"""
        try:
            cpu_stats = stats.get('cpu_stats', {})
            precpu_stats = stats.get('precpu_stats', {})

            cpu_usage = cpu_stats.get('cpu_usage', {})
            precpu_usage = precpu_stats.get('cpu_usage', {})

            total_usage = cpu_usage.get('total_usage', 0)
            prev_total_usage = precpu_usage.get('total_usage', 0)

            system_usage = cpu_stats.get('system_cpu_usage', 0)
            prev_system_usage = precpu_stats.get('system_cpu_usage', 0)

            cpu_delta = total_usage - prev_total_usage
            system_delta = system_usage - prev_system_usage

            if system_delta > 0:
                online_cpus = cpu_stats.get('online_cpus', 1)
                return (cpu_delta / system_delta) * online_cpus * 100

            return 0

        except Exception as e:
            logger.error(f"Error calculating CPU percentage: {e}")
            return 0

    def analyze_containers(self):
        """Main analysis loop"""
        start_time = time.time()

        try:
            # Fetch container metrics
            containers = self.fetch_container_metrics()

            if containers:
                # Update Prometheus metrics
                self.update_metrics(containers)
            else:
                logger.warning("No containers found to monitor")

            # Record analysis duration
            duration = time.time() - start_time
            analysis_duration.observe(duration)

        except Exception as e:
            logger.error(f"Error during container analysis: {e}")
            analysis_errors.inc()

    def start(self):
        """Start the monitor"""
        self.is_running = True

        # Schedule periodic analysis
        self.scheduler.add_job(
            func=self.analyze_containers,
            trigger="interval",
            seconds=Config.SCRAPE_INTERVAL_SECONDS,
            id='container_analysis'
        )
        self.scheduler.start()

        logger.info("✅ Container Resource Monitor started (Docker API mode)")

        # Run initial analysis
        self.analyze_containers()

    def stop(self):
        """Stop the monitor"""
        self.is_running = False
        self.scheduler.shutdown()


# Initialize monitor
monitor = ContainerResourceMonitor()


@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': Config.SERVICE_NAME,
        'mode': 'docker-api',
        'is_running': monitor.is_running,
        'timestamp': datetime.now().isoformat()
    })


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


@app.route('/containers')
def get_containers():
    """Get list of monitored containers"""
    containers = monitor.fetch_container_metrics()
    return jsonify({
        'total': len(containers),
        'containers': [c['name'] for c in containers]
    })


if __name__ == '__main__':
    logger.info("🚀 Starting Container Resource Monitor (Docker API Mode)...")
    logger.info(f"📊 Metrics available at /metrics")
    logger.info(f"🏥 Health check at /health")
    logger.info(f"📦 Container list at /containers")

    # Start monitoring
    monitor.start()

    # Start Flask app
    app.run(host='0.0.0.0', port=Config.SERVICE_PORT, debug=False)
