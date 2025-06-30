#!/bin/bash

echo "📊 Complete System Status - DDoS Detection, Auto-Baselining, Transaction Monitoring & Tracing"
echo "=========================================================================================="
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
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml ps 2>/dev/null || docker compose ps 2>/dev/null || echo "❌ Docker Compose not available"

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

# Windows IIS Monitoring
echo -n "🪟 Windows Exporter (9182): "
if curl -s http://localhost:9182/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    # Check if metrics are being generated
    metric_count=$(curl -s http://localhost:9182/metrics | grep -c "windows_iis_requests_total" 2>/dev/null || echo "0")
    echo "   📊 IIS metrics exposed: $metric_count sites"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo -n "🌐 IIS Application (8090): "
if curl -s http://localhost:8090/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Jaeger
echo -n "🔍 Jaeger UI (16686): "
if curl -s http://localhost:16686 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    # Get service count
    services=$(curl -s "http://localhost:16686/jaeger/api/services" 2>/dev/null | jq -r '.data | length' 2>/dev/null || echo "0")
    echo "   📊 Services being traced: $services"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Trace Generator
echo -n "🔍 Trace Generator (9414): "
if curl -s http://localhost:9414/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    # Get trace generation status
    is_running=$(curl -s http://localhost:9414/status 2>/dev/null | jq -r '.is_running // false' 2>/dev/null)
    traces_total=$(curl -s http://localhost:9414/metrics 2>/dev/null | grep -E "traces_generated_total{" | awk '{sum += $NF} END {print sum}')
    echo "   🚀 Generation active: $is_running"
    echo "   📊 Total traces generated: ${traces_total:-0}"
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
echo -e "${BLUE}🔍 Transaction Tracing Status:${NC}"
echo "============================="

if curl -s http://localhost:16686 >/dev/null 2>&1 && curl -s http://localhost:9414/health >/dev/null 2>&1; then
    # Check trace generation metrics
    traces_per_min=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(traces_generated_total[1m]))*60" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
    
    if [ "$traces_per_min" != "0" ]; then
        echo "📊 Trace Generation Rate: $traces_per_min traces/min"
        
        # Get trace pattern distribution
        echo "📈 Trace Patterns:"
        curl -s http://localhost:9414/metrics 2>/dev/null | grep "traces_generated_total{" | while read line; do
            trace_type=$(echo "$line" | grep -oP 'trace_type="\K[^"]+')
            count=$(echo "$line" | awk '{print $NF}' | cut -d. -f1)
            echo "   • $trace_type: $count traces"
        done
        
        # Check Jaeger services
        services_list=$(curl -s "http://localhost:16686/jaeger/api/services" 2>/dev/null | jq -r '.data[]' 2>/dev/null | grep -v "jaeger-query" | head -5)
        if [ ! -z "$services_list" ]; then
            echo "🔍 Services in Jaeger:"
            echo "$services_list" | while read service; do
                echo "   • $service"
            done
        fi
    else
        echo -e "${YELLOW}⏳ No traces being generated yet${NC}"
    fi
else
    echo -e "${RED}❌ Transaction tracing system not available${NC}"
fi

echo ""
echo -e "${BLUE}🪟 Windows IIS Monitoring Status:${NC}"
echo "=================================="

if curl -s http://localhost:9182/health >/dev/null 2>&1; then
    # Check IIS metrics
    req_rate=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(windows_iis_requests_total[5m]))*60" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
    
    if [ "$req_rate" != "0" ]; then
        echo "📊 Request Volume: $req_rate req/min"
        
        # Get success rate
        success_rate=$(curl -s "http://localhost:9090/api/v1/query?query=((sum(rate(windows_iis_requests_total[5m]))-sum(rate(windows_iis_server_errors_total[5m]))-sum(rate(windows_iis_client_errors_total[5m])))/sum(rate(windows_iis_requests_total[5m])))*100" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
        echo "✅ Success Rate: $success_rate%"
        
        # Get P95 response time
        p95_response=$(curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,sum(rate(windows_iis_request_execution_time_bucket[5m]))by(le))" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
        echo "⏱️  P95 Response Time: ${p95_response}ms"
        
        # Get technical exceptions
        exception_rate=$(curl -s "http://localhost:9090/api/v1/query?query=(sum(rate(windows_netframework_exceptions_thrown_total[5m]))/sum(rate(windows_iis_requests_total[5m])))*100" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null)
        echo "❌ Technical Exceptions: ${exception_rate:0:5}%"
        
        # Check volume status
        volume_indicator=$(curl -s "http://localhost:9090/api/v1/query?query=(sum(rate(windows_iis_requests_total[5m]))/avg_over_time(sum(rate(windows_iis_requests_total[5m]))[30m:]))*100-100" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
        if [ "$volume_indicator" -gt 100 ]; then
            echo -e "🔄 Volume Status: ${RED}SURGE (+$volume_indicator%)${NC}"
        elif [ "$volume_indicator" -lt -50 ]; then
            echo -e "🔄 Volume Status: ${BLUE}DIP ($volume_indicator%)${NC}"
        else
            echo -e "🔄 Volume Status: ${GREEN}NORMAL ($volume_indicator%)${NC}"
        fi
    else
        echo -e "${YELLOW}⏳ No IIS data yet - metrics are initializing${NC}"
    fi
else
    echo -e "${RED}❌ Windows IIS monitoring service not available${NC}"
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
[ $(curl -s http://localhost:9182/health >/dev/null 2>&1 && echo 1 || echo 0) -eq 1 ] && ((services_running++))
[ $(curl -s http://localhost:8090/health >/dev/null 2>&1 && echo 1 || echo 0) -eq 1 ] && ((services_running++))
[ $(curl -s http://localhost:16686 >/dev/null 2>&1 && echo 1 || echo 0) -eq 1 ] && ((services_running++))
[ $(curl -s http://localhost:9414/health >/dev/null 2>&1 && echo 1 || echo 0) -eq 1 ] && ((services_running++))

echo "🎯 ML/Monitoring/Tracing Services: $services_running/9 running"

if [ $services_running -eq 9 ]; then
    echo -e "🤝 ${GREEN}PERFECT INTEGRATION${NC}: All monitoring and tracing services running!"
elif [ $services_running -ge 7 ]; then
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
echo "# Test Windows IIS anomalies:"
echo "./test_windows_iis_anomalies_v2.sh"
echo ""
echo "# View IIS metrics:"
echo "curl -s http://localhost:9182/metrics | grep windows_iis"
echo ""
echo "# View traces in Jaeger:"
echo "open http://localhost:16686"
echo ""
echo "# Check trace generation status:"
echo "curl http://localhost:9414/status | jq"
echo ""
echo "# Configure trace generation rate:"
echo 'curl -X POST http://localhost:9414/configure -H "Content-Type: application/json" -d '"'"'{"patterns_per_minute":{"successful":60,"failed_auth":10,"slow":5,"insufficient_funds":10}}'"'"
echo ""
echo "# Check all dashboards:"
echo "open http://localhost:3000"
echo ""
echo "# Monitor all logs:"
echo "docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml logs -f"

echo ""
echo -e "${GREEN}📋 Status check complete!${NC}"
echo "Run this script anytime with: ./system_status3.sh"