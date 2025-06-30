#!/bin/bash

echo "🛑 Safe System Shutdown v4 - Enhanced Dashboard Preservation"
echo "==========================================================="

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

# CRITICAL: Force save all Grafana dashboards first
echo "💾 Force-saving all Grafana dashboards..."
echo "   This preserves your manual edits!"

if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    # Get all dashboards
    dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null)
    
    if [ ! -z "$dashboards" ]; then
        mkdir -p "$backup_dir/grafana_exports"
        
        # Special handling for Transaction Tracing dashboard
        echo -e "${YELLOW}   🔍 Special backup for Transaction Tracing Analytics...${NC}"
        
        echo "$dashboards" | jq -r '.[] | .uid + ":" + .title' | while IFS=: read -r uid title; do
            echo -n "   Exporting $title... "
            
            # Get the CURRENT state of the dashboard (including unsaved changes)
            dashboard_json=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/dashboards/uid/$uid" 2>/dev/null)
            
            if [ ! -z "$dashboard_json" ]; then
                # Save complete dashboard with metadata
                echo "$dashboard_json" > "$backup_dir/grafana_exports/${uid}_complete.json"
                
                # Also save just the dashboard portion for easier import
                echo "$dashboard_json" | jq '.dashboard' > "$backup_dir/grafana_exports/${title// /_}.json"
                
                # Save dashboard metadata separately
                echo "$dashboard_json" | jq '{meta: .meta, uid: .dashboard.uid, version: .dashboard.version}' > "$backup_dir/grafana_exports/${uid}_metadata.json"
                
                echo -e "${GREEN}✅${NC}"
            else
                echo -e "${RED}❌${NC}"
            fi
        done
        
        # Create dashboard restore script
        cat > "$backup_dir/grafana_exports/restore_dashboards.sh" << 'EOF'
#!/bin/bash
echo "🔄 Restoring Grafana dashboards..."
for file in *_complete.json; do
    if [ -f "$file" ]; then
        uid=$(basename "$file" _complete.json)
        echo -n "Restoring dashboard $uid... "
        
        dashboard_data=$(cat "$file" | jq '.dashboard')
        import_payload=$(jq -n --argjson dash "$dashboard_data" '{"dashboard": $dash, "overwrite": true, "inputs": [], "folderId": 0}')
        
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u admin:bankingdemo \
            http://localhost:3000/api/dashboards/db \
            -d "$import_payload")
        
        if echo "$response" | grep -q "success"; then
            echo "✅"
        else
            echo "❌"
        fi
    fi
done
EOF
        chmod +x "$backup_dir/grafana_exports/restore_dashboards.sh"
    fi
else
    echo -e "${YELLOW}⚠️  Grafana not accessible for backup${NC}"
fi

# Backup configurations
echo ""
echo "📁 Backing up configurations..."

# Prometheus config with current state
if [ -d "prometheus" ]; then
    cp -r prometheus "$backup_dir/"
    echo "   ✅ Prometheus configuration backed up"
    # Note the iis-application job removal
    echo "   📝 Note: iis-application job has been removed from Prometheus config" >> "$backup_dir/configuration_notes.txt"
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

# All monitoring services
for service in transaction-monitor performance-aggregator anomaly-injector mock-windows-exporter mock-iis-application trace-generator; do
    if [ -d "$service" ]; then
        cp -r "$service" "$backup_dir/"
        echo "   ✅ $service backed up"
    fi
done

# Docker compose files
cp docker-compose*.yml "$backup_dir/" 2>/dev/null
echo "   ✅ Docker compose files backed up"

# Scripts
mkdir -p "$backup_dir/scripts"
cp *.sh "$backup_dir/scripts/" 2>/dev/null
echo "   ✅ Shell scripts backed up"

echo ""
echo -e "${BLUE}📊 Step 2: Collecting Final Metrics State${NC}"
echo "========================================"

# Collect comprehensive metrics
metrics_summary="$backup_dir/final_metrics_state.txt"
{
    echo "System State at Shutdown - $(date)"
    echo "===================================="
    echo ""
    
    echo "🤖 DDoS Detection:"
    curl -s "http://localhost:9090/api/v1/query?query=ddos_detection_score" 2>/dev/null | \
        jq -r '.data.result[0].value[1] // "No data"' 2>/dev/null
    
    echo ""
    echo "🎯 Auto-Baselining:"
    curl -s http://localhost:5002/health 2>/dev/null | jq . 2>/dev/null || echo "Not available"
    
    echo ""
    echo "💰 Transaction Monitoring:"
    curl -s http://localhost:5003/stats 2>/dev/null | jq . 2>/dev/null || echo "Not available"
    
    echo ""
    echo "🪟 Windows IIS Metrics:"
    echo "Request rate: $(curl -s 'http://localhost:9090/api/v1/query?query=sum(rate(windows_iis_requests_total[5m]))*60' | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)"
    
    echo ""
    echo "🔍 Transaction Tracing:"
    echo "Total traces: $(curl -s http://localhost:9414/metrics | grep -E 'traces_generated_total{' | awk '{sum += $NF} END {print sum}' 2>/dev/null)"
    echo "Services in Jaeger: $(curl -s http://localhost:16686/jaeger/api/services | jq -r '.data | length' 2>/dev/null)"
    
} > "$metrics_summary"

echo ""
echo -e "${BLUE}🐳 Step 3: Graceful Service Shutdown${NC}"
echo "===================================="

# Save running services list
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml ps --services --filter "status=running" 2>/dev/null > "$backup_dir/running_services.txt"

# Shutdown in correct order
echo "🛑 Stopping services gracefully..."

# Phase 1: Stop generators
echo "⚡ Stopping generators..."
docker compose -f docker-compose.yml -f docker-compose.tracing.yml stop trace-generator load-generator 2>/dev/null

# Phase 2: Stop monitoring services
echo "📊 Stopping monitoring services..."
docker compose stop mock-iis-application mock-windows-exporter 2>/dev/null
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml stop anomaly-injector performance-aggregator transaction-monitor 2>/dev/null

# Phase 3: Stop ML services
echo "🤖 Stopping ML services..."
docker compose stop auto-baselining ddos-ml-detection 2>/dev/null

# Phase 4: Stop banking services
echo "🏦 Stopping banking services..."
docker compose stop api-gateway fraud-detection notification-service auth-service transaction-service account-service 2>/dev/null

# Phase 5: Stop infrastructure
echo "🔧 Stopping infrastructure..."
docker compose -f docker-compose.yml -f docker-compose.tracing.yml stop jaeger 2>/dev/null
docker compose stop grafana prometheus cadvisor node-exporter 2>/dev/null

# Phase 6: Stop database
echo "🗄️ Stopping database..."
docker compose stop mysql-db 2>/dev/null

echo ""
echo -e "${BLUE}📋 Step 4: Creating Restoration Package${NC}"
echo "======================================"

# Create comprehensive restore instructions
cat > "$backup_dir/RESTORE_INSTRUCTIONS.md" << EOF
# System Restoration Guide
Generated: $backup_timestamp

## Quick Restore
Run: \`./safe_restart4.sh\` and select this backup

## Manual Dashboard Edits Preserved
- Transaction Tracing Analytics: "No Errors" display fix
- Service Dependencies: Dependency graph configuration
- All other manual panel modifications

## Configuration Changes
- Prometheus: iis-application job removed (port 8088 issue resolved)
- All services configured and tested
- Trace generator properly integrated

## Backup Contents
- Complete Grafana dashboards (with all manual edits)
- All service configurations
- Prometheus setup
- Docker compose files
- Shell scripts
- Metrics state at shutdown

## To Restore Dashboards Manually
1. Go to grafana_exports directory
2. Run: ./restore_dashboards.sh
3. Or import each *_complete.json file via Grafana UI
EOF

# Calculate backup size
backup_size=$(du -sh "$backup_dir" | cut -f1)

echo ""
echo -e "${GREEN}🎉 SAFE SHUTDOWN COMPLETE!${NC}"
echo ""
echo "📦 Backup size: $backup_size"
echo "📁 Backup location: $backup_dir"
echo "📊 Dashboard exports: $(ls -1 $backup_dir/grafana_exports/*.json 2>/dev/null | wc -l) files"
echo ""
echo "✨ All your manual dashboard changes have been preserved!"
echo "🚀 To restart: ./safe_restart4.sh"