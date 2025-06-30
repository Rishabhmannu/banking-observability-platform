#!/bin/bash

echo "💾 Save Backup v3 - Create Full System Backup (No Shutdown)"
echo "=========================================================="

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
echo "📅 Backup initiated at: $(date)"

# Create backup directory with timestamp
backup_timestamp=$(date +%Y%m%d_%H%M%S)
backup_dir="backups/$backup_timestamp"
mkdir -p "$backup_dir"

echo ""
echo -e "${BLUE}📥 Step 1: System Status Check${NC}"
echo "=============================="

# Check if system is running
running_containers=$(docker compose ps --services --filter "status=running" 2>/dev/null | wc -l)
if [ "$running_containers" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No services are running. Backup will include current files only.${NC}"
else
    echo -e "${GREEN}✅ Found $running_containers running services${NC}"
fi

echo ""
echo -e "${BLUE}📊 Step 2: Backing Up Grafana Dashboards${NC}"
echo "======================================="

# Export all Grafana dashboards if Grafana is running
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo "💾 Exporting all Grafana dashboards..."
    echo "   This preserves your manual edits!"
    
    # Get all dashboards
    dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null)
    
    if [ ! -z "$dashboards" ]; then
        mkdir -p "$backup_dir/grafana_exports"
        
        dashboard_count=0
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
                
                ((dashboard_count++))
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
            -H "Accept: application/json" \
            -u admin:bankingdemo \
            -d "$import_payload" \
            http://localhost:3000/api/dashboards/import)
        
        if echo "$response" | grep -q "success"; then
            echo "✅"
        else
            echo "❌"
            echo "Error: $response"
        fi
    fi
done
echo "✅ Dashboard restoration complete!"
EOF
        chmod +x "$backup_dir/grafana_exports/restore_dashboards.sh"
        
        echo -e "${GREEN}✅ Exported all dashboards successfully${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Grafana not accessible. Skipping dashboard export.${NC}"
fi

echo ""
echo -e "${BLUE}📁 Step 3: Backing Up Configuration Files${NC}"
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
backup_item "scripts" "Shell scripts"  # Include scripts directory

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

echo ""
echo -e "${BLUE}📈 Step 4: Capturing Current Metrics State${NC}"
echo "========================================="

# Capture current metrics state if services are running
if [ "$running_containers" -gt 0 ]; then
    echo -n "   Capturing metrics state... "
    {
        echo "Metrics State Snapshot - $(date)"
        echo "================================"
        echo ""
        
        # Prometheus targets
        echo "Prometheus Targets:"
        curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"' 2>/dev/null || echo "Prometheus not accessible"
        echo ""
        
        # RabbitMQ Monitor metrics - NEW
        echo "RabbitMQ Queue Monitor Status:"
        curl -s http://localhost:9418/health 2>/dev/null | jq '.' || echo "RabbitMQ monitor not accessible"
        echo ""
        
        echo "RabbitMQ Queue Depths (from Monitor):"
        curl -s http://localhost:9418/metrics | grep "rabbitmq_queue_messages_ready" | grep -v "^#" 2>/dev/null || echo "No queue metrics available"
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
        
    } > "$backup_dir/live_metrics_snapshot.txt"
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  No running services to capture metrics from${NC}"
fi

# List running containers
if [ "$running_containers" -gt 0 ]; then
    echo -n "   Listing running services... "
    docker compose ps > "$backup_dir/running_services.txt" 2>&1
    echo -e "${GREEN}✅${NC}"
fi

echo ""
echo -e "${BLUE}📋 Step 5: Creating Backup Documentation${NC}"
echo "========================================"

# Create comprehensive restore instructions
cat > "$backup_dir/RESTORE_INSTRUCTIONS.md" << EOF
# System Backup - $backup_timestamp
Generated while system was $([ "$running_containers" -gt 0 ] && echo "RUNNING" || echo "STOPPED")

## Quick Restore
Run: \`./safe_restart5.sh\` and select this backup when prompted

## Backup Contents
- Complete Grafana dashboards (including all manual edits)
- All service configurations including RabbitMQ Monitor
- Message broker configurations  
- Prometheus setup with monitor scrape job
- Docker compose files
- Shell scripts including message-queue-tester-v2.sh
$([ "$running_containers" -gt 0 ] && echo "- Live metrics snapshot with queue depths")
$([ "$running_containers" -gt 0 ] && echo "- Running services list")

## Manual Dashboard Restoration
If dashboards need to be restored manually:
1. Navigate to grafana_exports directory
2. Run: ./restore_dashboards.sh
3. Or import each *_complete.json file via Grafana UI

## Services Included in Backup
- Core banking services
- DDoS detection and auto-baselining
- Transaction monitoring suite
- Windows IIS monitoring
- Transaction tracing with Jaeger
- RabbitMQ and Kafka messaging
- RabbitMQ Queue Monitor (port 9418)
- PostgreSQL connection pool demo

## RabbitMQ Monitor Details
- Service: rabbitmq-monitor
- Port: 9418
- Monitored Queues:
  - transaction_processing_q
  - notification_dispatch_q
  - fraud_check_q
  - auth_token_q
  - core_banking_updates_q

## To Use This Backup
1. Run: ./safe_restart5.sh
2. When prompted for backup selection, choose: $backup_timestamp
3. The system will restore all configurations and dashboards

## Notes
- This backup was created without stopping the system
- All dashboard edits and configurations are preserved
- The backup can be used to restore the system to this exact state
- RabbitMQ Monitor configuration is included for queue visibility
EOF

# Calculate backup size
backup_size=$(du -sh "$backup_dir" | cut -f1)

# Create a marker file to indicate this is a valid backup
date > "$backup_dir/.backup_complete"

echo ""
echo -e "${GREEN}🎉 BACKUP COMPLETE!${NC}"
echo ""
echo "📦 Backup size: $backup_size"
echo "📁 Backup location: $backup_dir"
echo "📊 Dashboard exports: $(ls -1 $backup_dir/grafana_exports/*.json 2>/dev/null | wc -l) files"
echo "🏃 System status: $([ "$running_containers" -gt 0 ] && echo "Running ($running_containers services)" || echo "Stopped")"
echo ""
echo "✨ Your backup has been created successfully!"
echo "🔄 To restore from this backup: ./safe_restart5.sh"
echo ""
echo -e "${BLUE}💡 Tip:${NC} This backup can be used to:"
echo "  • Restore after system issues"
echo "  • Replicate your setup on another machine"
echo "  • Create a checkpoint before major changes"
echo "  • Preserve RabbitMQ Monitor configuration"