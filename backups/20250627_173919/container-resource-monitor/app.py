"""
Container Resource Monitor Service
Monitors container resource usage and provides optimization recommendations
"""
import time
import logging
import json
import requests
from datetime import datetime, timedelta
from collections import defaultdict
from flask import Flask, jsonify
from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST
from apscheduler.schedulers.background import BackgroundScheduler
from config import Config
from optimizer import ResourceOptimizer, VPARecommender, MLBasedOptimizer, RightSizingAnalyzer

# Configure logging
logging.basicConfig(
    level=getattr(logging, Config.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Prometheus metrics
container_cpu_optimization_score = Gauge(
    f'{Config.METRICS_PREFIX}cpu_optimization_score',
    'CPU optimization score (0-100, higher means more optimization potential)',
    ['container_name']
)

container_memory_waste_percent = Gauge(
    f'{Config.METRICS_PREFIX}memory_waste_percent',
    'Percentage of wasted memory',
    ['container_name']
)

container_recommended_cpu_cores = Gauge(
    f'{Config.METRICS_PREFIX}recommended_cpu_cores',
    'Recommended CPU cores',
    ['container_name']
)

container_recommended_memory_mb = Gauge(
    f'{Config.METRICS_PREFIX}recommended_memory_mb',
    'Recommended memory in MB',
    ['container_name']
)

container_stability_score = Gauge(
    f'{Config.METRICS_PREFIX}stability_score',
    'Container stability score (0-100)',
    ['container_name']
)

container_cost_savings_potential = Gauge(
    f'{Config.METRICS_PREFIX}cost_savings_potential_dollars',
    'Potential monthly cost savings in USD',
    ['container_name']
)

total_optimization_potential = Gauge(
    f'{Config.METRICS_PREFIX}total_optimization_potential_dollars',
    'Total potential monthly savings across all containers'
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
    """Monitors and analyzes container resource usage"""
    
    def __init__(self):
        self.cadvisor_url = Config.CADVISOR_URL
        self.optimizer = ResourceOptimizer(Config)
        self.scheduler = BackgroundScheduler()
        self.metrics_history = defaultdict(list)
        self.recommendations = {}
        self.is_running = False
        
    def fetch_container_metrics(self):
        """Fetch current metrics from cAdvisor"""
        try:
            # Log the URL we're trying to connect to
            logger.info(f"Attempting to connect to cAdvisor at: {self.cadvisor_url}")
            
            # Get all containers
            response = requests.get(f"{self.cadvisor_url}/api/v1.3/containers/docker", 
                                  timeout=10)
            response.raise_for_status()
            data = response.json()
            
            containers = []
            for subcontainer in data.get('subcontainers', []):
                # Get detailed stats for each container
                container_response = requests.get(
                    f"{self.cadvisor_url}/api/v1.3/containers{subcontainer['name']}",
                    timeout=10
                )
                if container_response.status_code == 200:
                    container_data = container_response.json()
                    containers.append(container_data)
            
            return containers
            
        except Exception as e:
            logger.error(f"Error fetching metrics from cAdvisor: {e}")
            analysis_errors.inc()
            return []
    
    def process_container_metrics(self, container_data):
        """Process raw container metrics"""
        try:
            # Extract container name
            container_name = container_data.get('name', '').split('/')[-1]
            if not container_name or container_name == 'docker':
                return None
            
            # Get latest stats
            stats = container_data.get('stats', [])
            if not stats:
                return None
            
            latest_stat = stats[-1]
            
            # Extract metrics
            metrics = {
                'timestamp': datetime.now(),
                'container_name': container_name,
                'cpu_usage_cores': self._calculate_cpu_cores(latest_stat),
                'memory_usage_bytes': latest_stat.get('memory', {}).get('usage', 0),
                'memory_limit_bytes': container_data.get('spec', {}).get('memory', {}).get('limit', 0),
                'cpu_limit_cores': self._get_cpu_limit(container_data),
                'restart_count': container_data.get('spec', {}).get('labels', {}).get('restartCount', 0),
                'cpu_throttled_periods': latest_stat.get('cpu', {}).get('cfs', {}).get('throttled_periods', 0),
            }
            
            # Store in history
            self.metrics_history[container_name].append(metrics)
            
            # Keep only recent history (1 hour)
            cutoff_time = datetime.now() - timedelta(hours=1)
            self.metrics_history[container_name] = [
                m for m in self.metrics_history[container_name]
                if m['timestamp'] > cutoff_time
            ]
            
            return metrics
            
        except Exception as e:
            logger.error(f"Error processing container metrics: {e}")
            return None
    
    def _calculate_cpu_cores(self, stat):
        """Calculate CPU usage in cores"""
        cpu_usage = stat.get('cpu', {}).get('usage', {})
        total_usage = cpu_usage.get('total', 0)
        
        # Convert from nanoseconds to cores
        # Assuming 1 second interval between measurements
        cores = total_usage / 1e9
        
        return cores
    
    def _get_cpu_limit(self, container_data):
        """Get CPU limit in cores"""
        cpu_spec = container_data.get('spec', {}).get('cpu', {})
        quota = cpu_spec.get('quota', 0)
        period = cpu_spec.get('period', 100000)
        
        if quota > 0 and period > 0:
            return quota / period
        
        return None
    
    def analyze_all_containers(self):
        """Analyze all containers and generate recommendations"""
        start_time = time.time()
        
        try:
            # Fetch current metrics
            containers = self.fetch_container_metrics()
            
            total_savings = 0
            all_recommendations = []
            
            for container_data in containers:
                # Process metrics
                metrics = self.process_container_metrics(container_data)
                if not metrics:
                    continue
                
                container_name = metrics['container_name']
                
                # Skip non-banking containers
                if not any(svc in container_name for svc in Config.SERVICE_PRIORITIES.keys()):
                    continue
                
                # Generate recommendation
                history = self.metrics_history.get(container_name, [])
                if len(history) >= 10:  # Need minimum data points
                    recommendation = self.optimizer.analyze_container_resources(
                        container_name, history
                    )
                    
                    if recommendation:
                        # Update metrics
                        container_cpu_optimization_score.labels(
                            container_name=container_name
                        ).set(recommendation['cpu']['waste_percent'])
                        
                        container_memory_waste_percent.labels(
                            container_name=container_name
                        ).set(recommendation['memory']['waste_percent'])
                        
                        container_recommended_cpu_cores.labels(
                            container_name=container_name
                        ).set(recommendation['cpu']['recommended_limit'])
                        
                        container_recommended_memory_mb.labels(
                            container_name=container_name
                        ).set(recommendation['memory']['recommended_limit_mb'])
                        
                        container_stability_score.labels(
                            container_name=container_name
                        ).set(recommendation['stability_score'])
                        
                        container_cost_savings_potential.labels(
                            container_name=container_name
                        ).set(recommendation['estimated_monthly_savings_usd'])
                        
                        # Store recommendation
                        self.recommendations[container_name] = recommendation
                        all_recommendations.append(recommendation)
                        
                        total_savings += recommendation['estimated_monthly_savings_usd']
            
            # Update total savings metric
            total_optimization_potential.set(total_savings)
            
            # Prioritize recommendations
            if all_recommendations:
                prioritized = RightSizingAnalyzer.prioritize_optimizations(
                    all_recommendations,
                    Config.SERVICE_PRIORITIES
                )
                self.recommendations['_prioritized'] = prioritized
            
            # Record analysis duration
            duration = time.time() - start_time
            analysis_duration.observe(duration)
            
            logger.info(f"Analyzed {len(all_recommendations)} containers in {duration:.2f}s")
            logger.info(f"Total potential savings: ${total_savings:.2f}/month")
            
        except Exception as e:
            logger.error(f"Error during container analysis: {e}")
            analysis_errors.inc()
    
    def start(self):
        """Start the monitor"""
        self.is_running = True
        
        # Schedule periodic analysis
        self.scheduler.add_job(
            func=self.analyze_all_containers,
            trigger="interval",
            seconds=Config.SCRAPE_INTERVAL_SECONDS,
            id='container_analysis'
        )
        self.scheduler.start()
        
        logger.info("✅ Container Resource Monitor started")
        
        # Run initial analysis
        self.analyze_all_containers()
    
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
        'is_running': monitor.is_running,
        'containers_tracked': len(monitor.metrics_history),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/recommendations')
def get_recommendations():
    """Get all optimization recommendations"""
    return jsonify({
        'recommendations': monitor.recommendations,
        'total_potential_savings': total_optimization_potential._value.get() or 0,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/recommendations/<container_name>')
def get_container_recommendation(container_name):
    """Get recommendation for specific container"""
    if container_name in monitor.recommendations:
        return jsonify(monitor.recommendations[container_name])
    else:
        return jsonify({'error': 'No recommendation available for this container'}), 404

@app.route('/top-optimizations')
def get_top_optimizations():
    """Get top optimization opportunities"""
    prioritized = monitor.recommendations.get('_prioritized', [])
    
    # Get top 10
    top_10 = prioritized[:10]
    
    return jsonify({
        'top_optimizations': [
            {
                'container': item['recommendation']['container_name'],
                'category': RightSizingAnalyzer.categorize_container(item['recommendation']),
                'potential_savings': item['recommendation']['estimated_monthly_savings_usd'],
                'optimization_score': item['optimization_score'],
                'cpu_waste': item['recommendation']['cpu']['waste_percent'],
                'memory_waste': item['recommendation']['memory']['waste_percent']
            }
            for item in top_10
        ],
        'total_containers_analyzed': len(monitor.recommendations) - 1,  # Exclude _prioritized
        'timestamp': datetime.now().isoformat()
    })

@app.route('/predictions/<container_name>')
def get_predictions(container_name):
    """Get ML-based predictions for a container"""
    if container_name not in monitor.metrics_history:
        return jsonify({'error': 'No data available for this container'}), 404
    
    history = monitor.metrics_history[container_name]
    
    # Get VPA-style recommendation
    vpa_rec = VPARecommender.calculate_recommendation(history)
    
    # Get ML prediction
    ml_pred = MLBasedOptimizer.predict_future_usage(history)
    
    return jsonify({
        'container_name': container_name,
        'vpa_recommendation': vpa_rec,
        'ml_prediction': ml_pred,
        'data_points': len(history),
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    # Start the monitor
    monitor.start()
    
    # Run Flask app
    logger.info(f"Starting {Config.SERVICE_NAME} on port {Config.SERVICE_PORT}")
    app.run(host='0.0.0.0', port=Config.SERVICE_PORT, debug=False)