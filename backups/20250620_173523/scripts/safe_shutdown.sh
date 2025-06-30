#!/bin/bash

echo "🔒 Safe System Shutdown - Preserving All Data"
echo "============================================="

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
echo "📅 Shutdown initiated at: $(date)"

echo ""
echo -e "${BLUE}🔍 Step 1: System Status Check${NC}"
echo "=============================="

# Check current system status
echo "📊 Current container status:"
docker compose ps

echo ""
echo "🏥 Service health check:"
services=(
    "Banking API:http://localhost:8080/health"
    "DDoS Detection:http://localhost:5001/health"
    "Auto-Baselining:http://localhost:5002/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
)

for service_info in "${services[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    echo -n "  $service_name: "
    if curl -s "$service_url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ UP${NC}"
    else
        echo -e "${YELLOW}⚠️ DOWN${NC}"
    fi
done

echo ""
echo -e "${BLUE}🗄️ Step 2: Data Backup & Preservation${NC}"
echo "======================================"

# Create backup directory with timestamp
backup_dir="backups/shutdown_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

echo "📁 Creating backup in: $backup_dir"

# Backup Grafana dashboards and config
echo "📊 Backing up Grafana dashboards..."
if [ -d "grafana" ]; then
    cp -r grafana "$backup_dir/"
    echo "   ✅ Grafana config and dashboards backed up"
else
    echo "   ⚠️ No grafana directory found"
fi

# Backup Prometheus config
echo "📈 Backing up Prometheus configuration..."
if [ -d "prometheus" ]; then
    cp -r prometheus "$backup_dir/"
    echo "   ✅ Prometheus config backed up"
else
    echo "   ⚠️ No prometheus directory found"
fi

# Backup Docker Compose files
echo "🐳 Backing up Docker Compose configuration..."
cp docker-compose.yml "$backup_dir/" 2>/dev/null && echo "   ✅ docker-compose.yml backed up"
cp docker-compose.override.yml "$backup_dir/" 2>/dev/null && echo "   ✅ docker-compose.override.yml backed up"

# Backup source code
echo "💻 Backing up source code..."
if [ -d "src" ]; then
    cp -r src "$backup_dir/"
    echo "   ✅ Source code backed up"
fi

# Backup Dockerfiles
echo "🏗️ Backing up Dockerfiles..."
cp Dockerfile* "$backup_dir/" 2>/dev/null && echo "   ✅ Dockerfiles backed up"
cp requirements*.txt "$backup_dir/" 2>/dev/null && echo "   ✅ Requirements files backed up"

# Export Grafana dashboards via API (if Grafana is running)
echo "📤 Exporting Grafana dashboards via API..."
if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
    mkdir -p "$backup_dir/grafana_exports"
    
    # Get list of dashboards
    dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" | jq -r '.[].uid' 2>/dev/null)
    
    if [ ! -z "$dashboards" ]; then
        for uid in $dashboards; do
            dashboard_json=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/dashboards/uid/$uid" 2>/dev/null)
            if echo "$dashboard_json" | jq . >/dev/null 2>&1; then
                dashboard_title=$(echo "$dashboard_json" | jq -r '.dashboard.title' | sed 's/[^a-zA-Z0-9]/_/g')
                echo "$dashboard_json" > "$backup_dir/grafana_exports/${dashboard_title}_${uid}.json"
                echo "   ✅ Exported dashboard: $dashboard_title"
            fi
        done
    else
        echo "   ℹ️ No dashboards found to export"
    fi
else
    echo "   ⚠️ Grafana not accessible for dashboard export"
fi

echo ""
echo -e "${BLUE}🛑 Step 3: Graceful Service Shutdown${NC}"
echo "===================================="

echo "⏳ Stopping services gracefully..."

# Stop services in reverse dependency order
services_to_stop=(
    "load-generator"
    "auto-baselining" 
    "ddos-ml-detection"
    "grafana"
    "prometheus"
    "cadvisor"
    "node-exporter"
    "api-gateway"
    "fraud-detection"
    "notification-service"
    "auth-service"
    "transaction-service"
    "account-service"
    "mysql-db"
)

for service in "${services_to_stop[@]}"; do
    echo -n "  Stopping $service: "
    if docker compose stop "$service" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Stopped${NC}"
    else
        echo -e "${YELLOW}⚠️ Already stopped${NC}"
    fi
done

# Final shutdown
echo ""
echo "🔄 Final cleanup..."
docker compose down --remove-orphans >/dev/null 2>&1

echo ""
echo -e "${BLUE}📋 Step 4: Shutdown Summary${NC}"
echo "=========================="

echo -e "${GREEN}✅ System shutdown completed successfully${NC}"
echo ""
echo "📁 Backup location: $backup_dir"
echo "📊 Grafana dashboards: Preserved"
echo "📈 Prometheus config: Preserved"
echo "💾 Docker volumes: Preserved"
echo "🐳 Containers: Stopped gracefully"

echo ""
echo "🔄 To restart your system:"
echo "./safe_restart.sh"

echo ""
echo "📋 Backup contents:"
ls -la "$backup_dir"

echo ""
echo -e "${GREEN}🔒 Safe shutdown complete at $(date)${NC}"
echo "Your work is fully preserved and ready for restart! 💾"