#!/bin/bash

echo "🔧 Fixing Windows IIS Monitoring..."

# Check if services are defined in any docker-compose file
echo "📋 Checking docker-compose files for Windows services..."
COMPOSE_FILE=""
if grep -q "mock-windows-exporter\|mock-iis-application" docker-compose.yml 2>/dev/null; then
    COMPOSE_FILE="docker-compose.yml"
elif grep -q "mock-windows-exporter\|mock-iis-application" docker-compose.override.yml 2>/dev/null; then
    COMPOSE_FILE="docker-compose.override.yml"
else
    echo "⚠️  Windows services not found in main compose files, creating override..."
    
    # Create docker-compose.override.yml with Windows services
    cat > docker-compose.override.yml << 'EOF'
version: '3.8'

services:
  # Mock Windows Exporter (simulates Windows metrics)
  mock-windows-exporter:
    build: ./mock-windows-exporter
    container_name: mock-windows-exporter
    ports:
      - "9182:9182"
    environment:
      - EXPORT_INTERVAL=10
    networks:
      - banking-network
    restart: unless-stopped

  # Mock IIS Application 
  mock-iis-application:
    build: ./mock-iis-application
    container_name: mock-iis-application
    ports:
      - "8088:8088"
    environment:
      - ENABLE_METRICS=true
    networks:
      - banking-network
    restart: unless-stopped
EOF
    COMPOSE_FILE="docker-compose.yml -f docker-compose.override.yml"
fi

# Start the Windows services
echo "🚀 Starting Windows monitoring services..."
docker-compose $COMPOSE_FILE up -d mock-windows-exporter mock-iis-application

# Wait for services to start
echo "⏳ Waiting for services to initialize..."
sleep 10

# Check if services are running
echo "📊 Checking service status..."
docker ps | grep -E "mock-windows-exporter|mock-iis-application"

# Check if metrics are available
echo ""
echo "🔍 Checking Windows metrics endpoint..."
curl -s http://localhost:9182/metrics | grep -E "windows_|iis_" | head -5 || echo "❌ No Windows metrics found"

echo ""
echo "🔍 Checking IIS application metrics..."
curl -s http://localhost:8088/metrics | grep -E "iis_|http_" | head -5 || echo "❌ No IIS metrics found"

# Check Prometheus configuration
echo ""
echo "📋 Checking if Prometheus is configured to scrape Windows metrics..."
PROMETHEUS_CONFIG="./prometheus/prometheus.yml"

if ! grep -q "mock-windows-exporter\|windows-exporter" "$PROMETHEUS_CONFIG"; then
    echo "⚠️  Prometheus not configured for Windows metrics. Adding configuration..."
    
    # Backup current config
    cp "$PROMETHEUS_CONFIG" "$PROMETHEUS_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Add Windows scrape configs
    cat >> "$PROMETHEUS_CONFIG" << 'EOF'

  # Windows IIS Monitoring
  - job_name: 'windows-exporter'
    static_configs:
      - targets: ['mock-windows-exporter:9182']
    scrape_interval: 15s

  - job_name: 'iis-application'
    static_configs:
      - targets: ['mock-iis-application:8088']
    metrics_path: '/metrics'
    scrape_interval: 10s
EOF
    
    echo "✅ Added Windows monitoring to Prometheus config"
    echo "🔄 Reloading Prometheus..."
    docker-compose restart prometheus
    sleep 5
fi

# Force Prometheus to reload
echo ""
echo "🔄 Forcing Prometheus to reload configuration..."
curl -X POST http://localhost:9090/-/reload 2>/dev/null || docker-compose restart prometheus

# Wait for Prometheus to reload
sleep 10

# Verify in Prometheus
echo ""
echo "✅ Checking Prometheus targets..."
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("windows") or contains("iis")) | {job: .labels.job, health: .health}'

# Check if metrics are being scraped
echo ""
echo "📊 Verifying metrics in Prometheus..."
echo "Windows CPU Usage:"
curl -s "http://localhost:9090/api/v1/query?query=windows_cpu_usage_percent" | jq '.data.result[0].value[1]' 2>/dev/null || echo "No data"

echo "IIS Request Rate:"
curl -s "http://localhost:9090/api/v1/query?query=iis_request_rate" | jq '.data.result[0].value[1]' 2>/dev/null || echo "No data"

echo ""
echo "🎉 Windows IIS monitoring should now be working!"
echo "📈 Refresh your Grafana dashboard in 30 seconds to see the metrics."
echo ""
echo "If still not working, check the logs:"
echo "  docker logs mock-windows-exporter"
echo "  docker logs mock-iis-application"