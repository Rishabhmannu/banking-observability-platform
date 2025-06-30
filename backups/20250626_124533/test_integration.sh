#!/bin/bash

echo "🧪 Testing DDoS Detection Integration"
echo "===================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test 1: Check if ML service is running
echo "🤖 Test 1: ML Service Health Check"
if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    echo -e "  ✅ ML Service: ${GREEN}RUNNING${NC}"
    
    # Get current prediction
    prediction=$(curl -s http://localhost:5001/predict)
    echo "  📊 Current Prediction: $prediction"
    
    # Check metrics endpoint
    metrics=$(curl -s http://localhost:5001/metrics | grep ddos_detection_score | head -1)
    echo "  📈 Current Metrics: $metrics"
else
    echo -e "  ❌ ML Service: ${RED}NOT RUNNING${NC}"
    echo "  Run: ./start_ml_service.sh"
    exit 1
fi

# Test 2: Check Prometheus targets
echo ""
echo "📊 Test 2: Prometheus Target Discovery"

targets_response=$(curl -s "http://localhost:9090/api/v1/targets")
if echo "$targets_response" | grep -q "ddos-ml-detection"; then
    echo -e "  ✅ ML Service Target: ${GREEN}DISCOVERED${NC}"
    
    # Check target health
    if echo "$targets_response" | grep -A5 "ddos-ml-detection" | grep -q '"health":"up"'; then
        echo -e "  ✅ Target Health: ${GREEN}UP${NC}"
    else
        echo -e "  ⚠️  Target Health: ${YELLOW}DOWN${NC}"
    fi
else
    echo -e "  ❌ ML Service Target: ${RED}NOT FOUND${NC}"
    echo "  This means Prometheus is not configured to scrape the ML service"
fi

# Test 3: Check if metrics are being collected
echo ""
echo "📈 Test 3: Metrics Collection"

# Test ddos_detection_score
score_response=$(curl -s "http://localhost:9090/api/v1/query?query=ddos_detection_score")
if echo "$score_response" | grep -q "ddos_detection_score"; then
    echo -e "  ✅ ddos_detection_score: ${GREEN}AVAILABLE${NC}"
    score_value=$(echo "$score_response" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
    echo "  📊 Current Score: $score_value"
else
    echo -e "  ❌ ddos_detection_score: ${RED}NOT AVAILABLE${NC}"
fi

# Test ddos_binary_prediction
pred_response=$(curl -s "http://localhost:9090/api/v1/query?query=ddos_binary_prediction")
if echo "$pred_response" | grep -q "ddos_binary_prediction"; then
    echo -e "  ✅ ddos_binary_prediction: ${GREEN}AVAILABLE${NC}"
    pred_value=$(echo "$pred_response" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
    echo "  🎯 Current Prediction: $pred_value"
else
    echo -e "  ❌ ddos_binary_prediction: ${RED}NOT AVAILABLE${NC}"
fi

# Test ddos_confidence
conf_response=$(curl -s "http://localhost:9090/api/v1/query?query=ddos_confidence")
if echo "$conf_response" | grep -q "ddos_confidence"; then
    echo -e "  ✅ ddos_confidence: ${GREEN}AVAILABLE${NC}"
    conf_value=$(echo "$conf_response" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A")
    echo "  🔍 Current Confidence: $conf_value"
else
    echo -e "  ❌ ddos_confidence: ${RED}NOT AVAILABLE${NC}"
fi

# Test 4: Check alert rules
echo ""
echo "🚨 Test 4: Alert Rules"

rules_response=$(curl -s "http://localhost:9090/api/v1/rules")
if echo "$rules_response" | grep -q "ddos_detection"; then
    echo -e "  ✅ DDoS Alert Rules: ${GREEN}LOADED${NC}"
    
    # Count rules
    rule_count=$(echo "$rules_response" | grep -o "DDoS" | wc -l | tr -d ' ')
    echo "  📋 Number of DDoS Rules: $rule_count"
else
    echo -e "  ❌ DDoS Alert Rules: ${RED}NOT LOADED${NC}"
fi

# Test 5: Banking services health
echo ""
echo "🏦 Test 5: Banking Services Health"

if curl -s http://localhost:8080/health | grep -q "UP"; then
    echo -e "  ✅ Banking API: ${GREEN}HEALTHY${NC}"
else
    echo -e "  ❌ Banking API: ${RED}UNHEALTHY${NC}"
fi

if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo -e "  ✅ Prometheus: ${GREEN}HEALTHY${NC}"
else
    echo -e "  ❌ Prometheus: ${RED}UNHEALTHY${NC}"
fi

if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    echo -e "  ✅ Grafana: ${GREEN}HEALTHY${NC}"
else
    echo -e "  ⚠️  Grafana: ${YELLOW}NOT RESPONDING${NC}"
fi

# Summary
echo ""
echo "📋 Integration Summary:"
echo "======================"
echo "🤖 ML Service: $(curl -s http://localhost:5001/health > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}")"
echo "📊 Prometheus Scraping: $(echo "$targets_response" | grep -q "ddos-ml-detection" && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}")"
echo "📈 Metrics Collection: $(echo "$score_response" | grep -q "ddos_detection_score" && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}")"
echo "🚨 Alert Rules: $(echo "$rules_response" | grep -q "ddos_detection" && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}")"

echo ""
echo "🔗 Quick Links:"
echo "=============="
echo "🤖 ML Service: http://localhost:5001/health"
echo "📊 Prometheus: http://localhost:9090"
echo "📈 Grafana: http://localhost:3000 (admin/admin)"
echo "🎯 Prometheus Query: http://localhost:9090/graph?g0.expr=ddos_detection_score"

echo ""
echo "✨ Integration test complete!"