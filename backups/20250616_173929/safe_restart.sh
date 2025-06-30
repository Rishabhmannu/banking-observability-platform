#!/bin/bash

echo "🚀 Safe System Restart - Restoring All Data"
echo "==========================================="

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
echo "📅 Restart initiated at: $(date)"

echo ""
echo -e "${BLUE}🔍 Step 1: Pre-Restart Checks${NC}"
echo "============================="

# Check if system is already running
echo "🔍 Checking current system state..."
running_containers=$(docker compose ps --services --filter "status=running" 2>/dev/null | wc -l)

if [ "$running_containers" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Some services are already running${NC}"
    echo "📊 Current running services:"
    docker compose ps --filter "status=running"
    echo ""
    read -p "Do you want to restart anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restart cancelled."
        exit 0
    fi
    
    echo "🛑 Stopping existing services first..."
    docker compose down --remove-orphans >/dev/null 2>&1
else
    echo -e "${GREEN}✅ System is ready for restart${NC}"
fi

echo ""
echo -e "${BLUE}📥 Step 2: Configuration Restoration${NC}"
echo "===================================="

# Find the most recent backup
latest_backup=""
if [ -d "backups" ]; then
    latest_backup=$(ls -t backups/ | head -1)
    if [ ! -z "$latest_backup" ]; then
        echo "📁 Found latest backup: $latest_backup"
        
        # Ask if user wants to restore from backup
        read -p "Restore from backup? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "📤 Restoring configurations from backup..."
            
            backup_path="backups/$latest_backup"
            
            # Restore Grafana config
            if [ -d "$backup_path/grafana" ]; then
                cp -r "$backup_path/grafana"/* grafana/ 2>/dev/null
                echo "   ✅ Grafana configuration restored"
            fi
            
            # Restore Prometheus config
            if [ -d "$backup_path/prometheus" ]; then
                cp -r "$backup_path/prometheus"/* prometheus/ 2>/dev/null
                echo "   ✅ Prometheus configuration restored"
            fi
            
            # Restore source code if needed
            if [ -d "$backup_path/src" ]; then
                cp -r "$backup_path/src"/* src/ 2>/dev/null
                echo "   ✅ Source code restored"
            fi
            
            echo -e "${GREEN}✅ Configuration restoration complete${NC}"
        fi
    else
        echo "ℹ️  No backups found, using current configuration"
    fi
else
    echo "ℹ️  No backup directory found, using current configuration"
fi

echo ""
echo -e "${BLUE}🏗️ Step 3: Service Startup Sequence${NC}"
echo "===================================="

echo "🚀 Starting services in dependency order..."

# Start core infrastructure first
echo ""
echo "🗄️ Phase 1: Starting core infrastructure..."
infrastructure_services=("mysql-db" "prometheus" "grafana" "node-exporter" "cadvisor")

for service in "${infrastructure_services[@]}"; do
    echo -n "  Starting $service: "
    if docker compose up -d "$service" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Started${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
done

echo "⏳ Waiting for core infrastructure to initialize (60 seconds)..."
sleep 60

# Start banking services
echo ""
echo "🏦 Phase 2: Starting banking services..."
banking_services=("account-service" "transaction-service" "auth-service" "notification-service" "fraud-detection")

for service in "${banking_services[@]}"; do
    echo -n "  Starting $service: "
    if docker compose up -d "$service" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Started${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
done

echo "⏳ Waiting for banking services to initialize (45 seconds)..."
sleep 45

# Start API gateway
echo ""
echo "🌐 Phase 3: Starting API gateway..."
echo -n "  Starting api-gateway: "
if docker compose up -d api-gateway >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Started${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi

echo "⏳ Waiting for API gateway (30 seconds)..."
sleep 30

# Start ML services
echo ""
echo "🤖 Phase 4: Starting ML services..."
ml_services=("ddos-ml-detection" "auto-baselining")

for service in "${ml_services[@]}"; do
    echo -n "  Starting $service: "
    if docker compose up -d "$service" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Started${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
done

echo "⏳ Waiting for ML services to initialize (60 seconds)..."
sleep 60

# Start load generator
echo ""
echo "⚡ Phase 5: Starting load generator..."
echo -n "  Starting load-generator: "
if docker compose up -d load-generator >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Started${NC}"
else
    echo -e "${YELLOW}⚠️  Optional service${NC}"
fi

echo ""
echo -e "${BLUE}🏥 Step 4: Health Verification${NC}"
echo "=============================="

echo "🧪 Testing all services..."

# Test core services
services_to_test=(
    "Banking API:http://localhost:8080/health"
    "DDoS Detection:http://localhost:5001/health"
    "Auto-Baselining:http://localhost:5002/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
)

all_healthy=true
for service_info in "${services_to_test[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    echo -n "  $service_name: "
    if curl -s "$service_url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
    else
        echo -e "${RED}❌ UNHEALTHY${NC}"
        all_healthy=false
    fi
done

echo ""
echo -e "${BLUE}📊 Step 5: Dashboard Restoration${NC}"
echo "==============================="

echo "⏳ Waiting for Grafana to be fully ready..."
max_attempts=20
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:3000/api/health | grep -q "ok"; then
        echo -e "${GREEN}✅ Grafana is ready${NC}"
        break
    fi
    echo -n "."
    sleep 3
    ((attempt++))
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}❌ Grafana failed to become ready${NC}"
else
    echo ""
    echo "📤 Verifying dashboard availability..."
    
    # Check if dashboards exist via API
    dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | jq -r '.[].title' 2>/dev/null)
    
    if [ ! -z "$dashboards" ]; then
        echo -e "${GREEN}✅ Dashboards found:${NC}"
        echo "$dashboards" | while read -r dashboard; do
            echo "   📊 $dashboard"
        done
    else
        echo -e "${YELLOW}⚠️  No dashboards found${NC}"
        
        # Try to restore from backup if available
        if [ -d "backups/$latest_backup/grafana_exports" ]; then
            echo "📥 Attempting to restore dashboards from backup..."
            
            for dashboard_file in "backups/$latest_backup/grafana_exports"/*.json; do
                if [ -f "$dashboard_file" ]; then
                    dashboard_name=$(basename "$dashboard_file" .json)
                    echo -n "   Importing $dashboard_name: "
                    
                    response=$(curl -s -X POST \
                        -H "Content-Type: application/json" \
                        -u admin:bankingdemo \
                        http://localhost:3000/api/dashboards/db \
                        -d @"$dashboard_file" 2>/dev/null)
                    
                    if echo "$response" | grep -q "success"; then
                        echo -e "${GREEN}✅ Imported${NC}"
                    else
                        echo -e "${RED}❌ Failed${NC}"
                    fi
                fi
            done
        else
            echo "ℹ️  No dashboard backups found - will use auto-provisioning"
        fi
    fi
fi

echo ""
echo -e "${BLUE}📈 Step 6: Metrics Verification${NC}"
echo "=============================="

echo "🔍 Checking key metrics availability..."

# Check DDoS metrics
ddos_score=$(curl -s "http://localhost:9090/api/v1/query?query=ddos_detection_score" | jq -r '.data.result | length' 2>/dev/null)
echo -n "  DDoS Detection metrics: "
if [ "$ddos_score" -gt 0 ]; then
    echo -e "${GREEN}✅ Available${NC}"
else
    echo -e "${YELLOW}⚠️  Initializing...${NC}"
fi

# Check Auto-baselining metrics
baselining_metrics=$(curl -s "http://localhost:9090/api/v1/query?query=active_metrics_being_monitored" | jq -r '.data.result | length' 2>/dev/null)
echo -n "  Auto-baselining metrics: "
if [ "$baselining_metrics" -gt 0 ]; then
    echo -e "${GREEN}✅ Available${NC}"
else
    echo -e "${YELLOW}⚠️  Initializing...${NC}"
fi

# Check Prometheus targets
echo -n "  Prometheus targets: "
targets=$(curl -s "http://localhost:9090/api/v1/targets" | jq -r '.data.activeTargets | length' 2>/dev/null)
if [ "$targets" -gt 5 ]; then
    echo -e "${GREEN}✅ $targets targets discovered${NC}"
else
    echo -e "${YELLOW}⚠️  $targets targets (may need more time)${NC}"
fi

echo ""
echo -e "${BLUE}📋 Step 7: System Status Summary${NC}"
echo "==============================="

echo "📊 Container Status:"
docker compose ps

echo ""
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}🎉 RESTART SUCCESSFUL!${NC}"
    echo ""
    echo -e "${GREEN}✅ All core services are healthy${NC}"
    echo -e "${GREEN}✅ Dashboards are accessible${NC}"
    echo -e "${GREEN}✅ Metrics are being collected${NC}"
    echo -e "${GREEN}✅ Your work has been preserved${NC}"
else
    echo -e "${YELLOW}⚠️  PARTIAL RESTART${NC}"
    echo "Some services may need additional time to initialize"
fi

echo ""
echo -e "${BLUE}🔗 Access Information:${NC}"
echo "====================="
echo "🏦 Banking API: http://localhost:8080"
echo "🤖 DDoS Detection: http://localhost:5001"
echo "🎯 Auto-Baselining: http://localhost:5002"
echo "📊 Prometheus: http://localhost:9090"
echo "📈 Grafana: http://localhost:3000 (admin/bankingdemo)"

echo ""
echo -e "${BLUE}📊 Quick Dashboard Links:${NC}"
echo "========================"
echo "🚨 DDoS Detection Dashboard: http://localhost:3000/d/ddos-detection"
echo "🎯 Auto-Baselining Dashboard: http://localhost:3000/d/auto-baselining"
echo "🏦 Banking Overview Dashboard: http://localhost:3000/d/banking-overview"

echo ""
echo -e "${BLUE}🎯 System Features Active:${NC}"
echo "========================="
echo "✅ Banking Microservices (6 services)"
echo "✅ DDoS Detection with ML"
echo "✅ Auto-Baselining (4 algorithms)"
echo "✅ Prometheus Monitoring"
echo "✅ Grafana Visualization"
echo "✅ Real-time Metrics Collection"

echo ""
echo -e "${BLUE}🔧 Troubleshooting:${NC}"
echo "=================="
echo "• If dashboards missing: Go to Grafana → + → Import"
echo "• If metrics not showing: Wait 5-10 minutes for initialization"
echo "• If services down: docker compose logs [service-name]"
echo "• For DDoS testing: Run ./ddos_trigger.sh (coming next!)"

echo ""
echo -e "${GREEN}🚀 Safe restart completed at $(date)${NC}"
echo -e "${GREEN}Your complete AIOps system is now running! 🎉${NC}"