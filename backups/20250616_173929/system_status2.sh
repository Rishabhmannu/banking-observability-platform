#!/bin/bash

echo "📊 Enhanced DDoS Detection, Auto-Baselining & Transaction Monitoring System Status"
echo "================================================================================="
echo "$(date)"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to project directory
cd /Users/rishabh/Downloads/Internship\ Related/DDoS_Detection/ddos-detection-system 2>/dev/null || {
    echo "⚠️  Warning: Could not find project directory"
    echo "Current directory: $(pwd)"
}

echo -e "${BLUE}🐳 Docker Services Status:${NC}"
echo "=========================="
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml ps 2>/dev/null || docker compose ps 2>/dev/null || echo "❌ Docker Compose not available"

echo ""
echo -e "${BLUE}🏥 Service Health Checks:${NC}"
echo "========================"

# Banking API
echo -n "🏦 Banking API (8080): "
if curl -s http://localhost:8080/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# DDoS ML Detection  
echo -n "🤖 DDoS ML Detection (5001): "
if curl -s http://localhost:5001/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    ml_status=$(curl -s http://localhost:5001/health | jq -r '.message // "Active"' 2>/dev/null)
    echo "   📋 Status: $ml_status"
else
    echo -e "${YELLOW}⚠️  OFFLINE${NC} (Optional service)"
fi

# Auto-Baselining
echo -n "🎯 Auto-Baselining (5002): "
if curl -s http://localhost:5002/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    recommendations_count=$(curl -s http://localhost:5002/health | jq -r '.recommendations_count // 0' 2>/dev/null)
    algorithms_count=$(curl -s http://localhost:5002/health | jq -r '.algorithms | length // 0' 2>/dev/null)
    echo "   🧠 $algorithms_count algorithms loaded"
    echo "   📊 $recommendations_count metric recommendations active"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Transaction Monitor
echo -n "💰 Transaction Monitor (5003): "
if curl -s http://localhost:5003/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    stats=$(curl -s http://localhost:5003/stats 2>/dev/null)
    if [ ! -z "$stats" ]; then
        total_count=$(echo "$stats" | jq -r '.total_count // 0' 2>/dev/null)
        echo "   📊 Transactions processed: $total_count"
    fi
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Performance Aggregator
echo -n "📈 Performance Aggregator (5004): "
if curl -s http://localhost:5004/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    anomaly_trained=$(curl -s http://localhost:5004/health | jq -r '.anomaly_detector_trained // false' 2>/dev/null)
    echo "   🧠 Anomaly detector trained: $anomaly_trained"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Anomaly Injector
echo -n "🎭 Anomaly Injector (5005): "
if curl -s http://localhost:5005/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    active_injections=$(curl -s http://localhost:5005/health | jq -r '.active_injections // 0' 2>/dev/null)
    echo "   💉 Active injections: $active_injections"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Prometheus
echo -n "📊 Prometheus (9090): "
if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    # Get target count
    targets_up=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -r '[.data.activeTargets[] | select(.health=="up")] | length' 2>/dev/null || echo "0")
    targets_total=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
    echo "   🎯 Targets: $targets_up/$targets_total UP"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Grafana
echo -n "📈 Grafana (3000): "
if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    # Count dashboards
    dashboard_count=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    echo "   📊 Dashboards: $dashboard_count loaded"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}💰 Transaction Monitoring Performance:${NC}"
echo "====================================="

if curl -s http://localhost:5003/health >/dev/null 2>&1; then
    # Check transaction metrics
    req_rate=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(transaction_requests_total[1m]))*60" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
    
    if [ "$req_rate" != "0" ]; then
        echo "📊 Current Transaction Rate: $req_rate req/min"
        
        # Get failure rate
        failure_rate=$(curl -s "http://localhost:9090/api/v1/query?query=(sum(rate(transaction_failures_total[5m]))/sum(rate(transaction_requests_total[5m])))*100" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)
        echo "❌ Failure Rate: ${failure_rate:0:5}%"
        
        # Get slow transaction percentage
        slow_pct=$(curl -s "http://localhost:9090/api/v1/query?query=slow_transaction_percentage{threshold=\"0.5s\"}" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)
        echo "🐌 Slow Transactions (>500ms): ${slow_pct:0:5}%"
    else
        echo -e "${YELLOW}⏳ No transaction data yet - run ./continuous-traffic-generator.sh${NC}"
    fi
else
    echo -e "${RED}❌ Transaction monitoring service not available${NC}"
fi

echo ""
echo -e "${BLUE}🎯 Auto-Baselining Performance:${NC}"
echo "==============================="

if curl -s http://localhost:5002/health >/dev/null 2>&1; then
    # Get current recommendations
    recommendations=$(curl -s http://localhost:5002/threshold-recommendations 2>/dev/null)
    
    if [[ $recommendations == *"api_request_rate"* ]]; then
        echo "📊 Active Metrics Being Monitored:"
        
        for metric in api_request_rate api_error_rate api_response_time_p95 cpu_usage_percent; do
            echo -n "   • $metric: "
            
            # Check if this metric has any recommendations
            has_recommendations=$(echo "$recommendations" | jq -r ".recommendations.$metric | keys | length" 2>/dev/null || echo "0")
            
            if [[ "$has_recommendations" -gt 0 ]]; then
                echo -e "${GREEN}$has_recommendations algorithms${NC}"
            else
                echo -e "${YELLOW}⏳ Processing...${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⏳ Auto-baselining is collecting historical data...${NC}"
    fi
else
    echo -e "${RED}❌ Auto-baselining service not available${NC}"
fi

echo ""
echo -e "${BLUE}🔗 System Integration Status:${NC}"
echo "============================"

# Check all services status
services_running=0
[ $(curl -s http://localhost:5001/health >/dev/null 2>&1 && echo 1 || echo 0) -eq 1 ] && ((services_running++))
[ $(curl -s http://localhost:5002/health >/dev/null 2>&1 && echo 1 || echo 0) -eq 1 ] && ((services_running++))
[ $(curl -s http://localhost:5003/health >/dev/null 2>&1 && echo 1 || echo 0) -eq 1 ] && ((services_running++))
[ $(curl -s http://localhost:5004/health >/dev/null 2>&1 && echo 1 || echo 0) -eq 1 ] && ((services_running++))
[ $(curl -s http://localhost:5005/health >/dev/null 2>&1 && echo 1 || echo 0) -eq 1 ] && ((services_running++))

echo "🎯 ML/Monitoring Services: $services_running/5 running"

if [ $services_running -eq 5 ]; then
    echo -e "🤝 ${GREEN}PERFECT INTEGRATION${NC}: All monitoring services running!"
elif [ $services_running -ge 3 ]; then
    echo -e "🔧 ${YELLOW}PARTIAL INTEGRATION${NC}: Some services need attention"
else
    echo -e "⚠️  ${RED}LIMITED FUNCTIONALITY${NC}: Most services are down"
fi

echo ""
echo -e "${BLUE}🚀 Quick Actions:${NC}"
echo "================="
echo "# Generate transaction traffic:"
echo "./continuous-traffic-generator.sh"
echo ""
echo "# Test anomaly injection:"
echo "./test-anomaly-injection.sh"
echo ""
echo "# View transaction stats:"
echo "curl -s http://localhost:5003/stats | jq ."
echo ""
echo "# Check performance aggregator:"
echo "curl -s http://localhost:5004/aggregated-stats | jq ."
echo ""
echo "# Monitor all logs:"
echo "docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml logs -f"

echo ""
echo -e "${GREEN}📋 Status check complete!${NC}"
echo "Run this script anytime with: ./system_status.sh"