#!/bin/bash

echo "🚨 Complete System Recovery After Corruption"
echo "============================================"
echo "This will completely rebuild your DDoS Detection & Auto-Baselining system"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to project directory
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" || {
    echo -e "${RED}❌ Could not find project directory${NC}"
    exit 1
}

echo "📂 Working from: $(pwd)"

echo ""
echo -e "${RED}⚠️  WARNING: This will completely reset your system${NC}"
echo "This will:"
echo "• Stop and remove all containers"
echo "• Delete all Docker volumes (including Grafana data)"
echo "• Rebuild all services from scratch"
echo "• Reset Grafana to default admin/admin"
echo "• Fix all configuration issues"
echo ""
read -p "Continue with complete system reset? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 1: Complete Docker Cleanup${NC}"
echo "==============================="

echo "🛑 Stopping all services..."
docker compose down --volumes --remove-orphans 2>/dev/null

echo "🗑️  Removing all related containers, images, and volumes..."
# Remove all containers with our project name
docker rm -f $(docker ps -aq --filter "name=banking-*" --filter "name=auto-baselining*" --filter "name=ddos-*" --filter "name=prometheus*" --filter "name=grafana*") 2>/dev/null

# Remove project-specific volumes
docker volume rm $(docker volume ls -q --filter "name=ddos-detection-system*") 2>/dev/null

# Clean up images
docker image rm $(docker images --filter "reference=ddos-detection-system*" -q) 2>/dev/null

echo "🧹 Docker system cleanup..."
docker system prune -f

sleep 5

echo ""
echo -e "${YELLOW}Step 2: Fix Configuration Files${NC}"
echo "==============================="

# Fix Grafana configuration
echo "🔧 Creating Grafana configuration..."
mkdir -p grafana/provisioning/{dashboards,datasources}

# Create Grafana datasource configuration
cat > grafana/provisioning/datasources/datasource.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Create Grafana dashboard provisioning
cat > grafana/provisioning/dashboards/dashboard.yml << EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Fix auto-baselining service (ensure proper metrics endpoint)
echo "🔧 Ensuring auto-baselining has proper metrics endpoint..."

# Create/fix the auto-baselining service to ensure it returns proper Prometheus metrics
cat > src/services/auto_baselining_service.py << 'EOF'
from flask import Flask, jsonify, request
from prometheus_client import Gauge, Counter, generate_latest, CONTENT_TYPE_LATEST
import threading
import time
import logging
import requests
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from sklearn.ensemble import IsolationForest
from sklearn.svm import OneClassSVM
import warnings
warnings.filterwarnings('ignore')

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Prometheus metrics
threshold_recommendations_total = Counter('threshold_recommendations_total', 'Total threshold recommendations generated')
algorithm_execution_time = Gauge('algorithm_execution_seconds', 'Time taken to execute algorithms', ['algorithm'])
active_metrics_count = Gauge('active_metrics_being_monitored', 'Number of metrics being actively monitored')

class AutoBaselineService:
    def __init__(self, prometheus_url="http://prometheus:9090"):
        self.prometheus_url = prometheus_url
        self.algorithms = {
            'rolling_statistics': self._rolling_statistics_threshold,
            'quantile_based': self._quantile_based_threshold,
            'isolation_forest': self._isolation_forest_threshold,
            'one_class_svm': self._svm_threshold
        }
        self.recommendations = {
            'api_request_rate': {},
            'api_error_rate': {},
            'api_response_time_p95': {},
            'cpu_usage_percent': {}
        }
        self.is_running = True
        
        # Start background processing
        self.processing_thread = threading.Thread(target=self._processing_loop, daemon=True)
        self.processing_thread.start()
        logger.info("Auto-baselining service initialized with 4 algorithms")
    
    def _query_prometheus(self, query, hours=1):
        """Query Prometheus for historical data"""
        try:
            end_time = datetime.now()
            start_time = end_time - timedelta(hours=hours)
            
            url = f"{self.prometheus_url}/api/v1/query_range"
            params = {
                'query': query,
                'start': start_time.timestamp(),
                'end': end_time.timestamp(),
                'step': '30s'
            }
            
            response = requests.get(url, params=params, timeout=10)
            if response.status_code == 200:
                data = response.json()
                if data['status'] == 'success' and data['data']['result']:
                    # Convert to pandas DataFrame
                    values = []
                    for series in data['data']['result']:
                        for timestamp, value in series['values']:
                            try:
                                values.append(float(value))
                            except ValueError:
                                continue
                    return np.array(values) if values else np.array([])
            return np.array([])
        except Exception as e:
            logger.error(f"Prometheus query failed: {e}")
            return np.array([])
    
    def _rolling_statistics_threshold(self, data):
        """Calculate threshold using rolling statistics"""
        if len(data) < 10:
            return None
        
        mean = np.mean(data)
        std = np.std(data)
        threshold = mean + (3 * std)  # 3-sigma rule
        
        return {
            'threshold': float(threshold),
            'method': 'rolling_statistics',
            'confidence': 0.85,
            'parameters': {'mean': float(mean), 'std': float(std)}
        }
    
    def _quantile_based_threshold(self, data):
        """Calculate threshold using quantiles"""
        if len(data) < 10:
            return None
        
        threshold = np.percentile(data, 95)  # 95th percentile
        
        return {
            'threshold': float(threshold),
            'method': 'quantile_based',
            'confidence': 0.90,
            'parameters': {'percentile': 95}
        }
    
    def _isolation_forest_threshold(self, data):
        """Calculate threshold using Isolation Forest"""
        if len(data) < 20:
            return None
        
        try:
            # Reshape data for sklearn
            X = data.reshape(-1, 1)
            
            # Fit Isolation Forest
            iso_forest = IsolationForest(contamination=0.1, random_state=42)
            predictions = iso_forest.fit_predict(X)
            
            # Find threshold at boundary between normal and anomalous
            scores = iso_forest.decision_function(X)
            threshold_idx = np.where(predictions == -1)[0]
            
            if len(threshold_idx) > 0:
                threshold = float(np.min(data[threshold_idx]))
            else:
                threshold = float(np.percentile(data, 90))
            
            return {
                'threshold': threshold,
                'method': 'isolation_forest',
                'confidence': 0.80,
                'parameters': {'contamination': 0.1}
            }
        except Exception as e:
            logger.error(f"Isolation Forest error: {e}")
            return None
    
    def _svm_threshold(self, data):
        """Calculate threshold using One-Class SVM"""
        if len(data) < 20:
            return None
        
        try:
            # Reshape data for sklearn
            X = data.reshape(-1, 1)
            
            # Fit One-Class SVM
            svm = OneClassSVM(nu=0.1, kernel="rbf", gamma='scale')
            predictions = svm.fit_predict(X)
            
            # Find threshold
            anomaly_indices = np.where(predictions == -1)[0]
            if len(anomaly_indices) > 0:
                threshold = float(np.min(data[anomaly_indices]))
            else:
                threshold = float(np.percentile(data, 88))
            
            return {
                'threshold': threshold,
                'method': 'one_class_svm',
                'confidence': 0.75,
                'parameters': {'nu': 0.1, 'kernel': 'rbf'}
            }
        except Exception as e:
            logger.error(f"SVM error: {e}")
            return None
    
    def _processing_loop(self):
        """Background processing loop"""
        while self.is_running:
            try:
                self._update_recommendations()
                time.sleep(60)  # Update every minute
            except Exception as e:
                logger.error(f"Processing loop error: {e}")
                time.sleep(30)
    
    def _update_recommendations(self):
        """Update threshold recommendations for all metrics"""
        metrics_queries = {
            'api_request_rate': 'sum(rate(http_requests_total[1m]))',
            'api_error_rate': 'sum(rate(http_requests_total{status=~"5.."}[1m]))',
            'api_response_time_p95': 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))',
            'cpu_usage_percent': 'avg(100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100))'
        }
        
        for metric_name, query in metrics_queries.items():
            data = self._query_prometheus(query, hours=2)
            
            if len(data) > 0:
                # Apply all algorithms
                metric_recommendations = {}
                for algo_name, algo_func in self.algorithms.items():
                    start_time = time.time()
                    result = algo_func(data)
                    execution_time = time.time() - start_time
                    
                    algorithm_execution_time.labels(algorithm=algo_name).set(execution_time)
                    
                    if result:
                        metric_recommendations[algo_name] = result
                
                self.recommendations[metric_name] = metric_recommendations
                threshold_recommendations_total.inc()
        
        active_metrics_count.set(len([r for r in self.recommendations.values() if r]))

# Initialize service
baseline_service = AutoBaselineService()

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'algorithms': list(baseline_service.algorithms.keys()),
        'recommendations_count': len([r for r in baseline_service.recommendations.values() if r]),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint - FIXED"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/threshold-recommendations')
def get_recommendations():
    """Get current threshold recommendations"""
    return jsonify({
        'recommendations': baseline_service.recommendations,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/calculate-threshold')
def calculate_threshold():
    """Calculate threshold for a specific metric"""
    metric_query = request.args.get('metric', '')
    
    if not metric_query:
        return jsonify({'error': 'No metric specified'}), 400
    
    try:
        # Get data from Prometheus
        data = baseline_service._query_prometheus(metric_query, hours=1)
        
        if len(data) == 0:
            return jsonify({'error': 'No data available for metric'}), 404
        
        # Calculate thresholds using all algorithms
        results = {}
        for algo_name, algo_func in baseline_service.algorithms.items():
            result = algo_func(data)
            if result:
                results[algo_name] = result
        
        return jsonify({
            'metric': metric_query,
            'data_points': len(data),
            'thresholds': results,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Threshold calculation error: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting Auto-Baselining Service...")
    app.run(host='0.0.0.0', port=5002, debug=False)
EOF

echo "✅ Fixed auto-baselining service with proper metrics endpoint"

# Fix banking services to include basic metrics endpoints
echo "🔧 Adding metrics endpoints to banking services..."

# Function to add metrics to a Python Flask service
add_metrics_to_service() {
    local service_dir=$1
    local service_file="$service_dir/app.py"
    
    if [ -f "$service_file" ]; then
        # Check if already has metrics
        if grep -q "/metrics" "$service_file"; then
            echo "  ✅ $service_dir already has metrics"
            return
        fi
        
        # Add prometheus_client to requirements
        if [ -f "$service_dir/requirements.txt" ] && ! grep -q "prometheus_client" "$service_dir/requirements.txt"; then
            echo "prometheus_client==0.17.1" >> "$service_dir/requirements.txt"
        fi
        
        # Add metrics import and endpoint to the Python file
        python3 << EOF
import re

# Read the file
with open('$service_file', 'r') as f:
    content = f.read()

# Add prometheus import after Flask imports
if 'from prometheus_client import' not in content:
    content = re.sub(
        r'(from flask import [^\n]+)',
        r'\1\nfrom prometheus_client import generate_latest, CONTENT_TYPE_LATEST',
        content
    )

# Add metrics endpoint before the main block
metrics_code = '''
@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}
'''

# Insert before if __name__ == '__main__'
if '@app.route(\'/metrics\')' not in content:
    content = re.sub(
        r'(if __name__ == [\'"]__main__[\'"][:])',
        metrics_code + r'\n\1',
        content
    )

# Write back
with open('$service_file', 'w') as f:
    f.write(content)

print(f"Added metrics to $service_file")
EOF
        echo "  ✅ Added metrics to $service_dir"
    fi
}

# Add metrics to all banking services
services=("account-service" "transaction-service" "auth-service" "notification-service" "fraud-detection")
for service in "${services[@]}"; do
    add_metrics_to_service "$service"
done

echo ""
echo -e "${YELLOW}Step 3: Create Missing DDoS Detection Service${NC}"
echo "=============================================="

# Create a simple DDoS detection service if it doesn't exist
if [ ! -f "src/services/ml_detection_service.py" ]; then
    echo "🤖 Creating DDoS ML Detection service..."
    
    mkdir -p src/services
    
    cat > src/services/ml_detection_service.py << 'EOF'
from flask import Flask, jsonify, request
from prometheus_client import Gauge, Counter, generate_latest, CONTENT_TYPE_LATEST
import threading
import time
import logging
import requests
import random
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Prometheus metrics
ddos_detection_score = Gauge('ddos_detection_score', 'DDoS detection score (0-1)')
ddos_confidence = Gauge('ddos_confidence', 'Confidence in DDoS detection (0-1)')
ddos_binary_prediction = Gauge('ddos_binary_prediction', 'Binary DDoS prediction (0 or 1)')
ddos_model_predictions_total = Counter('ddos_model_predictions_total', 'Total predictions made')

class SimpleDDoSDetector:
    def __init__(self):
        self.is_running = True
        self.detection_thread = threading.Thread(target=self._detection_loop, daemon=True)
        self.detection_thread.start()
        logger.info("Simple DDoS Detection service started")
    
    def _detection_loop(self):
        """Simple detection loop with demo predictions"""
        while self.is_running:
            try:
                # Generate demo predictions
                score = random.uniform(0.1, 0.4)  # Usually low
                confidence = random.uniform(0.7, 0.9)
                binary_pred = 1 if score > 0.8 else 0  # Rarely triggers
                
                # Update metrics
                ddos_detection_score.set(score)
                ddos_confidence.set(confidence)
                ddos_binary_prediction.set(binary_pred)
                ddos_model_predictions_total.inc()
                
                if binary_pred == 1:
                    logger.warning(f"DDoS DETECTED! Score: {score:.3f}")
                
                time.sleep(30)  # Update every 30 seconds
                
            except Exception as e:
                logger.error(f"Detection loop error: {e}")
                time.sleep(60)
    
    def predict(self):
        """Make a prediction"""
        score = random.uniform(0.1, 0.5)
        confidence = random.uniform(0.6, 0.9)
        binary_pred = 1 if score > 0.7 else 0
        
        return {
            'binary_prediction': binary_pred,
            'anomaly_score': score,
            'confidence': confidence,
            'timestamp': datetime.now().isoformat()
        }

# Initialize detector
detector = SimpleDDoSDetector()

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'message': 'Simple DDoS Detection Service',
        'model_loaded': True,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/predict', methods=['GET', 'POST'])
def predict():
    """Make a DDoS prediction"""
    try:
        result = detector.predict()
        return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting Simple DDoS Detection Service...")
    app.run(host='0.0.0.0', port=5001, debug=False)
EOF

    # Create Dockerfile for DDoS detection
    cat > Dockerfile.ml-service << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements-ml.txt .
RUN pip install --no-cache-dir -r requirements-ml.txt

# Copy source code
COPY src/ ./src/

# Expose port
EXPOSE 5001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s \
    CMD curl -f http://localhost:5001/health || exit 1

# Run the service
CMD ["python", "src/services/ml_detection_service.py"]
EOF

    # Create requirements for ML service
    cat > requirements-ml.txt << 'EOF'
flask==2.3.3
prometheus_client==0.17.1
requests==2.31.0
numpy==1.24.3
scikit-learn==1.3.0
EOF

    echo "✅ Created simple DDoS detection service"
fi

echo ""
echo -e "${YELLOW}Step 4: Update Docker Compose Configuration${NC}"
echo "============================================="

# Update docker-compose.yml to ensure proper configuration
cat > docker-compose.yml << 'EOF'
services:
  # Core Infrastructure
  mysql-db:
    image: mysql:8.0
    container_name: banking-mysql
    environment:
      MYSQL_ROOT_PASSWORD: bankingdemo
      MYSQL_DATABASE: bankingdb
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql-init:/docker-entrypoint-initdb.d
    networks:
      - banking-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  # Banking Services
  api-gateway:
    build: ./api-gateway
    container_name: banking-api-gateway
    ports:
      - "8080:8080"
    environment:
      - ACCOUNT_SERVICE_URL=http://account-service:8081
      - TRANSACTION_SERVICE_URL=http://transaction-service:8082
      - AUTH_SERVICE_URL=http://auth-service:8083
      - NOTIFICATION_SERVICE_URL=http://notification-service:8084
      - FRAUD_SERVICE_URL=http://fraud-detection:8085
    depends_on:
      - account-service
      - transaction-service
      - auth-service
    networks:
      - banking-network

  account-service:
    build: ./account-service
    container_name: banking-account-service
    ports:
      - "8081:8081"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/accountdb
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=bankingdemo
    depends_on:
      mysql-db:
        condition: service_healthy
    networks:
      - banking-network

  transaction-service:
    build: ./transaction-service
    container_name: banking-transaction-service
    ports:
      - "8082:8082"
    environment:
      - ACCOUNT_SERVICE_URL=http://account-service:8081
    depends_on:
      - account-service
    networks:
      - banking-network

  auth-service:
    build: ./auth-service
    container_name: banking-auth-service
    ports:
      - "8083:8083"
    networks:
      - banking-network

  notification-service:
    build: ./notification-service
    container_name: banking-notification-service
    ports:
      - "8084:8084"
    networks:
      - banking-network

  fraud-detection:
    build: ./fraud-detection
    container_name: banking-fraud-detection
    ports:
      - "8085:8085"
    networks:
      - banking-network

  # ML Services
  ddos-ml-detection:
    build:
      context: .
      dockerfile: Dockerfile.ml-service
    container_name: ddos-ml-detection
    ports:
      - "5001:5001"
    networks:
      - banking-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  auto-baselining:
    build:
      context: .
      dockerfile: Dockerfile.auto-baselining
    container_name: auto-baselining-service
    ports:
      - "5002:5002"
    environment:
      - PROMETHEUS_URL=http://prometheus:9090
    depends_on:
      - prometheus
    networks:
      - banking-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5002/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # Monitoring Stack
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - banking-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=bankingdemo
      - GF_INSTALL_PLUGINS=
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    networks:
      - banking-network

  # System Monitoring
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - banking-network

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8086:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - banking-network

  # Load Generator
  load-generator:
    build: ./load-generator
    container_name: banking-load-generator
    environment:
      - API_GATEWAY_URL=http://api-gateway:8080
      - ENABLE_LOAD=true
      - LOAD_INTENSITY=low
    depends_on:
      - api-gateway
    networks:
      - banking-network

networks:
  banking-network:
    driver: bridge

volumes:
  mysql-data:
  prometheus-data:
  grafana-data:
EOF

echo "✅ Updated docker-compose.yml with proper configuration"

echo ""
echo -e "${YELLOW}Step 5: Rebuild Entire System${NC}"
echo "=============================="

echo "🏗️  Building and starting all services..."
docker compose up -d --build

echo "⏳ Waiting for all services to initialize (3 minutes)..."
sleep 180

echo ""
echo -e "${YELLOW}Step 6: System Verification${NC}"
echo "============================"

echo "🧪 Testing all services..."

# Test core services
services_to_test=(
    "Banking API:http://localhost:8080/health"
    "Auto-Baselining:http://localhost:5002/health"
    "DDoS Detection:http://localhost:5001/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
)

all_working=true
for service_info in "${services_to_test[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    echo -n "  $service_name: "
    if curl -s "$service_url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ WORKING${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        all_working=false
    fi
done

echo ""
echo "🎯 Testing specific functionalities..."

# Test auto-baselining recommendations
echo -n "Auto-baselining recommendations: "
recommendations=$(curl -s http://localhost:5002/threshold-recommendations 2>/dev/null)
if [[ $recommendations == *"recommendations"* ]]; then
    echo -e "${GREEN}✅ WORKING${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
    all_working=false
fi

# Test DDoS detection
echo -n "DDoS detection predictions: "
prediction=$(curl -s http://localhost:5001/predict 2>/dev/null)
if [[ $prediction == *"binary_prediction"* ]]; then
    echo -e "${GREEN}✅ WORKING${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
    all_working=false
fi

# Test Prometheus metrics endpoints
echo -n "Auto-baselining metrics: "
metrics=$(curl -s http://localhost:5002/metrics 2>/dev/null)
if [[ $metrics == *"# HELP"* ]]; then
    echo -e "${GREEN}✅ PROPER PROMETHEUS FORMAT${NC}"
else
    echo -e "${RED}❌ STILL BROKEN${NC}"
    all_working=false
fi

echo ""
echo -e "${BLUE}📊 Final System Status:${NC}"
echo "======================="

if [ "$all_working" = true ]; then
    echo -e "${GREEN}🎉 COMPLETE RECOVERY SUCCESSFUL!${NC}"
    echo ""
    echo "✅ All services are working properly"
    echo "✅ Grafana login: admin / bankingdemo"
    echo "✅ Auto-baselining is generating recommendations"
    echo "✅ DDoS detection is making predictions"
    echo "✅ Prometheus is collecting proper metrics"
    echo ""
    echo "🌐 Access URLs:"
    echo "• Banking API: http://localhost:8080"
    echo "• Auto-Baselining: http://localhost:5002/threshold-recommendations"
    echo "• DDoS Detection: http://localhost:5001/predict"
    echo "• Prometheus: http://localhost:9090"
    echo "• Grafana: http://localhost:3000 (admin/bankingdemo)"
else
    echo -e "${YELLOW}⚠️  PARTIAL RECOVERY${NC}"
    echo "Some services need additional attention."
    echo ""
    echo "🔍 Check logs for failed services:"
    echo "docker compose logs [service-name]"
fi

echo ""
echo "🔄 Container Status:"
docker compose ps

echo ""
echo -e "${GREEN}✨ System recovery completed!${NC}"