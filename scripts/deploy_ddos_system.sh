#!/bin/bash
# scripts/deploy_ddos_system.sh - Deploy complete DDoS detection system

set -e  # Exit on any error

echo "🚀 Deploying Banking DDoS Detection System"
echo "=" * 50

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

# Check if Python packages are installed
python3 -c "import flask, joblib, sklearn, prometheus_client" 2>/dev/null || {
    print_error "Missing Python packages. Installing..."
    pip3 install flask joblib scikit-learn prometheus-client requests
}

# Check if trained model exists
if [ ! -f "data/models/isolation_forest_model.pkl" ]; then
    print_error "Trained ML model not found. Please run train_simple_model.py first."
    exit 1
fi

print_success "Prerequisites check passed"

# Create necessary directories
print_status "Creating directories..."
mkdir -p logs
mkdir -p config
mkdir -p data/models

# Check if banking services are running
print_status "Checking banking services..."
if ! curl -s http://localhost:8080/health > /dev/null; then
    print_warning "Banking services not running. Starting them..."
    if [ -d "../banking-demo" ]; then
        cd ../banking-demo
        docker compose up -d
        cd - > /dev/null
        sleep 30  # Wait for services to start
    else
        print_error "Banking demo not found. Please ensure your banking microservices are running."
        exit 1
    fi
fi

# Start Prometheus with enhanced config
print_status "Starting Prometheus..."
if pgrep prometheus > /dev/null; then
    print_warning "Prometheus already running. Stopping existing instance..."
    pkill prometheus
    sleep 5
fi

prometheus --config.file=config/prometheus.yml \
           --storage.tsdb.path=./data/prometheus \
           --web.console.libraries=./console_libraries \
           --web.console.templates=./consoles \
           --web.enable-lifecycle \
           --log.level=info \
           > logs/prometheus.log 2>&1 &

PROMETHEUS_PID=$!
echo $PROMETHEUS_PID > logs/prometheus.pid
print_success "Prometheus started (PID: $PROMETHEUS_PID)"

# Wait for Prometheus to start
sleep 10

# Start Grafana
print_status "Starting Grafana..."
if pgrep grafana-server > /dev/null; then
    print_warning "Grafana already running. Stopping existing instance..."
    pkill grafana-server
    sleep 5
fi

grafana-server --homepath=/usr/local/share/grafana \
               --config=config/grafana.ini \
               > logs/grafana.log 2>&1 &

GRAFANA_PID=$!
echo $GRAFANA_PID > logs/grafana.pid
print_success "Grafana started (PID: $GRAFANA_PID)"

# Wait for Grafana to start
sleep 15

# Start ML Detection Service
print_status "Starting ML Detection Service..."
if pgrep -f "ml_detection_service.py" > /dev/null; then
    print_warning "ML Detection Service already running. Stopping existing instance..."
    pkill -f "ml_detection_service.py"
    sleep 5
fi

python3 src/services/ml_detection_service.py > logs/ml_detection.log 2>&1 &
ML_SERVICE_PID=$!
echo $ML_SERVICE_PID > logs/ml_service.pid
print_success "ML Detection Service started (PID: $ML_SERVICE_PID)"

# Wait for ML service to initialize
sleep 20

# Health checks
print_status "Performing health checks..."

# Check Prometheus
if curl -s http://localhost:9090/-/healthy > /dev/null; then
    print_success "✅ Prometheus is healthy"
else
    print_error "❌ Prometheus health check failed"
fi

# Check Grafana
if curl -s http://localhost:3000/api/health > /dev/null; then
    print_success "✅ Grafana is healthy"
else
    print_error "❌ Grafana health check failed"
fi

# Check ML Detection Service
if curl -s http://localhost:5000/health > /dev/null; then
    ML_STATUS=$(curl -s http://localhost:5000/health | python3 -c "import sys, json; print(json.load(sys.stdin)['status'])")
    if [ "$ML_STATUS" = "healthy" ]; then
        print_success "✅ ML Detection Service is healthy"
    else
        print_warning "⚠️  ML Detection Service is running but not fully healthy"
    fi
else
    print_error "❌ ML Detection Service health check failed"
fi

# Check banking services
if curl -s http://localhost:8080/health > /dev/null; then
    print_success "✅ Banking services are healthy"
else
    print_warning "⚠️  Banking services may not be fully ready"
fi

# Configure Grafana datasource (Prometheus)
print_status "Configuring Grafana datasource..."
sleep 5  # Give Grafana more time to start

curl -X POST \
  http://admin:admin@localhost:3000/api/datasources \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Prometheus",
    "type": "prometheus", 
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true
  }' > /dev/null 2>&1 && print_success "✅ Prometheus datasource configured" || print_warning "⚠️  Datasource might already exist"

# Import dashboard
print_status "Importing DDoS detection dashboard..."
if [ -f "config/grafana_dashboard.json" ]; then
    curl -X POST \
      http://admin:admin@localhost:3000/api/dashboards/db \
      -H 'Content-Type: application/json' \
      -d @config/grafana_dashboard.json > /dev/null 2>&1 && \
      print_success "✅ Dashboard imported successfully" || \
      print_warning "⚠️  Dashboard import may have failed"
fi

# Final status summary
echo ""
echo "🎉 Deployment Complete!"
echo "=" * 30

echo ""
echo "📊 Access URLs:"
echo "  Prometheus:       http://localhost:9090"
echo "  Grafana:          http://localhost:3000 (admin/admin)"
echo "  ML Detection:     http://localhost:5000"
echo "  Banking API:      http://localhost:8080"

echo ""
echo "📁 Log Files:"
echo "  Prometheus:       logs/prometheus.log"
echo "  Grafana:          logs/grafana.log" 
echo "  ML Detection:     logs/ml_detection.log"

echo ""
echo "🔄 Process IDs:"
echo "  Prometheus:       $(cat logs/prometheus.pid 2>/dev/null || echo 'Not found')"
echo "  Grafana:          $(cat logs/grafana.pid 2>/dev/null || echo 'Not found')"
echo "  ML Detection:     $(cat logs/ml_service.pid 2>/dev/null || echo 'Not found')"

echo ""
echo "🧪 Testing Commands:"
echo "  Test ML prediction:    curl -X POST http://localhost:5000/predict"
echo "  Check service status:  curl http://localhost:5000/status"
echo "  View metrics:         curl http://localhost:5000/metrics"

echo ""
echo "📈 Next Steps:"
echo "1. Open Grafana at http://localhost:3000"
echo "2. Navigate to the DDoS Detection dashboard"
echo "3. Monitor real-time detection metrics"
echo "4. Test DDoS simulation (if available)"
echo "5. Configure alert notifications"

echo ""
print_success "🚀 Banking DDoS Detection System is now running!"