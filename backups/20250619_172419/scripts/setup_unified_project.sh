#!/bin/bash

echo "🚀 Setting Up Unified DDoS Detection & Banking System"
echo "================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get current directory
PROJECT_DIR="$(pwd)"
echo "Project Directory: $PROJECT_DIR"

# Step 1: Create necessary directories
echo ""
echo "📁 Step 1: Creating directory structure..."

directories=(
    "prometheus"
    "grafana/datasources"
    "grafana/dashboards"
    "data/models"
)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "  ✅ Created: ${GREEN}$dir${NC}"
    else
        echo -e "  ℹ️ Exists: ${YELLOW}$dir${NC}"
    fi
done

# Step 2: Check if banking services were copied
echo ""
echo "🏦 Step 2: Checking banking services..."

required_services=(
    "api-gateway"
    "account-service"
    "transaction-service"
    "auth-service"
    "notification-service"
    "fraud-detection"
    "mysql-init"
)

missing_services=()
for service in "${required_services[@]}"; do
    if [ -d "$service" ]; then
        echo -e "  ✅ Found: ${GREEN}$service${NC}"
    else
        echo -e "  ❌ Missing: ${RED}$service${NC}"
        missing_services+=("$service")
    fi
done

if [ ${#missing_services[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing banking services. Please copy them from banking-demo first.${NC}"
    echo "Run: cp -r /Users/rishabh/banking-demo/* ."
    exit 1
fi

# Step 3: Check if ML model files exist
echo ""
echo "🤖 Step 3: Checking ML model files..."

if [ -f "data/models/isolation_forest_model.pkl" ]; then
    echo -e "  ✅ ML Model: ${GREEN}FOUND${NC}"
else
    echo -e "  ⚠️ ML Model: ${YELLOW}NOT FOUND${NC}"
    echo "  The ML service will run in demo mode"
fi

# Step 4: Verify all configuration files exist
echo ""
echo "📋 Step 4: Checking configuration files..."

config_files=(
    "docker-compose.yml"
    "Dockerfile.ml-service"
    "requirements-ml.txt"
    "minimal_ml_service.py"
    "prometheus/prometheus.yml"
    "prometheus/ddos_alert_rules.yml"
    "grafana/datasources/datasource.yml"
    "grafana/dashboards/dashboard.yml"
)

missing_configs=()
for config in "${config_files[@]}"; do
    if [ -f "$config" ]; then
        echo -e "  ✅ Found: ${GREEN}$config${NC}"
    else
        echo -e "  ❌ Missing: ${RED}$config${NC}"
        missing_configs+=("$config")
    fi
done

if [ ${#missing_configs[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️ Some configuration files are missing. Please create them first.${NC}"
fi

# Step 5: Build and start services
echo ""
echo "🏗️ Step 5: Building and starting all services..."

# Stop any existing services first
echo "🛑 Stopping any existing services..."
docker compose down --volumes --remove-orphans 2>/dev/null || true

# Build and start services
echo "🚀 Starting unified DDoS detection system..."
docker compose up -d --build

# Step 6: Wait for services to be ready
echo ""
echo "⏳ Step 6: Waiting for services to be ready..."

services_to_check=(
    "Banking API:http://localhost:8080/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
    "ML Detection:http://localhost:5001/health"
)

echo "Waiting 60 seconds for all services to start..."
sleep 60

all_healthy=true
for service_info in "${services_to_check[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    if curl -s "$service_url" > /dev/null 2>&1; then
        echo -e "  ✅ $service_name: ${GREEN}HEALTHY${NC}"
    else
        echo -e "  ❌ $service_name: ${RED}NOT RESPONDING${NC}"
        all_healthy=false
    fi
done

# Step 7: Verify ML integration
echo ""
echo "🔍 Step 7: Verifying ML integration..."

# Check if ML service appears in Prometheus targets
sleep 10
if curl -s "http://localhost:9090/api/v1/targets" | grep -q "ddos-ml-detection"; then
    echo -e "  ✅ ML Service Target: ${GREEN}DISCOVERED${NC}"
else
    echo -e "  ⚠️ ML Service Target: ${YELLOW}NOT YET DISCOVERED${NC}"
fi

# Check if metrics are available
if curl -s "http://localhost:9090/api/v1/query?query=ddos_detection_score" | grep -q "ddos_detection_score"; then
    echo -e "  ✅ DDoS Metrics: ${GREEN}AVAILABLE${NC}"
else
    echo -e "  ⚠️ DDoS Metrics: ${YELLOW}NOT YET AVAILABLE${NC}"
fi

# Step 8: Display access information
echo ""
echo "🌐 System Access Information:"
echo "============================"
echo "🏦 Banking API: http://localhost:8080"
echo "📊 Prometheus: http://localhost:9090"
echo "📈 Grafana: http://localhost:3000 (admin/admin)"
echo "🤖 ML Detection Service: http://localhost:5001"
echo ""
echo "🔗 Quick Test Links:"
echo "==================="
echo "• Banking Health: http://localhost:8080/health"
echo "• ML Prediction: http://localhost:5001/predict"
echo "• Prometheus Targets: http://localhost:9090/targets"
echo "• Prometheus Metrics: http://localhost:9090/graph?g0.expr=ddos_detection_score"

# Step 9: Show container status
echo ""
echo "🐳 Container Status:"
echo "==================="
docker compose ps

echo ""
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}🎉 SUCCESS! Unified DDoS Detection System is running!${NC}"
    echo ""
    echo "📊 Next Steps:"
    echo "============="
    echo "1. Test the system: curl http://localhost:5001/predict"
    echo "2. View Prometheus: http://localhost:9090"
    echo "3. Check Grafana: http://localhost:3000"
    echo "4. Run DDoS simulation: ./test_ddos_simulation.sh"
    echo ""
    echo "🛑 To stop everything: docker compose down"
else
    echo -e "${YELLOW}⚠️ Some services are not responding yet. This is normal on first startup.${NC}"
    echo "Wait a few more minutes and check the services again."
    echo ""
    echo "🔍 Troubleshooting:"
    echo "=================="
    echo "• Check logs: docker compose logs [service-name]"
    echo "• Restart: docker compose restart [service-name]"
    echo "• Full restart: docker compose down && docker compose up -d"
fi

echo ""
echo -e "${GREEN}✨ Setup complete!${NC}"