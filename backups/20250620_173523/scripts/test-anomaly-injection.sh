#!/bin/bash

echo "🎯 Testing Anomaly Injection System"
echo "==================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to wait with countdown
wait_with_countdown() {
    local seconds=$1
    local message=$2
    echo -n "$message"
    for i in $(seq $seconds -1 1); do
        echo -n " $i"
        sleep 1
    done
    echo ""
}

echo "1️⃣ Testing Latency Injection"
echo "--------------------------"
echo "Injecting 1-second latency into transaction service..."

response=$(curl -s -X POST http://localhost:5005/inject/latency \
    -H "Content-Type: application/json" \
    -d '{
        "target": "transaction-service",
        "delay_ms": 1000,
        "probability": 0.5,
        "duration_minutes": 2
    }')

injection_id=$(echo $response | jq -r '.injection_id')
echo -e "${GREEN}✅ Latency injection started${NC}"
echo "   Injection ID: $injection_id"
echo "   Target: transaction-service"
echo "   Delay: 1000ms with 50% probability"
echo "   Duration: 2 minutes"

wait_with_countdown 30 "⏳ Waiting for effect to be visible..."

echo ""
echo "2️⃣ Testing Failure Injection"
echo "--------------------------"
echo "Injecting failures into auth service..."

response=$(curl -s -X POST http://localhost:5005/inject/failure \
    -H "Content-Type: application/json" \
    -d '{
        "target": "auth-service",
        "error_code": 500,
        "probability": 0.2,
        "duration_minutes": 1
    }')

failure_id=$(echo $response | jq -r '.injection_id')
echo -e "${GREEN}✅ Failure injection started${NC}"
echo "   Injection ID: $failure_id"
echo "   Target: auth-service"
echo "   Error: 500 with 20% probability"
echo "   Duration: 1 minute"

echo ""
echo "3️⃣ Testing Load Injection"
echo "-----------------------"
echo "Injecting spike load pattern..."

response=$(curl -s -X POST http://localhost:5005/inject/load \
    -H "Content-Type: application/json" \
    -d '{
        "pattern": "spike",
        "intensity": "medium",
        "duration_minutes": 3
    }')

load_id=$(echo $response | jq -r '.injection_id')
echo -e "${GREEN}✅ Load injection started${NC}"
echo "   Injection ID: $load_id"
echo "   Pattern: spike"
echo "   Intensity: medium"
echo "   Duration: 3 minutes"

echo ""
echo "4️⃣ Checking Active Injections"
echo "---------------------------"
active=$(curl -s http://localhost:5005/injections | jq '.')
echo "Active injections:"
echo "$active"

echo ""
echo "5️⃣ Monitoring Impact"
echo "------------------"
echo -e "${YELLOW}Monitor the following:${NC}"
echo "• Grafana Transaction Dashboard: http://localhost:3000"
echo "• Look for:"
echo "  - Increased response times in Response Time Percentiles"
echo "  - Spike in Failure Rate Over Time"
echo "  - Changes in Request Count by Transaction Type"
echo "  - Anomaly Score increases"
echo "  - SLO Compliance drops"

wait_with_countdown 60 "⏳ Letting anomalies run for effect..."

echo ""
echo "6️⃣ Stopping Injections"
echo "--------------------"
echo "Stopping all active injections..."

# Stop injections
for id in $injection_id $failure_id $load_id; do
    if [ ! -z "$id" ] && [ "$id" != "null" ]; then
        echo -n "Stopping $id: "
        curl -s -X DELETE "http://localhost:5005/injections/$id" > /dev/null
        echo -e "${GREEN}✅${NC}"
    fi
done

echo ""
echo "✨ Anomaly injection testing complete!"
echo "📊 Check Grafana to see the impact on metrics"