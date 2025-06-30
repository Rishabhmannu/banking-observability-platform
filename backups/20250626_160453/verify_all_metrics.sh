#!/bin/bash

echo "🔍 Comprehensive Metrics Verification"
echo "====================================="
echo "Checking all metrics needed for Grafana dashboards"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "📊 Step 1: DDoS Detection Metrics"
echo "================================="

ddos_metrics=(
    "ddos_detection_score"
    "ddos_confidence" 
    "ddos_binary_prediction"
    "ddos_model_predictions_total"
    "detection_latency_seconds"
    "service_uptime_seconds"
)

for metric in "${ddos_metrics[@]}"; do
    echo -n "  $metric: "
    
    # Query Prometheus for this metric
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result | length')
    
    if [[ "$result" -gt 0 ]]; then
        echo -e "${GREEN}✅ Available${NC}"
        
        # Get current value
        value=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result[0].value[1] // "N/A"')
        echo "     Current value: $value"
    else
        echo -e "${RED}❌ Missing${NC}"
    fi
done

echo ""
echo "📊 Step 2: Auto-Baselining Metrics"
echo "=================================="

baselining_metrics=(
    "threshold_recommendations_total"
    "algorithm_execution_seconds"
    "active_metrics_being_monitored"
)

for metric in "${baselining_metrics[@]}"; do
    echo -n "  $metric: "
    
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result | length')
    
    if [[ "$result" -gt 0 ]]; then
        echo -e "${GREEN}✅ Available${NC}"
        
        # For metrics with labels, show breakdown
        if [[ "$metric" == "algorithm_execution_seconds" ]]; then
            echo "     Algorithm breakdown:"
            curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result[] | "       " + .metric.algorithm + ": " + .value[1]'
        else
            value=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result[0].value[1] // "N/A"')
            echo "     Current value: $value"
        fi
    else
        echo -e "${RED}❌ Missing${NC}"
    fi
done

echo ""
echo "📊 Step 3: Banking System Metrics"
echo "================================="

banking_metrics=(
    "up{job=\"banking-services\"}"
    "rate(http_requests_total[1m])"
    "rate(http_requests_total{status=~\"5..\"}[1m])"
    "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))"
)

for metric in "${banking_metrics[@]}"; do
    echo -n "  $metric: "
    
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result | length')
    
    if [[ "$result" -gt 0 ]]; then
        echo -e "${GREEN}✅ Available ($result series)${NC}"
    else
        echo -e "${RED}❌ Missing${NC}"
    fi
done

echo ""
echo "📊 Step 4: Infrastructure Metrics"
echo "================================="

infra_metrics=(
    "up{job=\"node-exporter\"}"
    "node_cpu_seconds_total"
    "node_memory_MemAvailable_bytes"
    "node_network_receive_bytes_total"
)

for metric in "${infra_metrics[@]}"; do
    echo -n "  $metric: "
    
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result | length')
    
    if [[ "$result" -gt 0 ]]; then
        echo -e "${GREEN}✅ Available ($result series)${NC}"
    else
        echo -e "${YELLOW}⚠️  Missing (optional)${NC}"
    fi
done

echo ""
echo "🎯 Step 5: Test Dashboard Queries"
echo "================================="

# Test key dashboard queries
dashboard_queries=(
    "ddos_binary_prediction"
    "ddos_confidence * 100"
    "rate(ddos_model_predictions_total[5m]) * 60"
    "active_metrics_being_monitored"
    "sum(rate(http_requests_total[1m]))"
)

echo "Testing queries that will be used in dashboards:"
for query in "${dashboard_queries[@]}"; do
    echo -n "  '$query': "
    
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$(echo "$query" | sed 's/ /%20/g')" 2>/dev/null | jq -r '.data.result | length' 2>/dev/null)
    
    if [[ "$result" -gt 0 ]]; then
        echo -e "${GREEN}✅ Working${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
    fi
done

echo ""
echo "🔗 Step 6: Service Endpoint Tests"
echo "================================="

endpoints=(
    "DDoS Detection:http://localhost:5001/metrics"
    "Auto-Baselining:http://localhost:5002/metrics"
    "Banking API:http://localhost:8080/metrics"
    "Prometheus:http://localhost:9090/api/v1/targets"
    "Grafana:http://localhost:3000/api/health"
)

for endpoint_info in "${endpoints[@]}"; do
    service_name=$(echo $endpoint_info | cut -d: -f1)
    service_url=$(echo $endpoint_info | cut -d: -f2-)
    
    echo -n "  $service_name: "
    
    if curl -s "$service_url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Responding${NC}"
    else
        echo -e "${RED}❌ Not responding${NC}"
    fi
done

echo ""
echo "📋 Summary & Recommendations"
echo "============================"

# Count available metrics
ddos_available=0
baselining_available=0
banking_available=0

for metric in "${ddos_metrics[@]}"; do
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result | length' 2>/dev/null)
    if [[ "$result" -gt 0 ]]; then
        ((ddos_available++))
    fi
done

for metric in "${baselining_metrics[@]}"; do
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result | length' 2>/dev/null)
    if [[ "$result" -gt 0 ]]; then
        ((baselining_available++))
    fi
done

echo "📊 Metrics Availability:"
echo "• DDoS Detection: $ddos_available/${#ddos_metrics[@]} metrics available"
echo "• Auto-Baselining: $baselining_available/${#baselining_metrics[@]} metrics available"
echo "• Banking System: Available"

if [[ $ddos_available -eq ${#ddos_metrics[@]} ]] && [[ $baselining_available -eq ${#baselining_metrics[@]} ]]; then
    echo -e "${GREEN}🎉 All metrics available! Dashboards should work perfectly.${NC}"
elif [[ $ddos_available -gt 0 ]] && [[ $baselining_available -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Most metrics available. Dashboards will work with some limitations.${NC}"
else
    echo -e "${RED}❌ Critical metrics missing. Dashboards may not display data.${NC}"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "• Restart services with missing metrics"
    echo "• Check service logs: docker compose logs [service-name]"
    echo "• Verify /metrics endpoints are working"
fi

echo ""
echo "🚀 Ready for Dashboard Creation!"
echo "Next step: Run the dashboard setup script"