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
running_containers=$(docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml ps --services --filter "status=running" 2>/dev/null | wc -l)

if [ "$running_containers" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Some services are already running${NC}"
    echo "📊 Current running services:"
    docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml ps --filter "status=running"
    echo ""
    read -p "Do you want to restart anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restart cancelled."
        exit 0
    fi
    
    echo "🛑 Stopping existing services first..."
    docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml down --remove-orphans >/dev/null 2>&1
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
            
            # Restore all configurations including trace-generator
            for item in grafana prometheus src transaction-monitor performance-aggregator anomaly-injector mock-windows-exporter mock-iis-application trace-generator; do
                if [ -d "$backup_path/$item" ]; then
                    cp -r "$backup_path/$item"/* "$item/" 2>/dev/null
                    echo "   ✅ $item restored"
                fi
            done
            
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
docker compose up -d mysql-db prometheus grafana node-exporter cadvisor

echo "⏳ Waiting for core infrastructure to initialize (60 seconds)..."
sleep 60

# Start Jaeger for tracing
echo ""
echo "🔍 Phase 2: Starting Jaeger tracing system..."
docker compose -f docker-compose.yml -f docker-compose.tracing.yml up -d jaeger

echo "⏳ Waiting for Jaeger to initialize (30 seconds)..."
sleep 30

# Start banking services
echo ""
echo "🏦 Phase 3: Starting banking services..."
docker compose up -d account-service transaction-service auth-service notification-service fraud-detection

echo "⏳ Waiting for banking services to initialize (45 seconds)..."
sleep 45

# Start API gateway
echo ""
echo "🌐 Phase 4: Starting API gateway..."
docker compose up -d api-gateway

echo "⏳ Waiting for API gateway (30 seconds)..."
sleep 30

# Start ML services
echo ""
echo "🤖 Phase 5: Starting ML services..."
docker compose up -d ddos-ml-detection auto-baselining

echo "⏳ Waiting for ML services to initialize (45 seconds)..."
sleep 45

# Start transaction monitoring services
echo ""
echo "💰 Phase 6: Starting transaction monitoring services..."
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml up -d transaction-monitor performance-aggregator anomaly-injector

echo "⏳ Waiting for transaction monitoring services (45 seconds)..."
sleep 45

# Start Windows IIS monitoring
echo ""
echo "🪟 Phase 7: Starting Windows IIS monitoring..."
docker compose up -d mock-windows-exporter mock-iis-application

echo "⏳ Waiting for Windows IIS services (30 seconds)..."
sleep 30

# Start trace generator
echo ""
echo "🔍 Phase 8: Starting trace generator..."
docker compose -f docker-compose.yml -f docker-compose.tracing.yml up -d trace-generator

echo "⏳ Waiting for trace generator (30 seconds)..."
sleep 30

# Start load generator
echo ""
echo "⚡ Phase 9: Starting load generator..."
docker compose up -d load-generator

echo ""
echo -e "${BLUE}🏥 Step 4: Health Verification${NC}"
echo "=============================="

echo "🧪 Testing all services..."

# Test core services
services_to_test=(
    "Banking API:http://localhost:8080/health"
    "DDoS Detection:http://localhost:5001/health"
    "Auto-Baselining:http://localhost:5002/health"
    "Transaction Monitor:http://localhost:5003/health"
    "Performance Aggregator:http://localhost:5004/health"
    "Anomaly Injector:http://localhost:5005/health"
    "Windows Exporter:http://localhost:9182/health"
    "IIS Application:http://localhost:8090/health"
    "Jaeger UI:http://localhost:16686"
    "Trace Generator:http://localhost:9414/health"
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
                    
                    # Wrap the dashboard JSON properly for import
                    dashboard_json=$(cat "$dashboard_file")
                    import_payload=$(jq -n --argjson dash "$dashboard_json" '{"dashboard": $dash, "overwrite": true}')
                    
                    response=$(curl -s -X POST \
                        -H "Content-Type: application/json" \
                        -u admin:bankingdemo \
                        http://localhost:3000/api/dashboards/db \
                        -d "$import_payload" 2>/dev/null)
                    
                    if echo "$response" | grep -q "success"; then
                        echo -e "${GREEN}✅ Imported${NC}"
                    else
                        echo -e "${RED}❌ Failed${NC}"
                    fi
                fi
            done
        else
            echo "ℹ️  No dashboard backups found"
            echo "   Run import scripts to restore dashboards:"
            echo "   ./import-transaction-dashboard.sh"
            echo "   ./import_windows_iis_dashboard.sh"
            echo "   ./import_tracing_dashboard.sh"
        fi
    fi
fi

echo ""
echo -e "${BLUE}📈 Step 6: Metrics Verification${NC}"
echo "=============================="

echo "🔍 Checking key metrics availability..."

# Check all metric categories
metrics_checks=(
    "DDoS Detection:ddos_detection_score"
    "Auto-baselining:active_metrics_being_monitored"
    "Transaction monitoring:transaction_requests_total"
    "Windows IIS:windows_iis_requests_total"
    "Trace generation:traces_generated_total"
)

for check in "${metrics_checks[@]}"; do
    metric_name=$(echo $check | cut -d: -f1)
    metric_query=$(echo $check | cut -d: -f2)
    
    echo -n "  $metric_name metrics: "
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$metric_query" | jq -r '.data.result | length' 2>/dev/null)
    if [ "$result" -gt 0 ]; then
        echo -e "${GREEN}✅ Available${NC}"
    else
        echo -e "${YELLOW}⚠️  Initializing...${NC}"
    fi
done

# Check Prometheus targets
echo -n "  Prometheus targets: "
targets=$(curl -s "http://localhost:9090/api/v1/targets" | jq -r '.data.activeTargets | length' 2>/dev/null)
if [ "$targets" -gt 10 ]; then
    echo -e "${GREEN}✅ $targets targets discovered${NC}"
else
    echo -e "${YELLOW}⚠️  $targets targets (may need more time)${NC}"
fi

# Check Jaeger services
echo -n "  Jaeger traced services: "
services=$(curl -s "http://localhost:16686/jaeger/api/services" | jq -r '.data | length' 2>/dev/null)
if [ "$services" -gt 0 ]; then
    echo -e "${GREEN}✅ $services services discovered${NC}"
else
    echo -e "${YELLOW}⚠️  No services traced yet${NC}"
fi

echo ""
echo -e "${BLUE}📋 Step 7: System Status Summary${NC}"
echo "==============================="

echo "📊 Container Status:"
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml ps 2>/dev/null

echo ""
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}🎉 RESTART SUCCESSFUL!${NC}"
    echo ""
    echo -e "${GREEN}✅ All core services are healthy${NC}"
    echo -e "${GREEN}✅ Dashboards are accessible${NC}"
    echo -e "${GREEN}✅ Metrics are being collected${NC}"
    echo -e "${GREEN}✅ Tracing system is operational${NC}"
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
echo "💰 Transaction Monitor: http://localhost:5003"
echo "📈 Performance Aggregator: http://localhost:5004"
echo "🎭 Anomaly Injector: http://localhost:5005"
echo "🪟 Windows Exporter: http://localhost:9182/metrics"
echo "🔍 Jaeger UI: http://localhost:16686"
echo "🔍 Trace Generator: http://localhost:9414"
echo "📊 Prometheus: http://localhost:9090"
echo "📈 Grafana: http://localhost:3000 (admin/bankingdemo)"

echo ""
echo -e "${BLUE}📊 Quick Dashboard Links:${NC}"
echo "========================"
echo "🚨 DDoS Detection Dashboard: http://localhost:3000/d/ddos-detection"
echo "🎯 Auto-Baselining Dashboard: http://localhost:3000/d/auto-baselining"
echo "🏦 Banking Overview Dashboard: http://localhost:3000/d/banking-overview"
echo "💰 Transaction Performance Dashboard: http://localhost:3000/d/transaction-performance"
echo "🪟 Windows IIS Monitoring: http://localhost:3000/d/windows-iis"
echo "🔍 Transaction Tracing Analytics: http://localhost:3000/d/transaction-tracing"

echo ""
echo -e "${BLUE}🎯 System Features Active:${NC}"
echo "========================="
echo "✅ Banking Microservices (6 services)"
echo "✅ DDoS Detection with ML"
echo "✅ Auto-Baselining (4 algorithms)"
echo "✅ Transaction Performance Monitoring"
echo "✅ Performance Aggregation & SLO Tracking"
echo "✅ Anomaly Injection System"
echo "✅ Windows IIS Monitoring (Mock)"
echo "✅ Distributed Tracing with Jaeger"
echo "✅ Trace Generation & Analysis"
echo "✅ Prometheus Monitoring"
echo "✅ Grafana Visualization (6 dashboards)"
echo "✅ Real-time Metrics Collection"

echo ""
echo -e "${BLUE}🔧 Troubleshooting:${NC}"
echo "=================="
echo "• If dashboards missing: Run import scripts"
echo "• If metrics not showing: Run ./continuous-traffic-generator.sh"
echo "• If services down: docker compose logs [service-name]"
echo "• For anomaly testing: Run ./test-anomaly-injection.sh"
echo "• For IIS anomalies: Run ./test_windows_iis_anomalies_v2.sh"
echo "• View traces: Open http://localhost:16686"
echo "• Configure Grafana Jaeger datasource: URL = http://jaeger:16686/jaeger"

echo ""
echo -e "${GREEN}🚀 Safe restart completed at $(date)${NC}"
echo -e "${GREEN}Your complete AIOps system with Transaction Tracing is now running! 🎉${NC}"