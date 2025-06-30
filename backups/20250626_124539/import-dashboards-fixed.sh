#!/bin/bash

echo "🔧 Fixed Grafana Dashboard Import Script"
echo "======================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Wait for Grafana
echo "⏳ Waiting for Grafana to be ready..."
max_attempts=30
attempt=0
while ! curl -s http://localhost:3000/api/health | grep -q "ok"; do
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}❌ Grafana did not become ready${NC}"
        exit 1
    fi
    sleep 2
done
echo -e "${GREEN}✅ Grafana is ready${NC}"

# Function to import dashboard with proper format
import_dashboard() {
    local dashboard_file=$1
    local dashboard_name=$2
    
    echo ""
    echo "📊 Importing $dashboard_name..."
    
    # Check if file exists
    if [ ! -f "$dashboard_file" ]; then
        echo -e "${RED}❌ Dashboard file not found: $dashboard_file${NC}"
        return 1
    fi
    
    # Create temporary file with proper API format
    temp_file="/tmp/$(basename $dashboard_file .json)-import.json"
    
    # Read the dashboard content
    dashboard_content=$(cat "$dashboard_file")
    
    # Check if it's already in API format
    if echo "$dashboard_content" | jq -e '.dashboard' > /dev/null 2>&1; then
        # Already in API format
        cp "$dashboard_file" "$temp_file"
    else
        # Wrap in API format
        jq -n \
          --argjson dashboard "$dashboard_content" \
          '{
            dashboard: $dashboard,
            overwrite: true,
            folderId: 0
          }' > "$temp_file"
        
        # Ensure required fields
        jq '.dashboard.id = null | .dashboard.uid = null' "$temp_file" > "${temp_file}.tmp" && mv "${temp_file}.tmp" "$temp_file"
    fi
    
    # Import the dashboard
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u admin:bankingdemo \
        http://localhost:3000/api/dashboards/db \
        -d @"$temp_file")
    
    # Clean up temp file
    rm -f "$temp_file"
    
    if echo "$response" | grep -q "success"; then
        echo -e "${GREEN}✅ $dashboard_name imported successfully${NC}"
        url=$(echo "$response" | jq -r '.url // ""')
        uid=$(echo "$response" | jq -r '.uid // ""')
        if [ ! -z "$url" ]; then
            echo "   📍 URL: http://localhost:3000$url"
        fi
        return 0
    else
        echo -e "${RED}❌ Failed to import $dashboard_name${NC}"
        echo "   Error: $response"
        return 1
    fi
}

# Import all dashboards
echo ""
echo "📦 Starting dashboard imports..."

dashboards=(
    "grafana/dashboards/message-queue-dashboard.json|Message Queue Dashboard"
    "grafana/dashboards/db-connection-dashboard.json|Database Connection Pool Dashboard"
    "grafana/dashboards/ddos-detection-dashboard.json|DDoS Detection Dashboard"
    "grafana/dashboards/auto-baselining-dashboard.json|Auto-Baselining Dashboard"
    "grafana/dashboards/banking-overview-dashboard.json|Banking Overview Dashboard"
    "grafana/dashboards/transaction-performance-dashboard.json|Transaction Performance Dashboard"
    "grafana/dashboards/windows-iis-dashboard.json|Windows IIS Dashboard"
    "grafana/dashboards/transaction-tracing-dashboard.json|Transaction Tracing Dashboard"
)

successful=0
total=0

for dashboard_info in "${dashboards[@]}"; do
    IFS='|' read -r file name <<< "$dashboard_info"
    if [ -f "$file" ]; then
        if import_dashboard "$file" "$name"; then
            ((successful++))
        fi
        ((total++))
    fi
done

echo ""
echo "📋 Import Summary: $successful/$total dashboards imported successfully"

# Check why message publishing might be failing
echo ""
echo "🔍 Checking Message Queue Services..."
echo "====================================="

# Check RabbitMQ
rabbitmq_status=$(docker exec banking-rabbitmq rabbitmq-diagnostics ping 2>&1)
if echo "$rabbitmq_status" | grep -q "Ping succeeded"; then
    echo -e "${GREEN}✅ RabbitMQ is responding${NC}"
else
    echo -e "${RED}❌ RabbitMQ is not responding${NC}"
fi

# Check message producer
producer_health=$(curl -s http://localhost:5007/health | jq -r '.rabbitmq // "unknown"')
if [ "$producer_health" = "connected" ]; then
    echo -e "${GREEN}✅ Message Producer connected to RabbitMQ${NC}"
else
    echo -e "${RED}❌ Message Producer NOT connected to RabbitMQ${NC}"
    echo "   Status: $producer_health"
fi

# Check connection pool
pool_status=$(curl -s http://localhost:5009/pool/status | jq -r '.pool.utilization_percent // "unknown"')
echo ""
echo "🔍 Database Connection Pool Status:"
echo "=================================="
echo "Pool utilization: ${pool_status}%"

# Troubleshooting tips
echo ""
echo "🔧 Troubleshooting Tips:"
echo "======================="
echo ""
echo "If Message Queue metrics are missing:"
echo "1. Fix RabbitMQ connection:"
echo "   docker restart banking-message-producer banking-message-consumer"
echo ""
echo "2. Generate test messages:"
echo "   # Wait 30 seconds after restart, then:"
echo "   curl -X POST http://localhost:5007/publish/transaction"
echo "   curl -X POST http://localhost:5007/publish/notification"
echo ""
echo "If Connection Pool shows 0%:"
echo "1. Trigger database activity:"
echo "   curl -X POST http://localhost:5009/pool/stress-test"
echo ""
echo "2. Check pool metrics:"
echo "   curl http://localhost:5009/metrics | grep banking_db_pool"
echo ""
echo "✨ Script complete!"