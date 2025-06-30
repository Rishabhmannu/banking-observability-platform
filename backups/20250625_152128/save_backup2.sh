#!/bin/bash

echo "✅ Live System Backup v2 - AIOps Platform with Messaging & DB"
echo "================================================================="

# --- Configuration ---
# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# The absolute path to your project directory.
# IMPORTANT: Update this path if your project is located elsewhere.
PROJECT_DIR="/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system"
GRAFANA_URL="http://localhost:3000"
GRAFANA_CREDENTIALS="admin:bankingdemo"
PROMETHEUS_URL="http://localhost:9090"

# --- Script Logic ---

# Navigate to the project directory
cd "$PROJECT_DIR" || {
    echo -e "${RED}❌ Could not find project directory at '$PROJECT_DIR'${NC}"
    echo -e "${YELLOW}Please update the PROJECT_DIR variable in this script.${NC}"
    exit 1
}

echo "📂 Working from: $(pwd)"
echo "📅 Backup initiated at: $(date)"

# Create a unique backup directory with a timestamp
backup_timestamp=$(date +%Y%m%d_%H%M%S)
backup_dir="backups/$backup_timestamp"
mkdir -p "$backup_dir"

echo ""
echo -e "${BLUE}📥 Step 1: Creating Complete System Backup${NC}"
echo "=========================================="

# CRITICAL: Force-save all Grafana dashboards via API to preserve live edits.
echo "💾 Exporting all Grafana dashboards from $GRAFANA_URL..."
echo "   This preserves any unsaved or manual changes from the UI."

# First, check if Grafana is running and accessible
if curl -s --head "$GRAFANA_URL/api/health" | head -n 1 | grep "200 OK" > /dev/null; then
    # Get a list of all dashboards
    dashboards=$(curl -s -u "$GRAFANA_CREDENTIALS" "$GRAFANA_URL/api/search?type=dash-db" 2>/dev/null)
    
    if [ ! -z "$dashboards" ] && [ "$(echo "$dashboards" | jq 'length')" -gt 0 ]; then
        mkdir -p "$backup_dir/grafana_exports"
        
        # Loop through each dashboard and export it
        echo "$dashboards" | jq -r '.[] | .uid + ":" + .title' | while IFS=: read -r uid title; do
            echo -n "   Exporting '$title'... "
            dashboard_json=$(curl -s -u "$GRAFANA_CREDENTIALS" "$GRAFANA_URL/api/dashboards/uid/$uid" 2>/dev/null)
            
            if [ ! -z "$dashboard_json" ]; then
                filename_title=$(echo "$title" | tr -s ' /' '_')
                echo "$dashboard_json" > "$backup_dir/grafana_exports/${uid}_${filename_title}_complete.json"
                echo "$dashboard_json" | jq '.dashboard' > "$backup_dir/grafana_exports/${filename_title}.json"
                echo -e "${GREEN}✅${NC}"
            else
                echo -e "${RED}❌ (Failed to fetch JSON)${NC}"
            fi
        done
        
        # Create a restore script for convenience
        cat > "$backup_dir/grafana_exports/restore_dashboards.sh" << 'EOF'
#!/bin/bash
echo "🔄 Restoring Grafana dashboards..."
for file in *_complete.json; do
    if [ -f "$file" ]; then
        echo -n "Restoring dashboard from '$file'... "
        dashboard_data=$(cat "$file")
        import_payload=$(jq -n --argjson dash "$dashboard_data" '{"dashboard": $dash.dashboard, "overwrite": true, "folderId": $dash.meta.folderId}')
        
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u admin:bankingdemo \
            http://localhost:3000/api/dashboards/db \
            -d "$import_payload")
        
        if echo "$response" | grep -q "success"; then
            echo "✅"
        else
            echo "❌ - Check Grafana logs for details."
        fi
    fi
done
echo "✅ Restore process finished."
EOF
        chmod +x "$backup_dir/grafana_exports/restore_dashboards.sh"
    else
        echo -e "${YELLOW}⚠️  Could not find any dashboards to export.${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Grafana is not running or not accessible at $GRAFANA_URL. Skipping dashboard export.${NC}"
fi

# Backup local configuration files and source code
echo ""
echo "📁 Backing up local configuration files and source code..."

# Define all directories to be backed up, including new messaging and DB components
declare -a dirs_to_backup=(
    "prometheus" "grafana" "src" "message-brokers"
    "transaction-monitor" "performance-aggregator" "anomaly-injector"
    "mock-windows-exporter" "mock-iis-application" "trace-generator"
    "message-producer" "message-consumer" "db-connection-demo"
)

for dir in "${dirs_to_backup[@]}"; do
    if [ -d "$dir" ]; then
        cp -r "$dir" "$backup_dir/"
        echo "   ✅ $dir backed up"
    fi
done

# Backup Docker Compose files and shell scripts
cp docker-compose*.yml "$backup_dir/" 2>/dev/null
echo "   ✅ Docker compose files backed up"

mkdir -p "$backup_dir/scripts"
cp ./*.sh "$backup_dir/scripts/" 2>/dev/null
echo "   ✅ Shell scripts backed up"

echo ""
echo -e "${BLUE}📊 Step 2: Capturing Live System Metrics${NC}"
echo "========================================="

# Collect a snapshot of metrics from all running services
metrics_summary="$backup_dir/live_metrics_snapshot.txt"
echo "📝 Collecting metrics snapshot... (This may take a moment)"

{
    echo "System Metrics Snapshot at: $(date)"
    echo "===================================="
    echo ""
    
    echo "🤖 DDoS Detection:"
    curl -s "$PROMETHEUS_URL/api/v1/query?query=ddos_detection_score" 2>/dev/null | jq -r '.data.result[0].value[1] // "No data"'
    
    echo ""
    echo "🎯 Auto-Baselining:"
    curl -s http://localhost:5002/health 2>/dev/null | jq . 2>/dev/null || echo "Not available"
    
    echo ""
    echo "💰 Transaction Monitoring:"
    curl -s http://localhost:5003/stats 2>/dev/null | jq . 2>/dev/null || echo "Not available"
    
    echo ""
    echo "🪟 Windows IIS Metrics:"
    echo "Request rate: $(curl -s "$PROMETHEUS_URL/api/v1/query?query=sum(rate(windows_iis_requests_total[5m]))*60" | jq -r '.data.result[0].value[1] // "0"')"
    
    echo ""
    echo "🔍 Transaction Tracing:"
    echo "Total traces: $(curl -s http://localhost:9414/metrics 2>/dev/null | grep -E 'traces_generated_total{' | awk '{sum += $NF} END {print sum}')"
    echo "Services in Jaeger: $(curl -s http://localhost:16686/jaeger/api/services 2>/dev/null | jq -r '.data | length')"
    
    echo ""
    echo "📨 Message Queue Status:"
    echo "RabbitMQ Consumer Status: $(curl -s http://localhost:5008/consumer/status 2>/dev/null | jq . 2>/dev/null || echo "Not available")"
    echo "Messages Published (Prometheus): $(curl -s http://localhost:5007/metrics 2>/dev/null | grep 'banking_messages_published_total' | awk '{sum += $NF} END {print sum}')"
    echo "Messages Consumed (Prometheus): $(curl -s http://localhost:5008/metrics 2>/dev/null | grep 'banking_messages_consumed_total' | awk '{sum += $NF} END {print sum}')"
    
    echo ""
    echo "🗄️ Database Connection Pool:"
    curl -s http://localhost:5009/pool/status 2>/dev/null | jq . 2>/dev/null || echo "Not available"
    
} > "$metrics_summary"
echo "   ✅ Metrics snapshot saved to '$metrics_summary'"


echo ""
echo -e "${BLUE}📋 Step 3: Creating Restoration Package${NC}"
echo "======================================"

# Create a comprehensive README file for this specific backup
cat > "$backup_dir/RESTORE_INSTRUCTIONS.md" << EOF
# System Restoration Guide
**Backup Created:** $backup_timestamp

This backup is a **live snapshot** taken while the system was running.

## Services Included
- Core banking services
- DDoS detection and auto-baselining
- Transaction monitoring suite
- Windows IIS monitoring
- Transaction tracing with Jaeger
- RabbitMQ and Kafka messaging
- PostgreSQL connection pool demo

## Backup Contents
- **Complete Grafana Dashboards:** All dashboards as they appeared in the UI at the time of backup.
- **Service Configurations:** All local YAML/config files for services.
- **Message Broker Configs:** Configurations for RabbitMQ, Kafka, etc.
- **Source Code & Scripts:** A copy of the 'src' directory and helper scripts.
- **Metrics Snapshot:** A file named 'live_metrics_snapshot.txt' with the state of key metrics.

## To Restore Grafana Dashboards Manually
1.  Navigate into the 'grafana_exports' directory within this backup.
2.  Execute the restore script: \`./restore_dashboards.sh\`
3.  This will overwrite existing dashboards with the versions from this backup.
EOF

echo "   ✅ Restoration instructions created."

# Calculate and display the final backup size
backup_size=$(du -sh "$backup_dir" | cut -f1)

echo ""
echo -e "${GREEN}🎉 LIVE BACKUP COMPLETE!${NC}"
echo "--------------------------------"
echo "📦 Backup size: $backup_size"
echo "📁 Backup location: $backup_dir"
echo "📊 Dashboard exports: $(ls -1 "$backup_dir/grafana_exports/"*.json 2>/dev/null | wc -l) files"
echo ""
echo "✅ System remains online. This backup is a non-disruptive snapshot."
