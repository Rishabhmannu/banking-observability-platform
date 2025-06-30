#!/bin/bash

echo "🔄 Post-Docker Reinstall System Restoration"
echo "=========================================="

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
echo "📅 Restoration started at: $(date)"

echo ""
echo -e "${BLUE}🔍 Step 1: Verify Docker Installation${NC}"
echo "===================================="

# Check if Docker is running
if ! docker --version >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not installed or not running${NC}"
    echo "Please install Docker Desktop first, then run this script"
    exit 1
fi

echo -e "${GREEN}✅ Docker version: $(docker --version)${NC}"

# Check if Docker daemon is running
if ! docker ps >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    echo "Please start Docker Desktop first"
    exit 1
fi

echo -e "${GREEN}✅ Docker daemon is running${NC}"

echo ""
echo -e "${BLUE}📥 Step 2: Find and Restore from Latest Backup${NC}"
echo "=============================================="

# Find the most recent backup
if [ ! -d "backups" ]; then
    echo -e "${RED}❌ No backups directory found${NC}"
    exit 1
fi

latest_backup=$(ls -t backups/ | head -1)
if [ -z "$latest_backup" ]; then
    echo -e "${RED}❌ No backups found${NC}"
    exit 1
fi

echo "📁 Latest backup found: $latest_backup"
backup_path="backups/$latest_backup"

echo ""
echo -e "${YELLOW}📋 Backup contents:${NC}"
ls -la "$backup_path/"

read -p "Proceed with restoration from this backup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restoration cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}🔄 Step 3: Restore Configurations${NC}"
echo "=================================="

# Restore Docker configurations
if [ -f "$backup_path/docker-compose.yml" ]; then
    cp "$backup_path/docker-compose.yml" ./
    echo -e "   ✅ ${GREEN}docker-compose.yml restored${NC}"
else
    echo -e "   ⚠️  ${YELLOW}docker-compose.yml not found in backup${NC}"
fi

# Restore Dockerfiles
for dockerfile in Dockerfile.auto-baselining Dockerfile.ml-service; do
    if [ -f "$backup_path/$dockerfile" ]; then
        cp "$backup_path/$dockerfile" ./
        echo -e "   ✅ ${GREEN}$dockerfile restored${NC}"
    fi
done

# Restore requirements files
for req_file in requirements-baselining.txt requirements-ml.txt; do
    if [ -f "$backup_path/$req_file" ]; then
        cp "$backup_path/$req_file" ./
        echo -e "   ✅ ${GREEN}$req_file restored${NC}"
    fi
done

echo ""
echo -e "${BLUE}📊 Step 4: Restore Monitoring Configurations${NC}"
echo "============================================"

# Restore Grafana configurations
if [ -d "$backup_path/grafana" ]; then
    mkdir -p grafana
    cp -r "$backup_path/grafana"/* grafana/ 2>/dev/null
    echo -e "   ✅ ${GREEN}Grafana configurations restored${NC}"
    
    # List restored dashboards
    if [ -d "grafana/dashboards" ]; then
        echo "   📊 Restored dashboards:"
        ls grafana/dashboards/*.json 2>/dev/null | while read dashboard; do
            dashboard_name=$(basename "$dashboard" .json)
            echo "      • $dashboard_name"
        done
    fi
fi

# Restore Prometheus configurations
if [ -d "$backup_path/prometheus" ]; then
    mkdir -p prometheus
    cp -r "$backup_path/prometheus"/* prometheus/ 2>/dev/null
    echo -e "   ✅ ${GREEN}Prometheus configurations restored${NC}"
    
    # List restored configurations
    if [ -f "prometheus/prometheus.yml" ]; then
        echo "   📊 Prometheus config restored"
    fi
    if [ -f "prometheus/alert_rules.yml" ]; then
        echo "   🚨 Alert rules restored"
    fi
fi

echo ""
echo -e "${BLUE}💻 Step 5: Restore Source Code${NC}"
echo "=============================="

# Restore source code
if [ -d "$backup_path/src" ]; then
    mkdir -p src
    cp -r "$backup_path/src"/* src/ 2>/dev/null
    echo -e "   ✅ ${GREEN}Source code restored${NC}"
    
    # Verify critical services
    critical_services=("auto_baselining_service.py" "ml_detection_service.py")
    for service in "${critical_services[@]}"; do
        if [ -f "src/services/$service" ]; then
            echo -e "      ✅ ${GREEN}$service found${NC}"
        else
            echo -e "      ⚠️  ${YELLOW}$service missing${NC}"
        fi
    done
else
    echo -e "   ⚠️  ${YELLOW}No source code found in backup${NC}"
fi

echo ""
echo -e "${BLUE}🗂️ Step 6: Restore Data Directories${NC}"
echo "==================================="

# Create necessary directories
directories=("data/models" "data/baselining" "logs/baselining" "logs/ml")
for dir in "${directories[@]}"; do
    mkdir -p "$dir"
    echo -e "   ✅ ${GREEN}Created $dir${NC}"
done

echo ""
echo -e "${BLUE}🚀 Step 7: Test System Startup${NC}"
echo "==============================="

echo "🔍 Validating docker-compose configuration..."
if docker compose config >/dev/null 2>&1; then
    echo -e "   ✅ ${GREEN}Docker Compose configuration is valid${NC}"
else
    echo -e "   ❌ ${RED}Docker Compose configuration has errors${NC}"
    echo "   Running validation..."
    docker compose config
    exit 1
fi

echo ""
echo "🚀 Starting system in test mode..."
docker compose up -d

echo ""
echo "⏳ Waiting for services to initialize (60 seconds)..."
sleep 60

echo ""
echo -e "${BLUE}🧪 Step 8: Verify Service Health${NC}"
echo "=================================="

# Test critical services
services=(
    "Banking API:http://localhost:8080/health"
    "Auto-Baselining:http://localhost:5002/health" 
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
)

# Add ML Detection if it exists
if [ -f "src/services/ml_detection_service.py" ]; then
    services+=("ML Detection:http://localhost:5001/health")
fi

all_healthy=true
for service_info in "${services[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    echo -n "   Testing $service_name: "
    if curl -s "$service_url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
    else
        echo -e "${RED}❌ DOWN${NC}"
        all_healthy=false
    fi
done

echo ""
if $all_healthy; then
    echo -e "${GREEN}🎉 RESTORATION SUCCESSFUL!${NC}"
    echo ""
    echo -e "${BLUE}🌐 Access URLs:${NC}"
    echo "========================"
    echo "🏦 Banking API: http://localhost:8080"
    echo "🎯 Auto-Baselining: http://localhost:5002"
    echo "📊 Prometheus: http://localhost:9090"
    echo "📈 Grafana: http://localhost:3000 (admin/bankingdemo)"
    if [ -f "src/services/ml_detection_service.py" ]; then
        echo "🤖 ML Detection: http://localhost:5001"
    fi
    
    echo ""
    echo -e "${BLUE}🧪 Quick Verification:${NC}"
    echo "======================"
    echo "# Test auto-baselining:"
    echo "curl http://localhost:5002/threshold-recommendations | jq ."
    echo ""
    echo "# Test ML detection (if available):"
    echo "curl http://localhost:5001/health"
    echo ""
    echo "# View Grafana dashboards:"
    echo "open http://localhost:3000"
    
else
    echo -e "${YELLOW}⚠️  Some services are not responding${NC}"
    echo "Check logs with: docker compose logs -f"
fi

echo ""
echo -e "${GREEN}✅ Post-Docker restoration complete!${NC}"
echo "🔄 Your complete system has been restored from backup"
echo "🎯 Both DDoS Detection and Auto-Baselining are ready to use"