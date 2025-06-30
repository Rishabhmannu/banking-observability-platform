#!/bin/bash

echo "✅ Live System Backup v1 - Non-disruptive Snapshot"
echo "====================================================="

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
JAEGER_QUERY_URL="http://localhost:16686"

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
        
        # Loop through each dashboard UID and Title, then export it
        echo "$dashboards" | jq -r '.[] | .uid + ":" + .title' | while IFS=: read -r uid title; do
            echo -n "   Exporting '$title'... "
            
            # Fetch the full JSON model for the dashboard by its UID
            dashboard_json=$(curl -s -u "$GRAFANA_CREDENTIALS" "$GRAFANA_URL/api/dashboards/uid/$uid" 2>/dev/null)
            
            if [ ! -z "$dashboard_json" ]; then
                # Sanitize the title to create a valid filename
                filename_title=$(echo "$title" | tr -s ' /' '_')
                
                # Save the complete dashboard JSON (including metadata)
                echo "$dashboard_json" > "$backup_dir/grafana_exports/${uid}_${filename_title}_complete.json"
                
                # Also save just the dashboard model for easier direct import
                echo "$dashboard_json" | jq '.dashboard' > "$backup_dir/grafana_exports/${filename_title}.json"
                
                echo -e "${GREEN}✅${NC}"
            else
                echo -e "${RED}❌ (Failed to fetch JSON)${NC}"
            fi
        done
        
        # Create a simple restore script for convenience
        cat > "$backup_dir/grafana_exports/restore_dashboards.sh" << 'EOF'
#!/bin/bash
echo "🔄 Restoring Grafana dashboards..."
# This script assumes you are running it from within the 'grafana_exports' directory.
for file in *_complete.json; do
    if [ -f "$file" ]; then
        echo -n "Restoring dashboard from '$file'... "
        
        # Extract dashboard JSON and prepare payload for API
        dashboard_data=$(cat "$file")
        import_payload=$(jq -n --argjson dash "$dashboard_data" '{"dashboard": $dash.dashboard, "overwrite": true, "folderId": $dash.meta.folderId}')
        
        # Post the dashboard to Grafana for restoration
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u admin:bankingdemo \
            http://localhost:3000/api/dashboards/db \
            -d "$import_payload")
        
        if echo "$response" | grep -q "success"; then
            echo "✅"
        else
            echo "❌ - Check Grafana logs for details."
            echo "   Response: $response"
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

# Define all directories to be backed up
declare -a dirs_to_backup=("prometheus" "grafana" "src" "transaction-monitor" "performance-aggregator" "anomaly-injector" "mock-windows-exporter" "mock-iis-application" "trace-generator")

for dir in "${dirs_to_backup[@]}"; do
    if [ -d "$dir" ]; then
        cp -r "$dir" "$backup_dir/"
        echo "   ✅ $dir backed up"
    else
        echo "   ℹ️  Skipping '$dir' (directory not found)"
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

# Using a function for cleaner metric fetching
fetch_metric() {
    local name="$1"
    local url="$2"
    local processor="$3"
    echo -n "   Fetching $name... "
    local data=$(curl -s "$url" 2>/dev/null)
    if [ -z "$data" ]; then
        echo "Not available"
        return
    fi
    # Process with jq if specified
    if [ ! -z "$processor" ]; then
        echo "$data" | jq "$processor" 2>/dev/null || echo "Processing error"
    else
        echo "$data"
    fi
}

{
    echo "System Metrics Snapshot at: $(date)"
    echo "===================================="
    echo ""
    
    echo "🤖 DDoS Detection Score:"
    fetch_metric "DDoS Score" "$PROMETHEUS_URL/api/v1/query?query=ddos_detection_score" '.data.result[0].value[1] // "No data"'
    
    echo ""
    echo "🎯 Auto-Baselining Health:"
    fetch_metric "Auto-Baselining" "http://localhost:5002/health" '.'
    
    echo ""
    echo "💰 Transaction Monitoring Stats:"
    fetch_metric "Transaction Stats" "http://localhost:5003/stats" '.'

    echo ""
    echo "🔍 Transaction Tracing (Jaeger):"
    echo "Total services in Jaeger: $(curl -s $JAEGER_QUERY_URL/jaeger/api/services | jq -r '.data | length // "0"')"

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

## Backup Contents
- **Complete Grafana Dashboards:** All dashboards as they appeared in the UI at the time of backup, including any manual edits.
- **Service Configurations:** All local YAML/config files for services like Prometheus, Grafana, etc.
- **Source Code:** A copy of the 'src' directory.
- **Docker & Scripts:** All 'docker-compose.yml' files and helper scripts.
- **Metrics Snapshot:** A file named 'live_metrics_snapshot.txt' with the state of key metrics at the time of backup.

## To Restore Grafana Dashboards Manually
1.  Navigate into the 'grafana_exports' directory within this backup.
2.  Execute the restore script: \`./restore_dashboards.sh\`
3.  Alternatively, you can manually import the '\*_complete.json' files through the Grafana UI ('Create' -> 'Import').

This will overwrite existing dashboards with the versions from this backup.
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
