#!/bin/bash

echo "🔧 System Recovery Script for Complete Banking AIOps System"
echo "=========================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Navigate to project directory
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" || {
    echo -e "${RED}❌ Could not find project directory${NC}"
    exit 1
}

echo "📂 Current directory: $(pwd)"

# Step 1: Docker cleanup
echo ""
echo -e "${YELLOW}🧹 Step 1: Docker System Cleanup${NC}"
echo "=================================="

echo "🛑 Stopping all containers..."
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml down --remove-orphans --volumes 2>/dev/null || \
docker compose down --remove-orphans --volumes 2>/dev/null

echo "🗑️  Cleaning Docker system..."
docker system prune -a --volumes -f

echo "🔄 Restarting Docker daemon..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   ℹ️  On macOS - Please restart Docker Desktop manually if needed"
    echo "   💡 Docker Desktop → Restart"
    sleep 5
else
    sudo systemctl restart docker
    sleep 10
fi

# Step 2: Verify essential files
echo ""
echo -e "${YELLOW}📋 Step 2: File System Check${NC}"
echo "============================="

# Check transaction monitoring services
transaction_services=("transaction-monitor" "performance-aggregator" "anomaly-injector")
for service in "${transaction_services[@]}"; do
    if [ -d "$service" ] && [ -f "$service/requirements.txt" ]; then
        echo -e "   ✅ ${GREEN}$service directory found${NC}"
    else
        echo -e "   ❌ ${RED}$service directory missing${NC}"
    fi
done

# Check if load-generator requirements.txt exists
if [ ! -f "load-generator/requirements.txt" ]; then
    echo "🔧 Creating missing load-generator/requirements.txt..."
    mkdir -p load-generator
    cat > load-generator/requirements.txt << EOF
requests==2.31.0
flask==2.3.3
numpy==1.24.3
pandas==2.0.3
EOF
    echo -e "   ✅ ${GREEN}Created load-generator/requirements.txt${NC}"
else
    echo -e "   ✅ ${GREEN}load-generator/requirements.txt exists${NC}"
fi

# Check docker-compose files
if [ -f "docker-compose.yml" ]; then
    echo -e "   ✅ ${GREEN}docker-compose.yml found${NC}"
else
    echo -e "   ❌ ${RED}docker-compose.yml missing${NC}"
fi

if [ -f "docker-compose.transaction-monitoring.yml" ]; then
    echo -e "   ✅ ${GREEN}docker-compose.transaction-monitoring.yml found${NC}"
else
    echo -e "   ⚠️  ${YELLOW}docker-compose.transaction-monitoring.yml missing${NC}"
fi

# Step 3: Check Dockerfiles
echo ""
echo "🐳 Checking Dockerfiles..."

essential_dockerfiles=(
    "Dockerfile.ml-service"
    "Dockerfile.auto-baselining"
)

for dockerfile in "${essential_dockerfiles[@]}"; do
    if [ -f "$dockerfile" ]; then
        echo -e "   ✅ ${GREEN}$dockerfile found${NC}"
    else
        echo -e "   ⚠️  ${YELLOW}$dockerfile missing${NC}"
    fi
done

# Step 4: Remove problematic version attributes
echo ""
echo -e "${YELLOW}🔧 Step 3: Fix Docker Compose Warnings${NC}"
echo "======================================="

for compose_file in docker-compose.yml docker-compose.override.yml docker-compose.transaction-monitoring.yml; do
    if [ -f "$compose_file" ] && grep -q "version:" "$compose_file" 2>/dev/null; then
        echo "🔧 Removing obsolete 'version' attribute from $compose_file..."
        sed -i.bak '/^version:/d' "$compose_file"
        echo -e "   ✅ ${GREEN}Fixed $compose_file${NC}"
    fi
done

# Step 5: Selective service restart
echo ""
echo -e "${YELLOW}🚀 Step 4: Selective Service Restart${NC}"
echo "====================================="

echo "🔄 Starting core services first..."

# Start core infrastructure first
docker compose up -d mysql-db prometheus grafana node-exporter cadvisor

echo "⏳ Waiting for core services (45 seconds)..."
sleep 45

# Start banking services
echo "🏦 Starting banking services..."
docker compose up -d api-gateway account-service transaction-service auth-service notification-service fraud-detection

echo "⏳ Waiting for banking services (30 seconds)..."
sleep 30

# Start ML services (these might fail, but that's ok)
echo "🤖 Starting ML services..."
docker compose up -d ddos-ml-detection auto-baselining 2>/dev/null || {
    echo -e "   ⚠️  ${YELLOW}Some ML services failed to start (this is expected if Dockerfiles/models are missing)${NC}"
}

# Start transaction monitoring services
echo "💰 Starting transaction monitoring services..."
if [ -f "docker-compose.transaction-monitoring.yml" ]; then
    docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml up -d transaction-monitor performance-aggregator anomaly-injector 2>/dev/null || {
        echo -e "   ⚠️  ${YELLOW}Transaction monitoring services failed to start${NC}"
    }
else
    echo -e "   ⚠️  ${YELLOW}Transaction monitoring compose file not found${NC}"
fi

# Load generator last
echo "⚡ Starting load generator..."
docker compose up -d load-generator 2>/dev/null || {
    echo -e "   ⚠️  ${YELLOW}Load generator failed to start${NC}"
}

# Step 6: System health check
echo ""
echo -e "${YELLOW}🏥 Step 5: Health Check${NC}"
echo "======================"

echo "⏳ Waiting for services to stabilize (30 seconds)..."
sleep 30

# Check core services
services_to_check=(
    "Banking API:http://localhost:8080/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
)

all_healthy=true
for service_info in "${services_to_check[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    echo -n "Testing $service_name: "
    if curl -s "$service_url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
    else
        echo -e "${RED}❌ DOWN${NC}"
        all_healthy=false
    fi
done

# Check all ML and monitoring services
optional_services=(
    "DDoS ML Detection:http://localhost:5001/health"
    "Auto-Baselining:http://localhost:5002/health"
    "Transaction Monitor:http://localhost:5003/health"
    "Performance Aggregator:http://localhost:5004/health"
    "Anomaly Injector:http://localhost:5005/health"
)

ml_count=0
for service_info in "${optional_services[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    echo -n "Testing $service_name: "
    if curl -s "$service_url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ RUNNING${NC}"
        ((ml_count++))
    else
        echo -e "${YELLOW}⚠️  OFFLINE${NC}"
    fi
done

# Step 7: Show container status
echo ""
echo -e "${YELLOW}📊 Container Status:${NC}"
echo "==================="
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml ps 2>/dev/null || docker compose ps

echo ""
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}🎉 RECOVERY SUCCESSFUL!${NC}"
    echo ""
    echo "✅ Core system is running:"
    echo "🏦 Banking API: http://localhost:8080"
    echo "📊 Prometheus: http://localhost:9090"
    echo "📈 Grafana: http://localhost:3000 (admin/bankingdemo)"
    
    if [ $ml_count -gt 0 ]; then
        echo ""
        echo "🤖 ML/Monitoring services: $ml_count/5 running"
    fi
else
    echo -e "${YELLOW}⚠️  PARTIAL RECOVERY${NC}"
    echo "Core banking system should be working, but some services need attention."
fi

echo ""
echo "🔍 Troubleshooting commands:"
echo "==========================="
echo "# Check specific service logs:"
echo "docker compose logs [service-name]"
echo ""
echo "# Restart a specific service:"
echo "docker compose restart [service-name]"
echo ""
echo "# Full system status:"
echo "./system_status.sh"
echo ""
echo "# Import Transaction Dashboard:"
echo "./import-transaction-dashboard.sh"

echo ""
echo -e "${GREEN}🏁 Recovery script completed!${NC}"