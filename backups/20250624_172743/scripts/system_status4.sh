#!/bin/bash

echo "📊 System Status v4 - Complete AIOps Platform Health Check"
echo "========================================================="
echo "$(date)"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Navigate to project directory
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" 2>/dev/null || {
    echo "⚠️  Warning: Could not find project directory"
}

echo -e "${BLUE}🐳 Docker Container Overview:${NC}"
echo "============================="
# Show running containers count
running=$(docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml ps --services --filter "status=running" 2>/dev/null | wc -l)
total=$(docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml ps --services 2>/dev/null | wc -l)
echo "Containers: $running/$total running"
echo ""

echo -e "${BLUE}🏥 Core Services Health:${NC}"
echo "======================="

# Banking API
echo -n "🏦 Banking API Gateway (8080): "
if curl -s http://localhost:8080/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Prometheus
echo -n "📊 Prometheus (9090): "
if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    targets_up=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -r '[.data.activeTargets[] | select(.health=="up")] | length' 2>/dev/null || echo "0")
    targets_total=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
    echo "   🎯 Targets: $targets_up/$targets_total UP"
    
    # Check for removed target
    iis_8088=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -r '.data.activeTargets[] | select(.labels.instance=="mock-iis-application:8088")' 2>/dev/null)
    if [ ! -z "$iis_8088" ]; then
        echo -e "   ${YELLOW}⚠️  Old IIS target (8088) still present - should be removed${NC}"
    fi
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Grafana
echo -n "📈 Grafana (3000): "
if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    dashboard_count=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    echo "   📊 Dashboards: $dashboard_count loaded"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}🤖 ML/Detection Services:${NC}"
echo "========================"

# DDoS Detection
echo -n "🛡️  DDoS ML Detection (5001): "
if curl -s http://localhost:5001/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    score=$(curl -s "http://localhost:9090/api/v1/query?query=ddos_detection_score" | jq -r '.data.result[0].value[1] // "N/A"' 2>/dev/null)
    echo "   📊 Current score: $score"
else
    echo -e "${YELLOW}⏸️  STOPPED${NC} (Optional service)"
fi

# Auto-Baselining
echo -n "🎯 Auto-Baselining (5002): "
if curl -s http://localhost:5002/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    health=$(curl -s http://localhost:5002/health 2>/dev/null)
    algorithms=$(echo "$health" | jq -r '.algorithms | length' 2>/dev/null || echo "0")
    recommendations=$(echo "$health" | jq -r '.recommendations_count' 2>/dev/null || echo "0")
    echo "   🧠 Algorithms: $algorithms | 📊 Recommendations: $recommendations"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}💰 Transaction Monitoring:${NC}"
echo "========================="

# Transaction Monitor
echo -n "📊 Transaction Monitor (5003): "
if curl -s http://localhost:5003/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    stats=$(curl -s http://localhost:5003/stats 2>/dev/null)
    if [ ! -z "$stats" ]; then
        total=$(echo "$stats" | jq -r '.total_count // 0' 2>/dev/null)
        echo "   💳 Transactions: $total processed"
    fi
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Performance Aggregator
echo -n "📈 Performance Aggregator (5004): "
if curl -s http://localhost:5004/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Anomaly Injector
echo -n "🎭 Anomaly Injector (5005): "
if curl -s http://localhost:5005/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    active=$(curl -s http://localhost:5005/health | jq -r '.active_injections // 0' 2>/dev/null)
    echo "   💉 Active anomalies: $active"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}🔍 Transaction Tracing:${NC}"
echo "======================"

# Jaeger
echo -n "🔍 Jaeger UI (16686): "
if curl -s http://localhost:16686 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    services=$(curl -s "http://localhost:16686/jaeger/api/services" 2>/dev/null | jq -r '.data | length' 2>/dev/null || echo "0")
    echo "   📊 Services traced: $services"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Trace Generator
echo -n "🔄 Trace Generator (9414): "
if curl -s http://localhost:9414/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    # Get metrics
    traces_total=$(curl -s http://localhost:9414/metrics 2>/dev/null | grep -E "traces_generated_total{" | awk '{sum += $NF} END {print int(sum)}')
    traces_per_min=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(traces_generated_total[1m]))*60" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
    echo "   📊 Total: ${traces_total:-0} | Rate: ${traces_per_min:-0}/min"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}🪟 Windows IIS Monitoring:${NC}"
echo "========================="

# Windows Exporter
echo -n "📊 Windows Exporter (9182): "
if curl -s http://localhost:9182/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    iis_metrics=$(curl -s http://localhost:9182/metrics 2>/dev/null | grep -c "windows_iis_requests_total" || echo "0")
    echo "   📈 IIS sites monitored: $((iis_metrics / 3))"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# IIS Application
echo -n "🌐 IIS Mock App (8090): "
if curl -s http://localhost:8090/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    echo "   📝 Note: No /metrics endpoint (metrics via Windows Exporter)"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# IIS Metrics Summary
if curl -s http://localhost:9182/health >/dev/null 2>&1; then
    req_rate=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(windows_iis_requests_total[5m]))*60" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
    if [ "$req_rate" != "0" ]; then
        echo "   📊 Request rate: $req_rate req/min"
        success_rate=$(curl -s "http://localhost:9090/api/v1/query?query=((sum(rate(windows_iis_requests_total[5m]))-sum(rate(windows_iis_server_errors_total[5m]))-sum(rate(windows_iis_client_errors_total[5m])))/sum(rate(windows_iis_requests_total[5m])))*100" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
        echo "   ✅ Success rate: $success_rate%"
    fi
fi

echo ""
echo -e "${BLUE}📊 Dashboard Status:${NC}"
echo "==================="

if curl -s http://localhost:3000/api/health | grep -q "ok" 2>/dev/null; then
    dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null)
    if [ ! -z "$dashboards" ]; then
        echo "$dashboards" | jq -r '.[] | "   📊 " + .title + " (uid: " + .uid + ")"' 2>/dev/null | head -6
        
        # Check for Transaction Tracing dashboard
        tracing_dashboard=$(echo "$dashboards" | jq -r '.[] | select(.title | contains("Transaction Tracing")) | .uid' 2>/dev/null)
        if [ ! -z "$tracing_dashboard" ]; then
            echo -e "   ${GREEN}✅ Transaction Tracing dashboard with manual fixes present${NC}"
        fi
    else
        echo "   ⚠️  No dashboards found"
    fi
else
    echo "   ❌ Grafana not accessible"
fi

echo ""
echo -e "${BLUE}🎯 System Integration Summary:${NC}"
echo "============================="

# Count healthy services
healthy_count=0
total_services=14

services_to_check=(
    "http://localhost:8080/health"
    "http://localhost:5001/health"
    "http://localhost:5002/health"
    "http://localhost:5003/health"
    "http://localhost:5004/health"
    "http://localhost:5005/health"
    "http://localhost:9182/health"
    "http://localhost:8090/health"
    "http://localhost:9414/health"
    "http://localhost:16686"
    "http://localhost:9090/-/healthy"
    "http://localhost:3000/api/health"
)

for url in "${services_to_check[@]}"; do
    curl -s "$url" >/dev/null 2>&1 && ((healthy_count++))
done

if [ $healthy_count -eq $total_services ]; then
    echo -e "🏆 ${GREEN}PERFECT HEALTH${NC}: All $total_services services operational!"
elif [ $healthy_count -ge 10 ]; then
    echo -e "💪 ${GREEN}EXCELLENT${NC}: $healthy_count/$total_services services running"
elif [ $healthy_count -ge 7 ]; then
    echo -e "⚠️  ${YELLOW}PARTIAL${NC}: $healthy_count/$total_services services running"
else
    echo -e "🚨 ${RED}CRITICAL${NC}: Only $healthy_count/$total_services services running"
fi

echo ""
echo -e "${BLUE}🚀 Quick Commands:${NC}"
echo "=================="
echo "# View all logs:"
echo "docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml logs -f"
echo ""
echo "# Generate traffic:"
echo "./continuous-traffic-generator.sh"
echo ""
echo "# Test anomalies:"
echo "./test-anomaly-injection.sh"
echo "./test_windows_iis_anomalies_v2.sh"
echo ""
echo "# Access UIs:"
echo "Grafana: http://localhost:3000 (admin/bankingdemo)"
echo "Jaeger: http://localhost:16686"
echo "Prometheus: http://localhost:9090"
echo ""
echo -e "${GREEN}✨ Status check complete!${NC}"
echo "Generated at: $(date '+%Y-%m-%d %H:%M:%S')"