#!/bin/bash

echo "🔧 Updating Prometheus Configuration"
echo "===================================="

# Backup current prometheus.yml
echo "📋 Backing up current prometheus.yml..."
cp prometheus/prometheus.yml prometheus/prometheus.yml.backup.$(date +%Y%m%d_%H%M%S)

# Check if transaction monitoring jobs already exist
if grep -q "transaction-monitor" prometheus/prometheus.yml; then
    echo "✅ Transaction monitoring jobs already configured"
else
    echo "📝 Adding transaction monitoring scrape configs..."
    
    # Append the new scrape configs
    cat >> prometheus/prometheus.yml << 'EOF'

  # Transaction monitoring services
  - job_name: 'transaction-monitor'
    static_configs:
      - targets: ['transaction-monitor:5003']
    metrics_path: '/metrics'
    scrape_interval: 10s

  - job_name: 'performance-aggregator'
    static_configs:
      - targets: ['performance-aggregator:5004']
    metrics_path: '/metrics'
    scrape_interval: 15s

  - job_name: 'anomaly-injector'
    static_configs:
      - targets: ['anomaly-injector:5005']
    metrics_path: '/metrics'
    scrape_interval: 10s
EOF

    echo "✅ Configuration updated"
fi

echo ""
echo "🔄 Reloading Prometheus configuration..."

# Try to reload Prometheus
reload_response=$(curl -X POST http://localhost:9090/-/reload 2>&1)
reload_status=$?

if [ $reload_status -eq 0 ]; then
    echo "✅ Prometheus configuration reloaded successfully"
else
    echo "⚠️  Couldn't reload Prometheus via API, restarting container..."
    docker compose restart prometheus
    echo "⏳ Waiting for Prometheus to restart (30 seconds)..."
    sleep 30
fi

echo ""
echo "🔍 Verifying new targets..."
sleep 5

# Check if new targets are being scraped
echo "Checking Prometheus targets:"
new_targets=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.job | test("transaction|performance|anomaly")) | "\(.job): \(.health)"' 2>/dev/null)

if [ ! -z "$new_targets" ]; then
    echo "✅ New targets found:"
    echo "$new_targets"
else
    echo "❌ No new targets found yet. Checking container names..."
    
    # Debug: Check if containers are running with correct names
    echo ""
    echo "🐳 Docker containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(transaction|performance|anomaly)"
fi

echo ""
echo "✨ Configuration update complete!"
echo ""
echo "📝 Next steps:"
echo "1. Wait 1-2 minutes for metrics to accumulate"
echo "2. Run: ./simulate-realistic-traffic.sh"
echo "3. Check Grafana dashboard again"