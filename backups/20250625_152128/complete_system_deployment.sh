#!/bin/bash

echo "🚀 Starting Complete DDoS Detection System Deployment"
echo "======================================================"

# Capture current directory (DDoS project directory)
DDOS_PROJECT_DIR="$(pwd)"
echo "DDoS Project Directory: $DDOS_PROJECT_DIR"

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a service is running
check_service() {
    local service_name=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}Checking $service_name...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $service_name is running${NC}"
            return 0
        fi
        
        echo "  Attempt $attempt/$max_attempts - waiting for $service_name..."
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}❌ $service_name failed to start${NC}"
    return 1
}

# Function to kill process on port
kill_port() {
    local port=$1
    local pid=$(lsof -ti:$port)
    if [ ! -z "$pid" ]; then
        echo "Killing process on port $port (PID: $pid)"
        kill -9 $pid
        sleep 2
    fi
}

# Clean up existing processes
echo "🧹 Cleaning up existing processes..."
kill_port 9090  # Prometheus
kill_port 3000  # Grafana  
kill_port 5000  # ML Detection Service

# Step 1: Start Banking Microservices
echo ""
echo "🏦 Step 1: Starting Banking Microservices..."

# Check if BANKING_DEMO_PATH is set, otherwise prompt user
if [ -z "$BANKING_DEMO_PATH" ]; then
    echo "Please enter the full path to your banking-demo folder:"
    read -p "Path: " BANKING_DEMO_PATH
fi

echo "Using banking demo path: $BANKING_DEMO_PATH"
cd "$BANKING_DEMO_PATH"

# Check if docker-compose exists
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Banking microservices not found at $BANKING_DEMO_PATH${NC}"
    echo "Please ensure your banking demo is set up first"
    exit 1
fi

# Start banking services
docker compose down
docker compose up -d

# Wait for banking services
sleep 10
if check_service "Banking API Gateway" "http://localhost:8080/health"; then
    echo -e "${GREEN}✅ Banking microservices are running${NC}"
else
    echo -e "${RED}❌ Failed to start banking microservices${NC}"
    exit 1
fi

# Step 2: Start Prometheus
echo ""
echo "📊 Step 2: Starting Prometheus..."
cd "$DDOS_PROJECT_DIR"

# Create Prometheus data directory
mkdir -p /tmp/prometheus-data

# Start Prometheus with your custom config
prometheus \
    --config.file=config/prometheus.yml \
    --storage.tsdb.path=/tmp/prometheus-data \
    --web.console.libraries=/usr/share/prometheus/console_libraries \
    --web.console.templates=/usr/share/prometheus/consoles \
    --web.enable-lifecycle \
    --web.listen-address=0.0.0.0:9090 &

PROMETHEUS_PID=$!
echo "Prometheus PID: $PROMETHEUS_PID"

if check_service "Prometheus" "http://localhost:9090/-/healthy"; then
    echo -e "${GREEN}✅ Prometheus is running${NC}"
else
    echo -e "${RED}❌ Failed to start Prometheus${NC}"
    exit 1
fi

# Step 3: Start Grafana
echo ""
echo "📈 Step 3: Starting Grafana..."

# Create Grafana data directory
mkdir -p /tmp/grafana-data

# Start Grafana
grafana-server \
    --homepath /usr/local/share/grafana \
    --config /usr/local/etc/grafana/grafana.ini \
    --pidfile /tmp/grafana.pid &

GRAFANA_PID=$!
echo "Grafana PID: $GRAFANA_PID"

if check_service "Grafana" "http://localhost:3000/api/health"; then
    echo -e "${GREEN}✅ Grafana is running${NC}"
    echo "  📱 Grafana UI: http://localhost:3000 (admin/admin)"
else
    echo -e "${RED}❌ Failed to start Grafana${NC}"
    exit 1
fi

# Step 4: Start ML Detection Service
echo ""
echo "🤖 Step 4: Starting ML Detection Service..."
cd "$DDOS_PROJECT_DIR"

# Check if model files exist
if [ ! -f "data/models/isolation_forest_model.pkl" ]; then
    echo -e "${RED}❌ Model files not found. Please train the model first.${NC}"
    exit 1
fi

# Start ML Detection Service
python src/services/ml_detection_service.py &
ML_SERVICE_PID=$!
echo "ML Detection Service PID: $ML_SERVICE_PID"

if check_service "ML Detection Service" "http://localhost:5000/health"; then
    echo -e "${GREEN}✅ ML Detection Service is running${NC}"
else
    echo -e "${RED}❌ Failed to start ML Detection Service${NC}"
    exit 1
fi

# Step 5: Generate some initial traffic
echo ""
echo "🚦 Step 5: Generating initial traffic for baseline..."
cd "$BANKING_DEMO_PATH"
if [ -f "generate_normal_traffic.sh" ]; then
    ./generate_normal_traffic.sh &
    echo "✅ Normal traffic generation started"
else
    echo -e "${YELLOW}⚠️  generate_normal_traffic.sh not found, skipping traffic generation${NC}"
fi

# Wait for metrics to populate
echo "⏳ Waiting 60 seconds for metrics to populate..."
sleep 60

# Return to DDoS detection system directory (where this script was run from)
cd "$DDOS_PROJECT_DIR"

# Step 6: System Status Check
echo ""
echo "🔍 Step 6: Final System Status Check..."
echo "======================================"

services=(
    "Banking API Gateway:http://localhost:8080/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
    "ML Detection Service:http://localhost:5000/health"
)

all_running=true
for service_info in "${services[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    if curl -s "$service_url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $service_name: Running${NC}"
    else
        echo -e "${RED}❌ $service_name: Not responding${NC}"
        all_running=false
    fi
done

# Step 7: Display Access Information
echo ""
echo "🎯 System Access Information:"
echo "=============================="
echo "🏦 Banking API: http://localhost:8080"
echo "📊 Prometheus: http://localhost:9090"
echo "📈 Grafana: http://localhost:3000 (admin/admin)"
echo "🤖 ML Service: http://localhost:5000"
echo ""
echo "📊 Key Prometheus Queries to Try:"
echo "- up"
echo "- ddos_detection_score"
echo "- ddos_binary_prediction"
echo "- sum(rate(http_requests_total[1m]))"
echo ""

# Save PIDs for cleanup
echo "💾 Saving process IDs for cleanup..."
cat > /tmp/ddos_system_pids.txt << EOF
PROMETHEUS_PID=$PROMETHEUS_PID
GRAFANA_PID=$GRAFANA_PID
ML_SERVICE_PID=$ML_SERVICE_PID
EOF

echo "📁 Process IDs saved to /tmp/ddos_system_pids.txt"
echo ""

if [ "$all_running" = true ]; then
    echo -e "${GREEN}🎉 SUCCESS: All services are running!${NC}"
    echo ""
    echo "🔥 Next Steps:"
    echo "1. Open Grafana (http://localhost:3000) and import the DDoS dashboard"
    echo "2. Check Prometheus metrics (http://localhost:9090)"
    echo "3. Run DDoS simulation: python scripts/test_ddos_system.py --mode comprehensive"
    echo ""
    echo "🛑 To stop all services, run: bash scripts/cleanup_system.sh"
else
    echo -e "${RED}❌ Some services failed to start. Check the logs above.${NC}"
    exit 1
fi