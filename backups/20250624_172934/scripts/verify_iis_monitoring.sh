#!/bin/bash

echo "🔍 Verifying Windows IIS Monitoring Setup..."
echo "==========================================="

# Check services
echo ""
echo "1️⃣ Checking Docker Services..."
if docker ps | grep -q "mock-windows-exporter"; then
    echo "✅ Windows Exporter is running"
else
    echo "❌ Windows Exporter is NOT running"
fi

if docker ps | grep -q "mock-iis-application"; then
    echo "✅ IIS Application is running"
else
    echo "❌ IIS Application is NOT running"
fi

# Check metrics endpoint
echo ""
echo "2️⃣ Checking Metrics Endpoint..."
if curl -s http://localhost:9182/metrics | grep -q "windows_iis_requests_total"; then
    echo "✅ IIS metrics are being exposed"
    echo "   Sample metrics:"
    curl -s http://localhost:9182/metrics | grep "windows_iis_requests_total" | head -3
else
    echo "❌ No IIS metrics found"
fi

# Check Prometheus
echo ""
echo "3️⃣ Checking Prometheus..."
PROM_RESPONSE=$(curl -s http://localhost:9090/api/v1/targets)
if echo "$PROM_RESPONSE" | grep -q "windows-iis"; then
    echo "✅ Windows IIS job configured in Prometheus"
    
    # Check if target is up
    if echo "$PROM_RESPONSE" | grep -A5 "windows-iis" | grep -q '"health":"up"'; then
        echo "✅ Windows IIS target is UP and being scraped"
    else
        echo "⚠️  Windows IIS target exists but may be DOWN"
    fi
else
    echo "❌ Windows IIS job not found in Prometheus"
fi

# Test some queries
echo ""
echo "4️⃣ Testing PromQL Queries..."
# Test request rate
REQUEST_RATE=$(curl -s 'http://localhost:9090/api/v1/query?query=sum(rate(windows_iis_requests_total[1m]))' | grep -o '"value":\[[0-9]*\.[0-9]*,"[0-9]*\.[0-9]*"\]' | grep -o '[0-9]*\.[0-9]*' | tail -1)
if [ ! -z "$REQUEST_RATE" ]; then
    echo "✅ Request rate query working: $REQUEST_RATE requests/sec"
else
    echo "❌ Request rate query failed"
fi

# Test success rate
SUCCESS_RATE=$(curl -s 'http://localhost:9090/api/v1/query?query=((sum(rate(windows_iis_requests_total[1m]))-sum(rate(windows_iis_server_errors_total[1m]))-sum(rate(windows_iis_client_errors_total[1m])))/sum(rate(windows_iis_requests_total[1m])))*100' | grep -o '"value":\[[0-9]*\.[0-9]*,"[0-9]*\.[0-9]*"\]' | grep -o '[0-9]*\.[0-9]*' | tail -1)
if [ ! -z "$SUCCESS_RATE" ]; then
    echo "✅ Success rate query working: $SUCCESS_RATE%"
else
    echo "❌ Success rate query failed"
fi

echo ""
echo "5️⃣ Dashboard Access:"
echo "   📊 Grafana: http://localhost:3000"
echo "   📈 Prometheus: http://localhost:9090"
echo "   🪟 Windows Exporter: http://localhost:9182/metrics"
echo ""
echo "✨ Verification complete!"