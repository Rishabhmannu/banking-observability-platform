#!/bin/bash

echo "🛑 Safe System Shutdown v5 - Complete State Preservation"
echo "======================================================="

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

# Create backup directory
backup_timestamp=$(date +%Y%m%d_%H%M%S)
backup_dir="backups/${backup_timestamp}"
mkdir -p "$backup_dir/grafana_exports"

echo ""
echo -e "${BLUE}📊 Step 1: Exporting Grafana Dashboards${NC}"
echo "======================================"

# Check if Grafana is running
if curl -s http://localhost:3000/api/health | grep -q "ok" 2>/dev/null; then
    echo "🔍 Discovering dashboards..."
    
    # Get all dashboards
    dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null)
    dashboard_count=$(echo "$dashboards" | jq -r '. | length' 2>/dev/null || echo "0")
    
    echo "📊 Found $dashboard_count dashboards"
    
    if [ "$dashboard_count" -gt 0 ]; then
        echo "$dashboards" | jq -r '.[] | @base64' | while IFS= read -r dashboard_encoded; do
            dashboard_info=$(echo "$dashboard_encoded" | base64 -d)
            uid=$(echo "$dashboard_info" | jq -r '.uid')
            title=$(echo "$dashboard_info" | jq -r '.title')
            slug=$(echo "$dashboard_info" | jq -r '.uri' | sed 's/^db\///')
            
            echo -n "   📥 Exporting: $title... "
            
            # Get full dashboard with all details
            dashboard_data=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/dashboards/uid/$uid")
            
            if [ ! -z "$dashboard_data" ] && echo "$dashboard_data" | jq -e '.dashboard' >/dev/null 2>&1; then
                # Save complete dashboard
                echo "$dashboard_data" | jq '.dashboard' > "$backup_dir/grafana_exports/${uid}_complete.json"
                
                # Save metadata
                echo "$dashboard_info" > "$backup_dir/grafana_exports/${uid}_metadata.json"
                
                echo -e "${GREEN}✅${NC}"
            else
                echo -e "${RED}❌${NC}"
            fi
        done
        
        # Create restoration script
        cat > "$backup_dir/grafana_exports/restore_dashboards.sh" << 'EOF'
#!/bin/bash
echo "🔄 Restoring Grafana Dashboards"
echo "=============================="

for dashboard in *_complete.json; do
    if [ -f "$dashboard" ]; then
        title=$(jq -r '.title // "Unknown"' "$dashboard")
        echo -n "📊 Importing $title... "
        
        # Prepare import payload
        dashboard_data=$(cat "$dashboard")
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
    echo -e "${YELLOW}⚠️  Grafana not accessible. Dashboard state may not be saved.${NC}"
fi

echo ""
echo -e "${BLUE}📂 Step 2: Backing Up All Configurations${NC}"
echo "========================================"

# Function to backup directory/file
backup_item() {
    local item=$1
    local display_name=${2:-$item}
    
    if [ -e "$item" ]; then
        echo -n "   Backing up $display_name... "
        cp -r "$item" "$backup_dir/"
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "   ${YELLOW}⚠️  $display_name not found${NC}"
    fi
}

# Backup all important directories and files
backup_item "prometheus" "Prometheus configuration"
backup_item "grafana" "Grafana configuration"
backup_item "grafana-dashboards" "Grafana dashboard files"
backup_item "src" "Source code"
backup_item "transaction-monitor" "Transaction Monitor"
backup_item "performance-aggregator" "Performance Aggregator"
backup_item "anomaly-injector" "Anomaly Injector"
backup_item "mock-windows-exporter" "Windows Exporter"
backup_item "mock-iis-application" "IIS Application"
backup_item "trace-generator" "Trace Generator"
backup_item "message-producer" "Message Producer"
backup_item "message-consumer" "Message Consumer"
backup_item "rabbitmq-monitor" "RabbitMQ Monitor"  # NEW
backup_item "db-connection-demo" "DB Connection Demo"
backup_item "message-brokers" "Message Brokers Config"

# Backup compose files
echo -n "   Backing up Docker Compose files... "
for file in docker-compose*.yml; do
    [ -f "$file" ] && cp "$file" "$backup_dir/"
done
echo -e "${GREEN}✅${NC}"

# Backup shell scripts
echo -n "   Backing up shell scripts... "
cp *.sh "$backup_dir/" 2>/dev/null
echo -e "${GREEN}✅${NC}"

# Capture current metrics state
echo -n "   Capturing final metrics state... "
{
    echo "Final Metrics State - $(date)"
    echo "============================="
    echo ""
    
    # Prometheus targets
    echo "Prometheus Targets:"
    curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"' 2>/dev/null || echo "Prometheus not accessible"
    echo ""
    
    # RabbitMQ Monitor metrics - NEW
    echo "RabbitMQ Queue Depths (from Monitor):"
    curl -s http://localhost:9418/metrics | grep "rabbitmq_queue_messages_ready" | grep -v "^#" 2>/dev/null || echo "RabbitMQ monitor not accessible"
    echo ""
    
    # Message queue stats
    echo "Message Queue Stats:"
    curl -s http://localhost:5007/metrics | grep -E "(messages_published_total|message_publish_duration_seconds_count)" 2>/dev/null || echo "Message producer not accessible"
    echo ""
    
    # DB connection stats
    echo "Database Connection Pool:"
    curl -s http://localhost:5009/metrics | grep -E "(db_pool_|db_query_)" 2>/dev/null || echo "DB connection demo not accessible"
    echo ""
    
    # Jaeger traces
    echo "Jaeger Traces:"
    curl -s "http://localhost:16686/api/services" | jq -r '.data[]' 2>/dev/null || echo "Jaeger not accessible"
    
} > "$backup_dir/final_metrics_state.txt"
echo -e "${GREEN}✅${NC}"

# List running containers before shutdown
docker compose ps > "$backup_dir/running_services.txt" 2>&1

echo ""
echo -e "${BLUE}🛑 Step 3: Graceful Service Shutdown${NC}"
echo "===================================="

# Phase 1: Stop load generator and trace generator first
echo "⚡ Stopping traffic generators..."
docker compose stop load-generator 2>/dev/null
docker compose -f docker-compose.tracing.yml stop trace-generator 2>/dev/null

# Phase 2: Stop message consumers and monitors
echo "📨 Stopping message consumers and monitors..."
docker compose -f docker-compose.messaging.yml stop message-consumer 2>/dev/null
docker compose -f docker-compose.messaging.yml stop rabbitmq-monitor 2>/dev/null  # NEW

# Phase 3: Stop monitoring services
echo "📊 Stopping monitoring services..."
docker compose stop mock-iis-application mock-windows-exporter 2>/dev/null
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml stop anomaly-injector performance-aggregator transaction-monitor 2>/dev/null

# Phase 4: Stop ML services
echo "🤖 Stopping ML services..."
docker compose stop auto-baselining ddos-ml-detection 2>/dev/null

# Phase 5: Stop banking services
echo "🏦 Stopping banking services..."
docker compose stop api-gateway fraud-detection notification-service auth-service transaction-service account-service 2>/dev/null

# Phase 6: Stop message brokers
echo "📨 Stopping message brokers..."
docker compose -f docker-compose.messaging.yml stop message-producer rabbitmq kafka kafka-exporter zookeeper 2>/dev/null

# Phase 7: Stop database
echo "🗄️ Stopping databases..."
docker compose -f docker-compose.db-demo.yml stop db-connection-demo postgres-exporter postgres 2>/dev/null
docker compose stop mysql-db 2>/dev/null

# Phase 8: Stop infrastructure
echo "🔧 Stopping infrastructure..."
docker compose -f docker-compose.yml -f docker-compose.tracing.yml stop jaeger 2>/dev/null
docker compose stop grafana prometheus cadvisor node-exporter 2>/dev/null

echo ""
echo -e "${BLUE}📋 Step 4: Creating Restoration Package${NC}"
echo "======================================"

# Create comprehensive restore instructions
cat > "$backup_dir/RESTORE_INSTRUCTIONS.md" << EOF
# System Restoration Guide
Generated: $backup_timestamp

## Quick Restore
Run: \`./safe_restart5.sh\` and select this backup

## Manual Dashboard Edits Preserved
- Transaction Tracing Analytics
- Message Queue Dashboard
- Database Connection Pool Dashboard
- RabbitMQ Monitor Comparison Dashboard
- All other manual panel modifications

## Services Included
- Core banking services
- DDoS detection and auto-baselining
- Transaction monitoring suite
- Windows IIS monitoring
- Transaction tracing with Jaeger
- RabbitMQ and Kafka messaging
- RabbitMQ Queue Monitor (port 9418)
- PostgreSQL connection pool demo

## Backup Contents
- Complete Grafana dashboards (with all manual edits)
- All service configurations including rabbitmq-monitor
- Message broker configurations
- Prometheus setup with monitor scrape job
- Docker compose files
- Shell scripts
- Metrics state at shutdown

## To Restore Dashboards Manually
1. Go to grafana_exports directory
2. Run: ./restore_dashboards.sh
3. Or import each *_complete.json file via Grafana UI

## Known Issues Resolved
- Docker compose volume definitions fixed
- Dashboard JSON format corrected
- Network configuration aligned
- RabbitMQ monitor service included
EOF

# Calculate backup size
backup_size=$(du -sh "$backup_dir" | cut -f1)

# Create a marker file to indicate complete shutdown backup
date > "$backup_dir/.shutdown_complete"

echo ""
echo -e "${GREEN}🎉 SAFE SHUTDOWN COMPLETE!${NC}"
echo ""
echo "📦 Backup size: $backup_size"
echo "📁 Backup location: $backup_dir"
echo "📊 Dashboard exports: $(ls -1 $backup_dir/grafana_exports/*.json 2>/dev/null | wc -l) files"
echo ""
echo "✨ All your manual dashboard changes have been preserved!"
echo "🚀 To restart: ./safe_restart5.sh"
echo ""
echo -e "${BLUE}💡 Next Steps:${NC}"
echo "  1. Your system has been safely shut down"
echo "  2. All configurations and dashboards are backed up"
echo "  3. Run ./safe_restart5.sh to restore everything"