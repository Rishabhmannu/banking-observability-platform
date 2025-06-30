"""
Container Resource Monitor Configuration
Manages settings for container resource optimization monitoring
"""
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class Config:
    """Configuration settings for Container Resource Monitor"""
    
    # Service Settings
    SERVICE_NAME = "container-resource-monitor"
    SERVICE_PORT = int(os.getenv('SERVICE_PORT', '5010'))
    
    # cAdvisor Connection
    # cAdvisor is running on port 8086 in your setup
    CADVISOR_URL = os.getenv('CADVISOR_URL', 'http://cadvisor:8086')
    
    # Monitoring Settings
    SCRAPE_INTERVAL_SECONDS = int(os.getenv('SCRAPE_INTERVAL', '30'))
    HISTORY_WINDOW_MINUTES = int(os.getenv('HISTORY_WINDOW', '60'))
    
    # Resource Optimization Thresholds
    CPU_UTILIZATION_LOW = float(os.getenv('CPU_LOW', '0.1'))      # 10%
    CPU_UTILIZATION_HIGH = float(os.getenv('CPU_HIGH', '0.8'))    # 80%
    MEMORY_UTILIZATION_LOW = float(os.getenv('MEM_LOW', '0.2'))   # 20%
    MEMORY_UTILIZATION_HIGH = float(os.getenv('MEM_HIGH', '0.85')) # 85%
    
    # Optimization Recommendations
    CPU_RECOMMENDATION_BUFFER = float(os.getenv('CPU_BUFFER', '1.2'))    # 20% buffer
    MEMORY_RECOMMENDATION_BUFFER = float(os.getenv('MEM_BUFFER', '1.25')) # 25% buffer
    
    # Container Stability Scoring
    RESTART_PENALTY_WEIGHT = float(os.getenv('RESTART_WEIGHT', '10.0'))
    OOM_KILL_PENALTY_WEIGHT = float(os.getenv('OOM_WEIGHT', '20.0'))
    
    # Cost Calculation (hypothetical cloud pricing)
    CPU_COST_PER_CORE_HOUR = float(os.getenv('CPU_COST', '0.05'))    # $0.05 per core/hour
    MEMORY_COST_PER_GB_HOUR = float(os.getenv('MEM_COST', '0.01'))   # $0.01 per GB/hour
    
    # Banking Service Priority Weights
    SERVICE_PRIORITIES = {
        'banking-api-gateway': 1.0,
        'banking-transaction-service': 0.9,
        'banking-account-service': 0.9,
        'banking-auth-service': 0.8,
        'banking-fraud-detection': 0.8,
        'banking-notification-service': 0.6,
        'ddos-ml-detection': 0.7,
        'auto-baselining': 0.5
    }
    
    # Metrics Settings
    METRICS_PREFIX = "container_"
    
    # Logging
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    
    @classmethod
    def get_service_priority(cls, container_name):
        """Get priority weight for a service"""
        for service, priority in cls.SERVICE_PRIORITIES.items():
            if service in container_name:
                return priority
        return 0.5  # Default priority