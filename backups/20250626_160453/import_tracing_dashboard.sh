#!/bin/bash

echo "🔧 Importing Transaction Tracing Dashboard"
echo "========================================"

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
while ! curl -s http://localhost:3000/api/health | grep -q "ok"; do
    echo "Waiting for Grafana..."
    sleep 5
done

echo "✅ Grafana is ready"

echo ""
echo "📊 Importing Transaction Tracing Dashboard..."

# Import the dashboard
response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u admin:bankingdemo \
  http://localhost:3000/api/dashboards/db \
  -d @grafana/dashboards/transaction-tracing-dashboard.json)

if echo "$response" | grep -q "success"; then
    echo "✅ Transaction Tracing Dashboard imported successfully"
    dashboard_url=$(echo "$response" | jq -r '.url // "N/A"')
    echo "   📍 URL: http://localhost:3000$dashboard_url"
else
    echo "❌ Failed to import dashboard"
    echo "   Error: $response"
fi