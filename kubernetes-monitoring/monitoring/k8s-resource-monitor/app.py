import asyncio
import aiohttp
import time
import logging
from datetime import datetime, timedelta
from prometheus_client import start_http_server, Gauge, Counter, Histogram
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
k8s_pod_count = Gauge('k8s_pod_count_total', 'Total number of pods by namespace', ['namespace', 'phase'])
k8s_deployment_replicas = Gauge('k8s_deployment_replicas', 'Deployment replica counts', ['namespace', 'deployment', 'type'])
k8s_hpa_replicas = Gauge('k8s_hpa_replicas', 'HPA replica counts', ['namespace', 'hpa', 'type'])
k8s_hpa_cpu_utilization = Gauge('k8s_hpa_cpu_utilization_percent', 'HPA CPU utilization percentage', ['namespace', 'hpa'])
k8s_hpa_memory_utilization = Gauge('k8s_hpa_memory_utilization_percent', 'HPA memory utilization percentage', ['namespace', 'hpa'])
k8s_node_pod_capacity = Gauge('k8s_node_pod_capacity', 'Node pod capacity and usage', ['node', 'type'])
k8s_node_resource_pressure = Gauge('k8s_node_resource_pressure', 'Node resource pressure indicators', ['node', 'condition'])
k8s_scaling_events = Counter('k8s_scaling_events_total', 'Total scaling events', ['namespace', 'hpa', 'direction'])
k8s_pod_restarts = Gauge('k8s_pod_restarts_total', 'Pod restart counts', ['namespace', 'pod'])
k8s_monitor_errors = Counter('k8s_monitor_errors_total', 'K8s monitoring errors')
k8s_monitor_duration = Histogram('k8s_monitor_duration_seconds', 'K8s monitoring collection duration')

class KubernetesResourceMonitor:
    def __init__(self):
        self.kube_state_metrics_url = "http://kube-state-metrics.kube-system.svc.cluster.local:8080/metrics"
        self.metrics_server_url = "http://metrics-server.kube-system.svc.cluster.local:4443/metrics"
        self.target_namespace = "banking-k8s-test"
        self.previous_hpa_replicas = {}
        
    async def fetch_metrics(self, url):
        """Fetch metrics from a given URL"""
        try:
            timeout = aiohttp.ClientTimeout(total=10)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(url) as response:
                    if response.status == 200:
                        return await response.text()
                    else:
                        logger.error(f"Failed to fetch metrics from {url}: {response.status}")
                        return None
        except Exception as e:
            logger.error(f"Error fetching metrics from {url}: {e}")
            return None
    
    def parse_prometheus_metrics(self, metrics_text):
        """Parse Prometheus metrics text into a dictionary"""
        metrics = {}
        if not metrics_text:
            return metrics
            
        for line in metrics_text.split('\n'):
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                try:
                    metric_part, value_part = line.rsplit(' ', 1)
                    value = float(value_part)
                    
                    if '{' in metric_part:
                        metric_name = metric_part.split('{')[0]
                        labels_part = metric_part.split('{')[1].rstrip('}')
                        labels = {}
                        
                        # Parse labels
                        for label_pair in labels_part.split(','):
                            if '=' in label_pair:
                                key, val = label_pair.split('=', 1)
                                labels[key.strip()] = val.strip('"')
                        
                        if metric_name not in metrics:
                            metrics[metric_name] = []
                        metrics[metric_name].append({'labels': labels, 'value': value})
                    else:
                        metrics[metric_part] = [{'labels': {}, 'value': value}]
                        
                except Exception as e:
                    continue  # Skip malformed lines
                    
        return metrics
    
    def update_pod_metrics(self, metrics):
        """Update pod-related metrics"""
        # Pod counts by phase
        if 'kube_pod_status_phase' in metrics:
            pod_counts = {}
            for entry in metrics['kube_pod_status_phase']:
                if entry['value'] == 1:  # Active phase
                    namespace = entry['labels'].get('namespace', 'unknown')
                    phase = entry['labels'].get('phase', 'unknown')
                    
                    key = (namespace, phase)
                    pod_counts[key] = pod_counts.get(key, 0) + 1
            
            # Update Prometheus metrics
            for (namespace, phase), count in pod_counts.items():
                k8s_pod_count.labels(namespace=namespace, phase=phase).set(count)
        
        # Pod restart counts
        if 'kube_pod_container_status_restarts_total' in metrics:
            for entry in metrics['kube_pod_container_status_restarts_total']:
                namespace = entry['labels'].get('namespace', 'unknown')
                pod = entry['labels'].get('pod', 'unknown')
                
                if namespace == self.target_namespace:
                    k8s_pod_restarts.labels(namespace=namespace, pod=pod).set(entry['value'])
    
    def update_deployment_metrics(self, metrics):
        """Update deployment-related metrics"""
        if 'kube_deployment_status_replicas' in metrics:
            for entry in metrics['kube_deployment_status_replicas']:
                namespace = entry['labels'].get('namespace', 'unknown')
                deployment = entry['labels'].get('deployment', 'unknown')
                
                if namespace == self.target_namespace:
                    k8s_deployment_replicas.labels(
                        namespace=namespace, 
                        deployment=deployment, 
                        type='current'
                    ).set(entry['value'])
        
        if 'kube_deployment_spec_replicas' in metrics:
            for entry in metrics['kube_deployment_spec_replicas']:
                namespace = entry['labels'].get('namespace', 'unknown')
                deployment = entry['labels'].get('deployment', 'unknown')
                
                if namespace == self.target_namespace:
                    k8s_deployment_replicas.labels(
                        namespace=namespace, 
                        deployment=deployment, 
                        type='desired'
                    ).set(entry['value'])
    
    def update_hpa_metrics(self, metrics):
        """Update HPA-related metrics"""
        # HPA replica counts
        if 'kube_horizontalpodautoscaler_status_current_replicas' in metrics:
            for entry in metrics['kube_horizontalpodautoscaler_status_current_replicas']:
                namespace = entry['labels'].get('namespace', 'unknown')
                hpa = entry['labels'].get('horizontalpodautoscaler', 'unknown')
                
                if namespace == self.target_namespace:
                    current_replicas = entry['value']
                    k8s_hpa_replicas.labels(
                        namespace=namespace, 
                        hpa=hpa, 
                        type='current'
                    ).set(current_replicas)
                    
                    # Track scaling events
                    key = f"{namespace}/{hpa}"
                    if key in self.previous_hpa_replicas:
                        previous = self.previous_hpa_replicas[key]
                        if current_replicas > previous:
                            k8s_scaling_events.labels(
                                namespace=namespace, 
                                hpa=hpa, 
                                direction='up'
                            ).inc()
                            logger.info(f"Scaling UP detected: {hpa} {previous} -> {current_replicas}")
                        elif current_replicas < previous:
                            k8s_scaling_events.labels(
                                namespace=namespace, 
                                hpa=hpa, 
                                direction='down'
                            ).inc()
                            logger.info(f"Scaling DOWN detected: {hpa} {previous} -> {current_replicas}")
                    
                    self.previous_hpa_replicas[key] = current_replicas
        
        if 'kube_horizontalpodautoscaler_status_desired_replicas' in metrics:
            for entry in metrics['kube_horizontalpodautoscaler_status_desired_replicas']:
                namespace = entry['labels'].get('namespace', 'unknown')
                hpa = entry['labels'].get('horizontalpodautoscaler', 'unknown')
                
                if namespace == self.target_namespace:
                    k8s_hpa_replicas.labels(
                        namespace=namespace, 
                        hpa=hpa, 
                        type='desired'
                    ).set(entry['value'])
    
    def update_node_metrics(self, metrics):
        """Update node-related metrics"""
        # Node pod capacity
        if 'kube_node_status_allocatable' in metrics:
            for entry in metrics['kube_node_status_allocatable']:
                node = entry['labels'].get('node', 'unknown')
                resource = entry['labels'].get('resource', 'unknown')
                
                if resource == 'pods':
                    k8s_node_pod_capacity.labels(node=node, type='allocatable').set(entry['value'])
        
        # Node conditions (pressure indicators)
        if 'kube_node_status_condition' in metrics:
            for entry in metrics['kube_node_status_condition']:
                if entry['value'] == 1:  # Condition is true
                    node = entry['labels'].get('node', 'unknown')
                    condition = entry['labels'].get('condition', 'unknown')
                    status = entry['labels'].get('status', 'unknown')
                    
                    # Convert to pressure indicator (1 = pressure, 0 = no pressure)
                    pressure_value = 1 if (condition in ['MemoryPressure', 'DiskPressure', 'PIDPressure'] and status == 'true') else 0
                    k8s_node_resource_pressure.labels(node=node, condition=condition).set(pressure_value)
    
    async def collect_and_update_metrics(self):
        """Main metrics collection and update loop"""
        with k8s_monitor_duration.time():
            try:
                # Fetch kube-state-metrics
                metrics_text = await self.fetch_metrics(self.kube_state_metrics_url)
                if not metrics_text:
                    k8s_monitor_errors.inc()
                    return
                
                # Parse metrics
                metrics = self.parse_prometheus_metrics(metrics_text)
                
                # Update all metric categories
                self.update_pod_metrics(metrics)
                self.update_deployment_metrics(metrics)
                self.update_hpa_metrics(metrics)
                self.update_node_metrics(metrics)
                
                logger.info(f"Successfully updated Kubernetes metrics for {self.target_namespace}")
                
            except Exception as e:
                logger.error(f"Error in metrics collection: {e}")
                k8s_monitor_errors.inc()
    
    async def run(self):
        """Main monitoring loop"""
        logger.info(f"Starting Kubernetes Resource Monitor for namespace: {self.target_namespace}")
        logger.info(f"Metrics endpoint: http://localhost:9419/metrics")
        
        while True:
            await self.collect_and_update_metrics()
            await asyncio.sleep(15)  # Collect every 15 seconds

if __name__ == "__main__":
    # Start Prometheus metrics server
    start_http_server(9419)
    
    # Start monitoring
    monitor = KubernetesResourceMonitor()
    
    try:
        asyncio.run(monitor.run())
    except KeyboardInterrupt:
        logger.info("Kubernetes Resource Monitor stopped")