#!/bin/bash

echo "🧪 Testing Transaction Performance Monitoring System"
echo "==================================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test function
test_endpoint() {
    local name=$1
    local url=$2
    local expected=$3
    
    echo -n "Testing $name: "
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$response" = "$expected" ]; then
        echo -e "${GREEN}✅ PASS${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} (Expected $expected, got $response)"
        return 1
    fi
}

# Test all service endpoints
echo "1️⃣ Testing Service Health Endpoints"
echo "--------------------------------"
test_endpoint "Transaction Monitor Health" "http://localhost:5003/health" "200"
test_endpoint "Performance Aggregator Health" "http://localhost:5004/health" "200"
test_endpoint "Anomaly Injector Health" "http://localhost:5005/health" "200"

echo ""
echo "2️⃣ Testing Metrics Endpoints"
echo "-------------------------"
test_endpoint "Transaction Monitor Metrics" "http://localhost:5003/metrics" "200"
test_endpoint "Performance Aggregator Metrics" "http://localhost:5004/metrics" "200"
test_endpoint "Anomaly Injector Metrics" "http://localhost:5005/metrics" "200"

echo ""
echo "3️⃣ Simulating Transactions"
echo "-----------------------"
echo "Sending test transactions..."

# Simulate different transaction types
for type in deposit withdrawal transfer query; do
    echo -n "  $type transaction: "
    response=$(curl -s -X POST http://localhost:5003/simulate-transaction \
        -H "Content-Type: application/json" \
        -d "{\"type\": \"$type\", \"duration\": 0.2, \"status\": \"success\"}")
    
    if echo "$response" | grep -q "recorded"; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
    fi
done

echo ""
echo "4️⃣ Testing Transaction Monitor Stats"
echo "---------------------------------"
stats=$(curl -s http://localhost:5003/stats)
echo "Current stats: $stats"

echo ""
echo "5️⃣ Testing Performance Aggregator"
echo "------------------------------"
echo "Triggering SLO calculation..."
curl -s -X POST http://localhost:5004/trigger-calculation \
    -H "Content-Type: application/json" \
    -d '{"type": "slo"}' > /dev/null
echo -e "${GREEN}✅ SLO calculation triggered${NC}"

echo ""
echo "Getting aggregated stats..."
agg_stats=$(curl -s http://localhost:5004/aggregated-stats | jq '.')
echo "$agg_stats"

echo ""
echo "6️⃣ Checking Prometheus Targets"
echo "----------------------------"
targets=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[]? | select(.job | test("transaction|performance|anomaly")) | {job: .job, health: .health}' 2>/dev/null || echo "No matching targets found")
if [ ! -z "$targets" ]; then
    echo "$targets"
else
    echo "No transaction monitoring targets found in Prometheus yet"
fi
echo ""
echo "✨ Basic testing complete!"
echo "📊 Check Grafana for visualizations"