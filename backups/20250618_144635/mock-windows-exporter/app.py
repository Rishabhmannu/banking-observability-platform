import os
from flask import Flask, Response
from prometheus_client import Counter, Gauge, Histogram, generate_latest, REGISTRY
import time
import threading
import logging
import random
import math
from datetime import datetime

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Raw IIS Metrics - These are what Windows Exporter actually exposes
# Reference: https://github.com/prometheus-community/windows_exporter/blob/master/docs/collector.iis.md

# Request Metrics
windows_iis_requests_total = Counter(
    'windows_iis_requests_total',
    'Total requests received by IIS',
    ['method', 'site']
)

windows_iis_current_connections = Gauge(
    'windows_iis_current_connections',
    'Current number of connections',
    ['site']
)

# Error Metrics (by type)
windows_iis_not_found_errors_total = Counter(
    'windows_iis_not_found_errors_total',
    'Total 404 errors',
    ['site']
)

windows_iis_locked_errors_total = Counter(
    'windows_iis_locked_errors_total',
    'Total 423 locked errors',
    ['site']
)

windows_iis_server_errors_total = Counter(
    'windows_iis_server_errors_total',
    'Total 5xx server errors',
    ['site']
)

windows_iis_client_errors_total = Counter(
    'windows_iis_client_errors_total',
    'Total 4xx client errors',
    ['site']
)

# Performance Metrics
windows_iis_request_wait_time = Histogram(
    'windows_iis_request_wait_time',
    'Request wait time in milliseconds',
    ['site'],
    buckets=(5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000)
)

windows_iis_request_execution_time = Histogram(
    'windows_iis_request_execution_time',
    'Request execution time in milliseconds',
    ['site'],
    buckets=(5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000)
)

# Worker Process Metrics
windows_iis_worker_processes = Gauge(
    'windows_iis_worker_processes',
    'Number of worker processes',
    ['app_pool', 'state']
)

windows_iis_worker_request_total = Counter(
    'windows_iis_worker_request_total',
    'Total requests handled by worker processes',
    ['app_pool']
)

# Application Pool Metrics
windows_iis_app_pool_state = Gauge(
    'windows_iis_app_pool_state',
    'Application pool state (1=started, 0=stopped)',
    ['app_pool']
)

windows_iis_app_pool_recycles_total = Counter(
    'windows_iis_app_pool_recycles_total',
    'Total number of app pool recycles',
    ['app_pool']
)

# .NET CLR Exceptions (for technical exceptions)
windows_netframework_exceptions_thrown_total = Counter(
    'windows_netframework_exceptions_thrown_total',
    'Total .NET exceptions thrown',
    ['app_name', 'exception_type']
)

# Custom Performance Counters (for custom error codes)
windows_custom_errors_total = Counter(
    'windows_custom_errors_total',
    'Custom application error codes',
    ['error_code', 'app_name']
)

# Sites configuration
IIS_SITES = ['Default Web Site', 'BankingApp', 'API Portal']
APP_POOLS = ['DefaultAppPool', 'BankingAppPool', 'APIPool']


class IISSimulator:
    def __init__(self):
        self.base_load = 100  # requests per second
        self.time_of_day_factor = 1.0
        self.is_running = True
        self.surge_active = False
        self.degradation_active = False

    def start(self):
        """Start background threads for metric generation"""
        threading.Thread(target=self._generate_traffic, daemon=True).start()
        threading.Thread(target=self._update_gauges, daemon=True).start()
        threading.Thread(target=self._simulate_patterns, daemon=True).start()
        # Start this check thread in the start() method:
        threading.Thread(target=self.check_anomaly_triggers, daemon=True).start()


    def _calculate_time_factor(self):
        """Simulate daily traffic patterns"""
        hour = datetime.now().hour
        # Peak hours: 9-17 (business hours)
        if 9 <= hour <= 17:
            return 2.0 + math.sin((hour - 9) * math.pi / 8) * 0.5
        # Night hours: reduced traffic
        elif hour < 6 or hour > 22:
            return 0.3
        else:
            return 1.0

    def _generate_traffic(self):
        """Generate realistic IIS traffic patterns"""
        while self.is_running:
            try:
                self.time_of_day_factor = self._calculate_time_factor()

                # Calculate current request rate
                surge_multiplier = 3.0 if self.surge_active else 1.0
                current_rate = self.base_load * self.time_of_day_factor * surge_multiplier

                # Generate requests for each site
                for site in IIS_SITES:
                    site_requests = int(current_rate / len(IIS_SITES))

                    for _ in range(site_requests):
                        # HTTP method distribution
                        method = random.choices(
                            ['GET', 'POST', 'PUT', 'DELETE'],
                            weights=[70, 20, 5, 5]
                        )[0]

                        # Simulate request
                        windows_iis_requests_total.labels(
                            method=method, site=site).inc()

                        # Calculate response times (affected by degradation)
                        base_wait_time = random.gauss(10, 5)
                        base_exec_time = random.gauss(50, 20)

                        if self.degradation_active:
                            base_wait_time *= 5
                            base_exec_time *= 3

                        windows_iis_request_wait_time.labels(
                            site=site).observe(max(0, base_wait_time))
                        windows_iis_request_execution_time.labels(
                            site=site).observe(max(0, base_exec_time))

                        # Simulate errors based on realistic rates
                        error_roll = random.random()
                        if error_roll < 0.001:  # 0.1% 500 errors
                            windows_iis_server_errors_total.labels(
                                site=site).inc()
                        elif error_roll < 0.005:  # 0.4% 404 errors
                            windows_iis_not_found_errors_total.labels(
                                site=site).inc()
                        elif error_roll < 0.01:  # 0.5% other 4xx errors
                            windows_iis_client_errors_total.labels(
                                site=site).inc()

                        # Simulate .NET exceptions (technical exceptions)
                        if random.random() < 0.002:  # 0.2% exception rate
                            exception_type = random.choice([
                                'System.NullReferenceException',
                                'System.ArgumentException',
                                'System.InvalidOperationException',
                                'System.Data.SqlException'
                            ])
                            windows_netframework_exceptions_thrown_total.labels(
                                app_name=f'{site}_App',
                                exception_type=exception_type
                            ).inc()

                        # Simulate custom error codes
                        if random.random() < 0.003:  # 0.3% custom errors
                            error_code = random.choice(['ERR_VALIDATION_001', 'ERR_AUTH_002',
                                                        'ERR_BUSINESS_003', 'ERR_DATA_004'])
                            windows_custom_errors_total.labels(
                                error_code=error_code,
                                app_name=f'{site}_App'
                            ).inc()

                # Sleep to control rate
                time.sleep(1.0)

            except Exception as e:
                logger.error(f"Error generating traffic: {e}")
                time.sleep(5)

    def _update_gauges(self):
        """Update gauge metrics"""
        while self.is_running:
            try:
                # Update current connections (based on current load)
                for site in IIS_SITES:
                    connections = int(
                        self.base_load * self.time_of_day_factor *
                        random.uniform(0.8, 1.2) / 10
                    )
                    windows_iis_current_connections.labels(
                        site=site).set(connections)

                # Update worker processes
                for pool in APP_POOLS:
                    # Simulate worker process states
                    running = int(2 + random.randint(0, 2))
                    idle = int(random.randint(0, 2))

                    windows_iis_worker_processes.labels(
                        app_pool=pool, state='running').set(running)
                    windows_iis_worker_processes.labels(
                        app_pool=pool, state='idle').set(idle)

                    # App pool state (mostly running)
                    state = 1 if random.random() > 0.01 else 0
                    windows_iis_app_pool_state.labels(app_pool=pool).set(state)

                    # Occasional recycles
                    if random.random() < 0.001:
                        windows_iis_app_pool_recycles_total.labels(
                            app_pool=pool).inc()

                time.sleep(5)

            except Exception as e:
                logger.error(f"Error updating gauges: {e}")
                time.sleep(10)

    def _simulate_patterns(self):
        """Simulate various patterns like surges and degradations"""
        while self.is_running:
            try:
                # Random surge (5% chance every minute)
                if random.random() < 0.05:
                    logger.info("Simulating traffic surge")
                    self.surge_active = True
                    time.sleep(random.randint(30, 120))  # Surge lasts 30s-2min
                    self.surge_active = False

                # Random degradation (3% chance every minute)
                if random.random() < 0.03:
                    logger.info("Simulating response time degradation")
                    self.degradation_active = True
                    # Degradation lasts 1-3min
                    time.sleep(random.randint(60, 180))
                    self.degradation_active = False

                time.sleep(60)

            except Exception as e:
                logger.error(f"Error in pattern simulation: {e}")
                time.sleep(60)

    # Add these methods to the IISSimulator class:


    def check_anomaly_triggers(self):
        """Check for external anomaly triggers"""
        while self.is_running:
            try:
                # Check for volume surge trigger
                if os.path.exists('/tmp/anomaly_trigger'):
                    with open('/tmp/anomaly_trigger', 'r') as f:
                        trigger = f.read().strip()

                    if trigger == 'volume_surge':
                        self.surge_active = True
                    elif trigger == 'normal':
                        self.surge_active = False
                        self.degradation_active = False

                # Check for degradation trigger
                if os.path.exists('/tmp/degradation_active'):
                    with open('/tmp/degradation_active', 'r') as f:
                        self.degradation_active = f.read().strip() == 'true'

                # Check for exceptions burst
                if os.path.exists('/tmp/exceptions_burst'):
                    with open('/tmp/exceptions_burst', 'r') as f:
                        if f.read().strip() == 'true':
                            # Generate more exceptions
                            for _ in range(10):
                                exception_type = random.choice([
                                    'System.NullReferenceException',
                                    'System.OutOfMemoryException',
                                    'System.StackOverflowException'
                                ])
                                windows_netframework_exceptions_thrown_total.labels(
                                    app_name='BankingApp',
                                    exception_type=exception_type
                                ).inc()

                # Check for custom errors burst
                if os.path.exists('/tmp/custom_errors_burst'):
                    with open('/tmp/custom_errors_burst', 'r') as f:
                        if f.read().strip() == 'true':
                            # Generate more custom errors
                            for _ in range(5):
                                error_code = random.choice([
                                    'ERR_TIMEOUT_005', 'ERR_DEADLOCK_006',
                                    'ERR_OVERFLOW_007', 'ERR_SECURITY_008'
                                ])
                                windows_custom_errors_total.labels(
                                    error_code=error_code,
                                    app_name='BankingApp'
                                ).inc()

                # Check for app pool failure
                if os.path.exists('/tmp/apppool_failure'):
                    with open('/tmp/apppool_failure', 'r') as f:
                        failed_pool = f.read().strip()
                        if failed_pool != 'none':
                            windows_iis_app_pool_state.labels(
                                app_pool=failed_pool).set(0)
                        else:
                            # Restore all pools
                            for pool in APP_POOLS:
                                windows_iis_app_pool_state.labels(
                                    app_pool=pool).set(1)

                time.sleep(1)

            except Exception as e:
                logger.error(f"Error checking triggers: {e}")
                time.sleep(5)




# Initialize simulator
simulator = IISSimulator()


@app.route('/health')
def health():
    return {'status': 'healthy', 'service': 'mock-windows-exporter'}


@app.route('/metrics')
def metrics():
    """Expose metrics in Prometheus format"""
    return Response(generate_latest(REGISTRY), mimetype='text/plain; version=0.0.4; charset=utf-8')


if __name__ == '__main__':
    logger.info("Starting Mock Windows Exporter on port 9182")
    simulator.start()
    app.run(host='0.0.0.0', port=9182, debug=False)
