#!/bin/bash

echo "🔧 Grafana Messaging & Database Dashboards Import"
echo "================================================"
echo "Importing new dashboards for message queues and database connections"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
max_attempts=30
attempt=0
while ! curl -s http://localhost:3000/api/health | grep -q "ok"; do
    attempt=$((attempt + 1))
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}❌ Grafana did not become ready after $max_attempts attempts${NC}"
        exit 1
    fi
    echo "Waiting for Grafana... (attempt $attempt/$max_attempts)"
    sleep 5
done

echo -e "${GREEN}✅ Grafana is ready${NC}"
echo ""

# Function to import a dashboard
import_dashboard() {
    local dashboard_file=$1
    local dashboard_name=$2
    
    echo "📊 Importing $dashboard_name..."
    
    # Check if file exists
    if [ ! -f "$dashboard_file" ]; then
        echo -e "${RED}❌ Dashboard file not found: $dashboard_file${NC}"
        return 1
    fi
    
    # Import the dashboard
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u admin:bankingdemo \
        http://localhost:3000/api/dashboards/db \
        -d @"$dashboard_file")
    
    if echo "$response" | grep -q "success"; then
        echo -e "${GREEN}✅ $dashboard_name imported successfully${NC}"
        url=$(echo "$response" | jq -r '.url // "N/A"')
        echo "   📍 URL: http://localhost:3000$url"
        return 0
    else
        echo -e "${RED}❌ Failed to import $dashboard_name${NC}"
        echo "   Error: $response"
        return 1
    fi
}

# Import all dashboards
echo "📦 Starting dashboard imports..."
echo ""

# Track success
total_dashboards=0
successful_imports=0
dashboard_urls=()

# Import Message Queue Dashboard
if import_dashboard "grafana/dashboards/message-queue-dashboard.json" "Message Queue Dashboard"; then
    ((successful_imports++))
    url=$(curl -s -u admin:bankingdemo http://localhost:3000/api/dashboards/db -d @grafana/dashboards/message-queue-dashboard.json | jq -r '.url // "N/A"')
    dashboard_urls+=("Message Queue Dashboard|http://localhost:3000$url")
fi
((total_dashboards++))
echo ""

# Import Database Connection Pool Dashboard
if import_dashboard "grafana/dashboards/db-connection-dashboard.json" "Database Connection Pool Dashboard"; then
    ((successful_imports++))
    url=$(curl -s -u admin:bankingdemo http://localhost:3000/api/dashboards/db -d @grafana/dashboards/db-connection-dashboard.json | jq -r '.url // "N/A"')
    dashboard_urls+=("Database Connection Pool|http://localhost:3000$url")
fi
((total_dashboards++))
echo ""

# Import existing dashboards too if they exist
existing_dashboards=(
    "grafana/dashboards/ddos-detection-dashboard.json|DDoS Detection Dashboard"
    "grafana/dashboards/auto-baselining-dashboard.json|Auto-Baselining Dashboard"
    "grafana/dashboards/banking-overview-dashboard.json|Banking Overview Dashboard"
    "grafana/dashboards/transaction-performance-dashboard.json|Transaction Performance Dashboard"
    "grafana/dashboards/windows-iis-dashboard.json|Windows IIS Dashboard"
    "grafana/dashboards/transaction-tracing-dashboard.json|Transaction Tracing Dashboard"
)

for dashboard_info in "${existing_dashboards[@]}"; do
    IFS='|' read -r file name <<< "$dashboard_info"
    if [ -f "$file" ]; then
        if import_dashboard "$file" "$name"; then
            ((successful_imports++))
            url=$(curl -s -u admin:bankingdemo http://localhost:3000/api/dashboards/db -d @"$file" | jq -r '.url // "N/A"')
            dashboard_urls+=("$name|http://localhost:3000$url")
        fi
        ((total_dashboards++))
        echo ""
    fi
done

# Summary
echo "📋 Dashboard Import Summary:"
echo "==========================="
echo -e "Imported: ${GREEN}$successful_imports${NC} / $total_dashboards dashboards"
echo ""

if [ ${#dashboard_urls[@]} -gt 0 ]; then
    echo "📊 Available Dashboards:"
    echo "======================="
    for dashboard_url in "${dashboard_urls[@]}"; do
        IFS='|' read -r name url <<< "$dashboard_url"
        echo -e "${GREEN}✅${NC} $name"
        echo "   📍 $url"
    done
fi

echo ""
echo "🎯 Next Steps:"
echo "============="
echo "1. Visit the dashboard URLs above"
echo "2. Check that metrics are being displayed"
echo "3. Adjust time ranges (last 30m recommended)"
echo "4. Set refresh rate to 10s for real-time updates"

if [ $successful_imports -eq $total_dashboards ]; then
    echo ""
    echo -e "${GREEN}✨ All dashboards imported successfully!${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠️  Some dashboards failed to import. Check the errors above.${NC}"
fi

# Test data generation reminder
echo ""
echo "💡 Generate Test Data:"
echo "===================="
echo "For Message Queue metrics:"
echo "  curl -X POST http://localhost:5007/publish/transaction"
echo "  curl -X POST http://localhost:5007/publish/notification"
echo ""
echo "For Database Connection metrics:"
echo "  curl -X POST http://localhost:5009/pool/stress-test"
echo ""