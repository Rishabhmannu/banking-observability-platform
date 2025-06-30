#!/bin/bash

echo "🧪 Testing DDoS Detection System"
echo "==============================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test banking services
echo "🏦 Testing Banking Services..."
if curl -s http://localhost:8080/health | grep -q "UP"; then
    echo -e "  ✅ Banking API: ${GREEN}HEALTHY${NC}"
else
    echo -e "  ❌ Banking API: ${RED}NOT RESPONDING${NC}"
fi

# Test Prometheus
echo ""
echo "📊 Testing Prometheus..."
if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo -e "  ✅ Prometheus (9090): ${GREEN}HEALTHY${NC}"
elif curl -s http://localhost:9091/-/healthy > /dev/null 2>&1; then
    echo -e "  ✅ Prometheus (9091): ${GREEN}HEALTHY${NC}"
else
    echo -e "  ❌ Prometheus: ${RED}NOT RESPONDING${NC}"
fi

# Test Grafana
echo ""
echo "📈 Testing Grafana..."
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    echo -e "  ✅ Grafana (3000): ${GREEN}HEALTHY${NC}"
elif curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
    echo -e "  ✅ Grafana (3001): ${GREEN}HEALTHY${NC}"
else
    echo -e "  ⚠️  Grafana: ${YELLOW}NOT RESPONDING (OK for now)${NC}"
fi

# Test ML Detection Service
echo ""
echo "🤖 Testing ML Detection Service..."
if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    echo -e "  ✅ ML Service: ${GREEN}HEALTHY${NC}"
    
    # Get detailed status
    echo ""
    echo "🔍 ML Service Details:"
    curl -s http://localhost:5001/status | python3 -m json.tool
    
    echo ""
    echo "🎯 Getting Prediction:"
    curl -s http://localhost:5001/predict | python3 -m json.tool
    
    echo ""
    echo "📊 Prometheus Metrics Sample:"
    curl -s http://localhost:5001/metrics | head -10
    
else
    echo -e "  ❌ ML Service: ${RED}NOT RESPONDING${NC}"
fi

echo ""
echo "🌐 Access URLs:"
echo "=============="
echo "🏦 Banking API: http://localhost:8080"
echo "📊 Prometheus: http://localhost:9090 (or 9091)"
echo "📈 Grafana: http://localhost:3000 (admin/admin)"
echo "🤖 ML Service: http://localhost:5001"

echo ""
echo "✨ Test complete!"