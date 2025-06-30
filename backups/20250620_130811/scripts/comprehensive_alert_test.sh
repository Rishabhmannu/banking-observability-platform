#!/bin/bash

echo "🚨 Comprehensive DDoS Alert Testing"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "📊 Current System Status:"
echo "------------------------"

# Check current metrics
current_score=$(curl -s 'http://localhost:9090/api/v1/query?query=ddos_detection_score' | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 'N/A')
current_prediction=$(curl -s 'http://localhost:9090/api/v1/query?query=ddos_binary_prediction' | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 'N/A')
current_confidence=$(curl -s 'http://localhost:9090/api/v1/query?query=ddos_confidence' | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 'N/A')
ml_service_status=$(curl -s 'http://localhost:9090/api/v1/query?query=up{job="ddos-ml-detection"}' | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 'N/A')

echo "🎯 Detection Score: $current_score"
echo "🔮 Binary Prediction: $current_prediction"
echo "💪 Confidence: $current_confidence"
echo "🤖 ML Service Status: $ml_service_status"
echo ""

echo "🧪 Test 1: Generating predictions to trigger High Score Alert (>0.7)"
echo "====================================================================="

high_score_found=false
for i in {1..50}; do
    response=$(curl -s http://localhost:5001/predict)
    score=$(echo $response | jq -r '.anomaly_score' 2>/dev/null || echo 'N/A')
    binary=$(echo $response | jq -r '.binary_prediction' 2>/dev/null || echo 'N/A')
    confidence=$(echo $response | jq -r '.confidence' 2>/dev/null || echo 'N/A')
    
    echo "Prediction $i: Score=$score, Binary=$binary, Confidence=$confidence"
    
    # Check for high score (potential alert trigger)
    if [[ $(echo "$score > 0.7" | bc -l 2>/dev/null) == 1 ]]; then
        echo -e "${RED}🚨 HIGH SCORE DETECTED: $score${NC}"
        echo -e "${YELLOW}⏰ Alert should trigger in ~1 minute if this persists${NC}"
        high_score_found=true
    fi
    
    # Check for attack prediction (critical alert)
    if [[ "$binary" == "1" ]]; then
        echo -e "${RED}🚨 ATTACK PREDICTION: $binary${NC}"
        echo -e "${RED}⚠️  CRITICAL ALERT should trigger in ~30 seconds${NC}"
        break
    fi
    
    sleep 3
done

if [ "$high_score_found" = false ]; then
    echo -e "${YELLOW}ℹ️  No high scores detected. This is normal - alerts trigger based on sustained high values.${NC}"
fi

echo ""
echo "🔔 Alert Status Check"
echo "===================="

echo "📋 Check these locations for active alerts:"
echo "1. Grafana Alert Rules: http://localhost:3000/alerting/rules"
echo "2. Grafana Active Alerts: http://localhost:3000/alerting/list"
echo "3. Your Gmail inbox (if configured)"
echo "4. Webhook receiver terminal (if running)"

echo ""
echo "📈 Current Metrics Summary:"
echo "==========================="

# Get latest metrics after test
sleep 5
final_score=$(curl -s 'http://localhost:9090/api/v1/query?query=ddos_detection_score' | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 'N/A')
final_prediction=$(curl -s 'http://localhost:9090/api/v1/query?query=ddos_binary_prediction' | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 'N/A')
final_confidence=$(curl -s 'http://localhost:9090/api/v1/query?query=ddos_confidence' | jq -r '.data.result[0].value[1]' 2>/dev/null || echo 'N/A')

echo "Final Detection Score: $final_score"
echo "Final Binary Prediction: $final_prediction"
echo "Final Confidence: $final_confidence"

# Determine alert likelihood
if [[ $(echo "$final_score > 0.7" | bc -l 2>/dev/null) == 1 ]]; then
    echo -e "${RED}🚨 Current score >0.7 - High Score Alert likely firing!${NC}"
elif [[ $(echo "$final_score > 0.5" | bc -l 2>/dev/null) == 1 ]]; then
    echo -e "${YELLOW}⚠️  Current score >0.5 - Elevated risk${NC}"
else
    echo -e "${GREEN}✅ Current score <0.5 - Normal levels${NC}"
fi

if [[ "$final_prediction" == "1" ]]; then
    echo -e "${RED}🚨 Binary prediction = 1 - CRITICAL ALERT should be firing!${NC}"
else
    echo -e "${GREEN}✅ Binary prediction = 0 - No attack detected${NC}"
fi

echo ""
echo "🧪 Test 2: Simulate ML Service Outage (Optional)"
echo "==============================================="
echo "To test ML Service Down alert:"
echo "1. Stop ML service: docker stop ddos-ml-detection"
echo "2. Wait 2 minutes"
echo "3. Check for 'ML Service Down' alert"
echo "4. Restart: docker start ddos-ml-detection"

echo ""
echo "🎯 Manual Alert Testing Commands:"
echo "================================"
echo "# Force high score testing:"
echo "while true; do score=\$(curl -s http://localhost:5001/predict | jq -r '.anomaly_score'); echo \"Score: \$score\"; if (( \$(echo \"\$score > 0.7\" | bc -l) )); then echo \"HIGH SCORE!\"; break; fi; sleep 1; done"
echo ""
echo "# Check alert rules status:"
echo "curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.name | contains(\"DDoS\"))'"

echo ""
echo "✅ Alert testing complete!"
echo ""
echo "🔍 What to check next:"
echo "1. Go to Grafana → Alerting → Alert rules (should show your 4 rules)"
echo "2. Go to Grafana → Alerting → Alerting (shows firing alerts)"
echo "3. Check your email for test notifications"
echo "4. Monitor webhook receiver for real-time alerts"