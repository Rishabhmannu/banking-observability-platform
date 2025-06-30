#!/bin/bash

echo "🚀 Quick Deploy from Docker Hub - Complete System with Transaction Monitoring"
echo "=========================================================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📥 Pulling latest images from Docker Hub...${NC}"
docker-compose -f docker-compose.hub.yml pull

echo ""
echo -e "${BLUE}🚀 Starting all services...${NC}"
docker-compose -f docker-compose.hub.yml up -d

echo ""
echo -e "${BLUE}⏳ Waiting for services to initialize (2 minutes)...${NC}"
sleep 120

echo ""
echo -e "${BLUE}🧪 Testing services...${NC}"

services=(
    "Banking API:http://localhost:8080/health"
    "DDoS Detection:http://localhost:5001/health"
    "Auto-Baselining:http://localhost:5002/health"
    "Transaction Monitor:http://localhost:5003/health"
    "Performance Aggregator:http://localhost:5004/health"
    "Anomaly Injector:http://localhost:5005/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
)

for service_info in "${services[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    echo -n "  Testing $service_name: "
    if curl -s "$service_url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ UP${NC}"
    else
        echo -e "❌ DOWN"
    fi
done

echo ""
echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo ""
echo "🌐 Access URLs:"
echo "• Banking API: http://localhost:8080"
echo "• DDoS Detection: http://localhost:5001"
echo "• Auto-Baselining: http://localhost:5002"
echo "• Transaction Monitor: http://localhost:5003"
echo "• Performance Aggregator: http://localhost:5004"
echo "• Anomaly Injector: http://localhost:5005"
echo "• Prometheus: http://localhost:9090"
echo "• Grafana: http://localhost:3000 (admin/bankingdemo)"
echo ""
echo "📊 Dashboards:"
echo "• Banking Overview"
echo "• DDoS Detection"
echo "• Auto-Baselining"
echo "• Transaction Performance"

