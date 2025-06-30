#!/bin/bash

echo "📊 Enhanced DDoS Detection & Auto-Baselining System Status"
echo "========================================================="
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
docker compose ps 2>/dev/null || echo "❌ Docker Compose not available"

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
else
    echo -e "${RED}❌ DOWN${NC}"
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
                
                # Show sample threshold if available
                sample_threshold=$(echo "$recommendations" | jq -r ".recommendations.$metric.rolling_statistics.threshold // null" 2>/dev/null)
                if [[ "$sample_threshold" != "null" && "$sample_threshold" != "" ]]; then
                    echo "     📈 Sample threshold: $sample_threshold"
                fi
            else
                echo -e "${YELLOW}⏳ Processing...${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⏳ Auto-baselining is collecting historical data...${NC}"
        echo "   💡 Algorithms need 30-60 minutes to generate meaningful thresholds"
    fi
else
    echo -e "${RED}❌ Auto-baselining service not available${NC}"
fi

echo ""
echo -e "${BLUE}🔗 System Integration Status:${NC}"
echo "============================"

# Check if both ML systems are running together
ddos_running=false
baselining_running=false

if curl -s http://localhost:5001/health >/dev/null 2>&1; then
    ddos_running=true
fi

if curl -s http://localhost:5002/health >/dev/null 2>&1; then
    baselining_running=true
fi

if $ddos_running && $baselining_running; then
    echo -e "🤝 ${GREEN}PERFECT INTEGRATION${NC}: Both DDoS Detection & Auto-Baselining running independently!"
elif $baselining_running; then
    echo -e "🎯 ${GREEN}AUTO-BASELINING ACTIVE${NC}: Threshold optimization running"
elif $ddos_running; then
    echo -e "🤖 ${GREEN}DDOS DETECTION ACTIVE${NC}: ML-based attack detection running"
else
    echo -e "⚠️  ${YELLOW}NO ML SERVICES RUNNING${NC}"
fi

# Check Prometheus integration
if curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | grep -q "auto-baselining"; then
    echo -e "📊 ${GREEN}PROMETHEUS INTEGRATION${NC}: Auto-baselining metrics being collected"
else
    echo -e "📊 ${YELLOW}PROMETHEUS${NC}: Auto-baselining target not yet discovered"
fi

echo ""
echo -e "${BLUE}🚀 Quick Actions:${NC}"
echo "================="
echo "# View live threshold recommendations:"
echo "curl -s http://localhost:5002/threshold-recommendations | jq ."
echo ""
echo "# Test threshold calculation:"
echo "curl -s 'http://localhost:5002/calculate-threshold?metric=sum(rate(http_requests_total[1m]))' | jq ."
echo ""
echo "# Monitor recommendations in real-time:"
echo "watch -n 30 'curl -s http://localhost:5002/threshold-recommendations | jq .'"
echo ""
echo "# Check detailed logs:"
echo "docker compose logs -f auto-baselining"

echo ""
echo -e "${GREEN}📋 Status check complete!${NC}"
echo "Run this script anytime with: ./system_status.sh"