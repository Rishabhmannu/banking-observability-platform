#!/bin/bash

echo "🔧 Manual Grafana Dashboard Import"
echo "=================================="
echo "Use this if automatic provisioning doesn't work"
echo ""

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
while ! curl -s http://localhost:3000/api/health | grep -q "ok"; do
    echo "Waiting for Grafana..."
    sleep 5
done

echo "✅ Grafana is ready"

echo ""
echo "📊 Importing DDoS Detection Dashboard..."

# Import DDoS Detection Dashboard
ddos_response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u admin:bankingdemo \
  http://localhost:3000/api/dashboards/db \
  -d @grafana/dashboards/ddos-detection-dashboard.json)

if echo "$ddos_response" | grep -q "success"; then
    echo "✅ DDoS Detection Dashboard imported successfully"
    ddos_url=$(echo "$ddos_response" | jq -r '.url // "N/A"')
    echo "   📍 URL: http://localhost:3000$ddos_url"
else
    echo "❌ Failed to import DDoS Detection Dashboard"
    echo "   Error: $ddos_response"
fi

echo ""
echo "📊 Importing Auto-Baselining Dashboard..."

# Import Auto-Baselining Dashboard
baselining_response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u admin:bankingdemo \
  http://localhost:3000/api/dashboards/db \
  -d @grafana/dashboards/auto-baselining-dashboard.json)

if echo "$baselining_response" | grep -q "success"; then
    echo "✅ Auto-Baselining Dashboard imported successfully"
    baselining_url=$(echo "$baselining_response" | jq -r '.url // "N/A"')
    echo "   📍 URL: http://localhost:3000$baselining_url"
else
    echo "❌ Failed to import Auto-Baselining Dashboard"
    echo "   Error: $baselining_response"
fi

echo ""
echo "📊 Importing Banking Overview Dashboard..."

# Import Banking Overview Dashboard
banking_response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u admin:bankingdemo \
  http://localhost:3000/api/dashboards/db \
  -d @grafana/dashboards/banking-overview-dashboard.json)

if echo "$banking_response" | grep -q "success"; then
    echo "✅ Banking Overview Dashboard imported successfully"
    banking_url=$(echo "$banking_response" | jq -r '.url // "N/A"')
    echo "   📍 URL: http://localhost:3000$banking_url"
else
    echo "❌ Failed to import Banking Overview Dashboard"
    echo "   Error: $banking_response"
fi

echo ""
echo "📋 Dashboard Import Summary:"
echo "==========================="
echo "✅ DDoS Detection: http://localhost:3000$ddos_url"
echo "✅ Auto-Baselining: http://localhost:3000$baselining_url"  
echo "✅ Banking Overview: http://localhost:3000$banking_url"

echo ""
echo "🎯 Next Steps:"
echo "============="
echo "1. Visit each dashboard URL above"
echo "2. Verify data is showing correctly"
echo "3. Customize time ranges and refresh rates as needed"
echo "4. Set up alerts if desired"

echo ""
echo "✨ Manual import complete!"