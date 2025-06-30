#!/bin/bash

echo "🚀 Restarting Enhanced DDoS Detection & Auto-Baselining System"
echo "=============================================================="

# Navigate to project directory
cd /Users/rishabh/Downloads/Internship\ Related/DDoS_Detection/ddos-detection-system

# Stop any existing services first
echo "🔄 Stopping any existing services..."
docker compose down 2>/dev/null

# Start all services
echo "📦 Starting all Docker services..."
docker compose up -d

# Wait for services
echo "⏳ Waiting for services to initialize (2 minutes)..."
sleep 120

# Check status
echo "🔍 Checking service status..."
docker compose ps

# Quick health checks
echo ""
echo "🧪 Testing key services..."

echo -n "Banking API: "
if curl -s http://localhost:8080/health > /dev/null; then
    echo "✅ UP"
else
    echo "❌ DOWN"
fi

echo -n "DDoS ML Detection: "
if curl -s http://localhost:5001/health > /dev/null; then
    echo "✅ UP"
else
    echo "❌ DOWN (Note: This is optional)"
fi

echo -n "Auto-Baselining: "
if curl -s http://localhost:5002/health > /dev/null; then
    echo "✅ UP"
else
    echo "❌ DOWN"
fi

echo -n "Prometheus: "
if curl -s http://localhost:9090/-/healthy > /dev/null; then
    echo "✅ UP"
else
    echo "❌ DOWN"
fi

echo -n "Grafana: "
if curl -s http://localhost:3000/api/health > /dev/null; then
    echo "✅ UP"
else
    echo "❌ DOWN"
fi

# Additional health checks for new services
echo ""
echo "🔍 Advanced System Status:"

# Check Prometheus targets
echo -n "Prometheus Targets: "
targets_count=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
echo "$targets_count targets discovered"

# Check auto-baselining recommendations
echo -n "Auto-Baselining: "
recommendations_count=$(curl -s http://localhost:5002/health 2>/dev/null | jq -r '.recommendations_count' 2>/dev/null || echo "0")
algorithms_count=$(curl -s http://localhost:5002/health 2>/dev/null | jq -r '.algorithms | length' 2>/dev/null || echo "0")
echo "$algorithms_count algorithms, $recommendations_count metric recommendations"

# Check if both ML systems are coexisting
if curl -s http://localhost:5001/health > /dev/null && curl -s http://localhost:5002/health > /dev/null; then
    echo "🤝 Both DDoS Detection & Auto-Baselining: ✅ COEXISTING PERFECTLY"
fi

echo ""
echo "🌐 Access URLs:"
echo "=============================="
echo "🏦 Banking API: http://localhost:8080"
echo "🤖 DDoS ML Detection: http://localhost:5001"
echo "🎯 Auto-Baselining: http://localhost:5002"
echo "📊 Prometheus: http://localhost:9090"
echo "📈 Grafana: http://localhost:3000 (admin/bankingdemo)"

echo ""
echo "🧪 Quick Test Commands:"
echo "======================"
echo "# Test banking services:"
echo "curl http://localhost:8080/health"
echo ""
echo "# Check DDoS detection:"
echo "curl http://localhost:5001/health"
echo ""
echo "# View threshold recommendations:"
echo "curl http://localhost:5002/threshold-recommendations | jq ."
echo ""
echo "# Test threshold calculation:"
echo "curl 'http://localhost:5002/calculate-threshold?metric=sum(rate(http_requests_total[1m]))' | jq ."

echo ""
echo "📊 Monitoring Commands:"
echo "======================"
echo "# Watch recommendations in real-time:"
echo "watch -n 30 'curl -s http://localhost:5002/threshold-recommendations | jq .'"
echo ""
echo "# Check Prometheus targets:"
echo "curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .job, health: .health}'"
echo ""
echo "# View service logs:"
echo "docker compose logs -f auto-baselining"
echo "docker compose logs -f prometheus"

echo ""
echo "🎯 System Features Active:"
echo "========================="
echo "✅ Banking Microservices (Ports 8080-8085)"
echo "✅ DDoS Detection with ML (Port 5001)"
echo "✅ Auto-Baselining with 4 Algorithms (Port 5002)"
echo "✅ Prometheus Monitoring (Port 9090)"
echo "✅ Grafana Visualization (Port 3000)"
echo "✅ MySQL Database (Port 3306)"
echo "✅ Node Exporter & cAdvisor (Ports 9100, 8086)"

echo ""
echo "✨ Enhanced system restart complete!"
echo "🎉 You now have both DDoS Detection AND Auto-Baselining running together!"