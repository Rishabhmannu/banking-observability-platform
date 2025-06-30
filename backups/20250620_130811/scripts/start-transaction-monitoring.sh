#!/bin/bash

echo "🚀 Starting Transaction Performance Monitoring System"
echo "===================================================="

# Check if existing system is running
if ! docker compose ps | grep -q "prometheus"; then
    echo "⚠️  Base system not running. Starting it first..."
    docker compose up -d
    echo "⏳ Waiting for base system to initialize (60 seconds)..."
    sleep 60
fi

# Start transaction monitoring services
echo "📦 Starting transaction monitoring services..."
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml up -d --build

# Wait for services to start
echo "⏳ Waiting for services to initialize (30 seconds)..."
sleep 30

# Check service health
echo ""
echo "🔍 Checking service health..."

services=("transaction-monitor:5003" "performance-aggregator:5004" "anomaly-injector:5005")
for service in "${services[@]}"; do
    IFS=':' read -r name port <<< "$service"
    echo -n "$name: "
    if curl -s "http://localhost:$port/health" > /dev/null; then
        echo "✅ UP"
    else
        echo "❌ DOWN"
    fi
done

# Update Prometheus configuration if needed
echo ""
echo "📊 Updating Prometheus configuration..."
cat prometheus/prometheus-transaction.yml >> prometheus/prometheus.yml 2>/dev/null || echo "Already configured"

# Reload Prometheus
echo "🔄 Reloading Prometheus configuration..."
curl -X POST http://localhost:9090/-/reload 2>/dev/null || echo "Manual reload may be needed"

echo ""
echo "🌐 Access URLs:"
echo "==============="
echo "📊 Transaction Monitor: http://localhost:5003"
echo "📈 Performance Aggregator: http://localhost:5004"
echo "🎯 Anomaly Injector: http://localhost:5005"
echo "📉 Grafana Dashboard: http://localhost:3000 (admin/bankingdemo)"

echo ""
echo "✨ Transaction monitoring system started successfully!"
echo "📝 Import the dashboard JSON in Grafana to see visualizations"