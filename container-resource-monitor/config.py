"""
Container Resource Monitor Configuration
Updated to work without resource limits
"""
import os

class Config:
    """Configuration for Container Resource Monitor"""
    
    # Service Settings
    SERVICE_NAME = "container-resource-monitor"
    SERVICE_PORT = int(os.getenv('SERVICE_PORT', '5010'))
    
    # Metrics prefix for Prometheus
    METRICS_PREFIX = "container_"
    
    # cAdvisor Connection - Updated to use host gateway
    CADVISOR_URL = os.getenv('CADVISOR_URL', 'http://host.docker.internal:8086')
    
    # Analysis Settings
    ANALYSIS_INTERVAL_SECONDS = int(os.getenv('ANALYSIS_INTERVAL', '30'))
    SCRAPE_INTERVAL_SECONDS = int(os.getenv('SCRAPE_INTERVAL', '30'))
    MIN_DATA_POINTS = int(os.getenv('MIN_DATA_POINTS', '1'))  # Reduced from 3
    
    # Service Priorities (still useful for sorting)
    SERVICE_PRIORITIES = {
        'api-gateway': 1.0,
        'account-service': 0.9,
        'transaction-service': 0.95,
        'auth-service': 0.85,
        'fraud-detection': 0.9,
        'notification-service': 0.7,
        'cache-proxy': 0.8,
        'ddos-ml-detection': 0.8,
        'auto-baselining': 0.75,
        'load-generator': 0.3,
        'redis': 0.8,
        'mysql': 0.9,
        'prometheus': 0.85,
        'grafana': 0.7
    }
    
    # Container Filters - More inclusive
    CONTAINER_FILTERS = [
        'account-service',
        'transaction-service',
        'auth-service',
        'fraud-detection',
        'notification-service',
        'api-gateway',
        'ddos-ml-detection',
        'auto-baselining',
        'cache-proxy-service',
        'cache-analyzer',
        'cache-load-generator',
        'container-monitor',
        'resource-anomaly',
        'redis',
        'mysql',
        'prometheus',
        'grafana',
        'load-generator',
        'transaction-monitor'
    ]
    
    # Logging
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    
    @classmethod
    def should_monitor_container(cls, container_name):
        """Check if container should be monitored"""
        # Convert to lowercase for comparison
        name_lower = container_name.lower()
        
        # Check against filter patterns
        for filter_pattern in cls.CONTAINER_FILTERS:
            if filter_pattern.lower() in name_lower:
                return True
        
        # Also check if it starts with 'banking-'
        if name_lower.startswith('banking-'):
            return True
            
        return False