#!/bin/bash

echo "🛑 Safe System Shutdown with Complete Backup"
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
echo "📅 Shutdown initiated at: $(date)"

# Create backup directory with timestamp
backup_timestamp=$(date +%Y%m%d_%H%M%S)
backup_dir="backups/$backup_timestamp"
mkdir -p "$backup_dir"

echo ""
echo -e "${BLUE}📥 Step 1: Creating Complete System Backup${NC}"
echo "=========================================="

# Backup Grafana dashboards via API
echo "📊 Backing up Grafana dashboards..."
mkdir -p "$backup_dir/grafana_exports"

if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null)
    
    if [ ! -z "$dashboards" ]; then
        echo "$dashboards" | jq -r '.[] | .uid + ":" + .title' | while IFS=: read -r uid title; do
            echo -n "   Exporting $title... "
            dashboard_json=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/dashboards/uid/$uid" 2>/dev/null)
            
            if [ ! -z "$dashboard_json" ]; then
                echo "$dashboard_json" | jq '.dashboard' > "$backup_dir/grafana_exports/${title// /_}.json"
                echo -e "${GREEN}✅${NC}"
            else
                echo -e "${RED}❌${NC}"
            fi
        done
    fi
else
    echo -e "${YELLOW}⚠️  Grafana not accessible for backup${NC}"
fi

# Backup configurations
echo ""
echo "📁 Backing up configurations..."

# Prometheus config
if [ -d "prometheus" ]; then
    cp -r prometheus "$backup_dir/"
    echo "   ✅ Prometheus configuration backed up"
fi

# Grafana provisioning
if [ -d "grafana" ]; then
    cp -r grafana "$backup_dir/"
    echo "   ✅ Grafana provisioning backed up"
fi

# Source code
if [ -d "src" ]; then
    cp -r src "$backup_dir/"
    echo "   ✅ Source code backed up"
fi

# Transaction monitoring services
for service in transaction-monitor performance-aggregator anomaly-injector; do
    if [ -d "$service" ]; then
        cp -r "$service" "$backup_dir/"
        echo "   ✅ $service backed up"
    fi
done

# Windows IIS monitoring services
for service in mock-windows-exporter mock-iis-application; do
    if [ -d "$service" ]; then
        cp -r "$service" "$backup_dir/"
        echo "   ✅ $service backed up"
    fi
done

# Trace generator service
if [ -d "trace-generator" ]; then
    cp -r trace-generator "$backup_dir/"
    echo "   ✅ trace-generator backed up"
fi

# Docker compose files
cp docker-compose*.yml "$backup_dir/" 2>/dev/null
echo "   ✅ Docker compose files backed up"

# Import scripts
cp *.sh "$backup_dir/" 2>/dev/null
echo "   ✅ Shell scripts backed up"

echo ""
echo -e "${BLUE}📊 Step 2: Collecting Metrics Summary${NC}"
echo "===================================="

# Collect final metrics
echo "📈 Collecting final system metrics..."
metrics_summary="$backup_dir/metrics_summary.txt"

{
    echo "Final Metrics Summary - $(date)"
    echo "=================================="
    echo ""
    
    # DDoS Detection metrics
    echo "🤖 DDoS Detection Status:"
    curl -s "http://localhost:9090/api/v1/query?query=ddos_detection_score" 2>/dev/null | \
        jq -r '.data.result[] | "   Score: " + .value[1]' 2>/dev/null || echo "   No data"
    
    # Auto-baselining metrics
    echo ""
    echo "🎯 Auto-Baselining Status:"
    curl -s http://localhost:5002/health 2>/dev/null | \
        jq -r '"   Recommendations: " + (.recommendations_count // 0 | tostring)' 2>/dev/null || echo "   No data"
    
    # Transaction monitoring
    echo ""
    echo "💰 Transaction Monitoring:"
    curl -s http://localhost:5003/stats 2>/dev/null | \
        jq -r '"   Total transactions: " + (.total_count // 0 | tostring)' 2>/dev/null || echo "   No data"
    
    # Windows IIS metrics
    echo ""
    echo "🪟 Windows IIS Monitoring:"
    req_rate=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(windows_iis_requests_total[5m]))*60" | \
        jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
    echo "   Request rate: $req_rate req/min"
    
    success_rate=$(curl -s "http://localhost:9090/api/v1/query?query=((sum(rate(windows_iis_requests_total[5m]))-sum(rate(windows_iis_server_errors_total[5m]))-sum(rate(windows_iis_client_errors_total[5m])))/sum(rate(windows_iis_requests_total[5m])))*100" | \
        jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
    echo "   Success rate: $success_rate%"
    
    # Tracing metrics
    echo ""
    echo "🔍 Transaction Tracing:"
    traces_generated=$(curl -s http://localhost:9414/metrics 2>/dev/null | grep -E "traces_generated_total{" | awk '{sum += $NF} END {print sum}')
    echo "   Total traces generated: ${traces_generated:-0}"
    
    services_traced=$(curl -s http://localhost:16686/jaeger/api/services 2>/dev/null | jq -r '.data | length' 2>/dev/null || echo "0")
    echo "   Services being traced: $services_traced"
    
} > "$metrics_summary"

echo "   ✅ Metrics summary saved"

echo ""
echo -e "${BLUE}🐳 Step 3: Graceful Service Shutdown${NC}"
echo "===================================="

# Get list of running containers before shutdown
running_before=$(docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml ps --services --filter "status=running" 2>/dev/null)
echo "$running_before" > "$backup_dir/running_services.txt"

echo "🛑 Stopping services in reverse dependency order..."

# Stop trace generator first
echo ""
echo "🔍 Phase 1: Stopping trace generator..."
docker compose -f docker-compose.yml -f docker-compose.tracing.yml stop trace-generator 2>/dev/null

# Stop Windows IIS monitoring
echo ""
echo "🪟 Phase 2: Stopping Windows IIS monitoring..."
docker compose stop mock-iis-application mock-windows-exporter 2>/dev/null

# Stop load generator
echo ""
echo "⚡ Phase 3: Stopping load generator..."
docker compose stop load-generator 2>/dev/null

# Stop transaction monitoring
echo ""
echo "💰 Phase 4: Stopping transaction monitoring services..."
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml stop anomaly-injector performance-aggregator transaction-monitor 2>/dev/null

# Stop ML services
echo ""
echo "🤖 Phase 5: Stopping ML services..."
docker compose stop auto-baselining ddos-ml-detection 2>/dev/null

# Stop API gateway
echo ""
echo "🌐 Phase 6: Stopping API gateway..."
docker compose stop api-gateway 2>/dev/null

# Stop banking services
echo ""
echo "🏦 Phase 7: Stopping banking services..."
docker compose stop fraud-detection notification-service auth-service transaction-service account-service 2>/dev/null

# Stop Jaeger
echo ""
echo "🔍 Phase 8: Stopping Jaeger..."
docker compose -f docker-compose.yml -f docker-compose.tracing.yml stop jaeger 2>/dev/null

# Stop monitoring stack
echo ""
echo "📊 Phase 9: Stopping monitoring stack..."
docker compose stop grafana prometheus cadvisor node-exporter 2>/dev/null

# Stop database last
echo ""
echo "🗄️ Phase 10: Stopping database..."
docker compose stop mysql-db 2>/dev/null

echo ""
echo -e "${BLUE}📋 Step 4: Backup Verification${NC}"
echo "=============================="

# Calculate backup size
backup_size=$(du -sh "$backup_dir" | cut -f1)
echo "📦 Backup size: $backup_size"
echo "📁 Backup location: $backup_dir"

# List backup contents
echo ""
echo "📋 Backup contents:"
ls -la "$backup_dir" | grep -E "^d" | awk '{print "   📁 " $9}'
ls -la "$backup_dir" | grep -E "^-" | awk '{print "   📄 " $9}'

# Create restore instructions
cat > "$backup_dir/RESTORE_INSTRUCTIONS.txt" << EOF
System Backup - $backup_timestamp
=================================

To restore this backup:
1. Run: ./safe_restart3.sh
2. When prompted, choose to restore from backup
3. Select this backup: $backup_timestamp

Backup includes:
- All Grafana dashboards (including Transaction Tracing)
- Prometheus configuration
- Service configurations
- Transaction monitoring setup
- Windows IIS monitoring setup
- Trace generator configuration
- Source code
- Shell scripts

Services running at shutdown:
$(echo "$running_before" | sed 's/^/  - /')

Final metrics summary available in: metrics_summary.txt
EOF

echo ""
echo -e "${BLUE}🏁 Step 5: Final Status${NC}"
echo "======================"

# Check all containers are stopped
remaining=$(docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml ps --services --filter "status=running" 2>/dev/null | wc -l)

if [ "$remaining" -eq 0 ]; then
    echo -e "${GREEN}✅ All services successfully stopped${NC}"
    echo -e "${GREEN}✅ Complete backup created${NC}"
    echo -e "${GREEN}✅ System ready for safe restart${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: $remaining services may still be running${NC}"
    docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml ps --filter "status=running"
fi

echo ""
echo -e "${GREEN}🎉 SAFE SHUTDOWN COMPLETE!${NC}"
echo ""
echo "📦 Backup saved to: $backup_dir"
echo "📊 To view metrics summary: cat $backup_dir/metrics_summary.txt"
echo "🚀 To restart: ./safe_restart3.sh"
echo ""
echo "✨ Shutdown completed at $(date)"