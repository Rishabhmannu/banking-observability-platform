#!/bin/bash

echo "🔧 Quick Fixes for Immediate Issues"
echo "=================================="

# Fix 1: Grafana login credentials
echo "🔑 Fix 1: Reset Grafana credentials"
echo "Restarting Grafana with proper environment variables..."

# Stop and restart Grafana with fixed credentials
docker compose stop grafana
docker rm grafana 2>/dev/null

# Start Grafana with explicit credentials
docker run -d \
  --name grafana \
  --network ddos-detection-system_banking-network \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_USER=admin \
  -e GF_SECURITY_ADMIN_PASSWORD=bankingdemo \
  grafana/grafana:latest

echo "✅ Grafana restarted with admin/bankingdemo"

# Fix 2: Auto-baselining metrics endpoint
echo ""
echo "🎯 Fix 2: Fix auto-baselining metrics endpoint"
echo "Restarting auto-baselining service..."

docker compose restart auto-baselining
sleep 15

echo "Testing metrics endpoint..."
metrics_response=$(curl -s http://localhost:5002/metrics | head -c 50)
if [[ $metrics_response == *"<html>"* ]]; then
    echo "❌ Still returning HTML - need complete rebuild"
else
    echo "✅ Fixed! Now returning Prometheus metrics"
fi

# Fix 3: Test URL encoding for calculate-threshold
echo ""
echo "🌐 Fix 3: Test URL encoding fix for calculate-threshold"
echo "Testing with proper URL encoding..."

# Test the endpoint with proper URL encoding
encoded_url="http://localhost:5002/calculate-threshold?metric=sum%28rate%28http_requests_total%5B1m%5D%29%29"
curl -s "$encoded_url" | jq . || echo "❌ Still not working"

echo ""
echo "📊 Quick System Status:"
echo "====================="

echo -n "Banking API: "
curl -s http://localhost:8080/health >/dev/null && echo "✅ UP" || echo "❌ DOWN"

echo -n "Auto-Baselining: "
curl -s http://localhost:5002/health >/dev/null && echo "✅ UP" || echo "❌ DOWN"

echo -n "Grafana (new creds): "
curl -s http://localhost:3000/api/health >/dev/null && echo "✅ UP" || echo "❌ DOWN"

echo -n "Prometheus: "
curl -s http://localhost:9090/-/healthy >/dev/null && echo "✅ UP" || echo "❌ DOWN"

echo ""
echo "🎯 Try These Now:"
echo "==============="
echo "1. Login to Grafana: http://localhost:3000 (admin/bankingdemo)"
echo "2. Test recommendations: curl http://localhost:5002/threshold-recommendations | jq ."
echo "3. Test with encoded URL: curl 'http://localhost:5002/calculate-threshold?metric=sum%28rate%28http_requests_total%5B1m%5D%29%29' | jq ."

echo ""
echo "If these fixes don't work, run the complete recovery script."