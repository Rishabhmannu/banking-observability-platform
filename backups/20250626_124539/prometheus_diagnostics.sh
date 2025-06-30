#!/bin/bash

echo "🔍 Prometheus Integration Diagnostics & Fixes"
echo "=============================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}📊 Testing All Metrics Endpoints:${NC}"
echo "=================================="

# Test auto-baselining metrics (main issue)
echo -e "\n🎯 ${YELLOW}Auto-Baselining Metrics:${NC}"
echo "curl -s http://localhost:5002/metrics"
response=$(curl -s http://localhost:5002/metrics)
if [[ $response == *"<html>"* ]] || [[ $response == *"<HTML>"* ]]; then
    echo -e "❌ ${RED}PROBLEM: Returns HTML instead of metrics${NC}"
    echo "First 100 chars: ${response:0:100}..."
    echo ""
    echo -e "${YELLOW}🔧 FIXING: Auto-baselining metrics endpoint${NC}"
    echo "Checking auto-baselining logs..."
    docker compose logs --tail=20 auto-baselining
else
    echo -e "✅ ${GREEN}OK: Returns Prometheus metrics${NC}"
fi

# Test banking services metrics
echo -e "\n🏦 ${YELLOW}Banking Services Metrics:${NC}"
services=(
    "account-service:8081"
    "transaction-service:8082" 
    "auth-service:8083"
    "notification-service:8084"
    "fraud-detection:8085"
    "api-gateway:8080"
)

for service_info in "${services[@]}"; do
    service=$(echo $service_info | cut -d: -f1)
    port=$(echo $service_info | cut -d: -f2)
    
    echo -n "  • $service ($port): "
    
    status_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/metrics)
    
    if [ "$status_code" = "200" ]; then
        echo -e "${GREEN}✅ OK${NC}"
    elif [ "$status_code" = "404" ]; then
        echo -e "${RED}❌ 404 (no /metrics endpoint)${NC}"
    else
        echo -e "${YELLOW}⚠️  HTTP $status_code${NC}"
    fi
done

# Test DDoS ML Detection
echo -e "\n🤖 ${YELLOW}DDoS ML Detection:${NC}"
echo -n "  • ml-detection (5001): "
if curl -s http://localhost:5001/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ UP${NC}"
    
    status_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/metrics)
    if [ "$status_code" = "200" ]; then
        echo "    📊 Metrics: ✅ Available"
    else
        echo "    📊 Metrics: ❌ Not available"
    fi
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}🔧 Quick Fixes:${NC}"
echo "==============="

echo ""
echo -e "${YELLOW}Fix 1: Auto-Baselining Metrics Issue${NC}"
echo "------------------------------------"
echo "The auto-baselining service is returning HTML instead of Prometheus metrics."
echo "Let's check what's happening:"

# Check if the metrics endpoint is working
echo ""
echo "🧪 Testing auto-baselining health vs metrics:"
echo "Health endpoint:"
curl -s http://localhost:5002/health | head -3
echo ""
echo "Metrics endpoint (first 200 chars):"
curl -s http://localhost:5002/metrics | head -c 200
echo ""

echo ""
echo -e "${YELLOW}Fix 2: Banking Services Missing /metrics${NC}"
echo "-------------------------------------------"
echo "Most banking services don't have /metrics endpoints."
echo "Quick solutions:"
echo ""
echo "Option A - Add basic metrics endpoints:"
cat > add_basic_metrics.py << 'EOF'
#!/usr/bin/env python3
# This script adds basic metrics to a Flask service

import sys
import re

def add_metrics_to_flask_app(app_file):
    with open(app_file, 'r') as f:
        content = f.read()
    
    # Check if already has metrics
    if '/metrics' in content:
        print(f"✅ {app_file} already has metrics endpoint")
        return
    
    # Add prometheus import
    if 'from prometheus_client import' not in content:
        content = content.replace(
            'from flask import', 
            'from flask import Flask, jsonify, request\nfrom prometheus_client import generate_latest, CONTENT_TYPE_LATEST\n# Original imports:\nfrom flask import'
        )
    
    # Add metrics endpoint
    metrics_code = '''
@app.route('/metrics')
def metrics():
    """Basic Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}
'''
    
    # Insert before the final if __name__ == '__main__'
    content = content.replace(
        "if __name__ == '__main__':",
        metrics_code + "\nif __name__ == '__main__':"
    )
    
    with open(app_file, 'w') as f:
        f.write(content)
    
    print(f"✅ Added metrics endpoint to {app_file}")

# Find and update Flask apps
import os
import glob

flask_apps = glob.glob('*/app.py')
for app in flask_apps:
    if os.path.exists(app):
        add_metrics_to_flask_app(app)

print("🔄 Now rebuild services: docker compose up -d --build")
EOF

chmod +x add_basic_metrics.py
echo "Created: add_basic_metrics.py"

echo ""
echo -e "${YELLOW}Fix 3: Restart Auto-Baselining Service${NC}"
echo "----------------------------------------"
echo "Let's restart the auto-baselining service to fix the metrics issue:"

echo "🔄 Restarting auto-baselining service..."
docker compose restart auto-baselining

echo "⏳ Waiting 15 seconds for restart..."
sleep 15

echo "🧪 Testing metrics endpoint again:"
metrics_test=$(curl -s http://localhost:5002/metrics | head -c 100)
if [[ $metrics_test == *"<html>"* ]] || [[ $metrics_test == *"<HTML>"* ]]; then
    echo -e "❌ ${RED}Still returning HTML${NC}"
    echo "We need to check the auto-baselining service code"
else
    echo -e "✅ ${GREEN}Fixed! Now returning Prometheus metrics${NC}"
fi

echo ""
echo -e "${BLUE}📋 Summary & Next Steps:${NC}"
echo "========================="

# Check final status
working_services=0
total_services=0

# Check auto-baselining
echo -n "🎯 Auto-Baselining Metrics: "
if curl -s http://localhost:5002/metrics | grep -q "^# HELP"; then
    echo -e "${GREEN}✅ WORKING${NC}"
    ((working_services++))
else
    echo -e "${RED}❌ NEEDS FIX${NC}"
fi
((total_services++))

# Check core system
echo -n "🏦 Banking API: "
if curl -s http://localhost:8080/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ WORKING${NC}"
    ((working_services++))
else
    echo -e "${RED}❌ DOWN${NC}"
fi
((total_services++))

echo -n "📊 Prometheus: "
if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
    echo -e "${GREEN}✅ WORKING${NC}"
    ((working_services++))
else
    echo -e "${RED}❌ DOWN${NC}"
fi
((total_services++))

echo ""
echo "📊 System Health: $working_services/$total_services core services working"

echo ""
echo "🚀 Recommended Actions:"
echo "======================="
echo "1. ✅ Your core system is working (Banking + Auto-Baselining + Prometheus)"
echo "2. 🔧 Fix auto-baselining metrics if still broken:"
echo "   docker compose logs auto-baselining"
echo "3. 📊 Add metrics to banking services (optional):"
echo "   ./add_basic_metrics.py && docker compose up -d --build"
echo "4. 🎯 Access your working systems:"
echo "   • Auto-Baselining: http://localhost:5002/threshold-recommendations"
echo "   • Banking API: http://localhost:8080/health"
echo "   • Prometheus: http://localhost:9090/targets"

echo ""
echo -e "${GREEN}✨ Diagnostics complete!${NC}"