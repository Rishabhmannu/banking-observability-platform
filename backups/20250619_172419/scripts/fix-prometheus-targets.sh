#!/bin/bash

echo "🔧 Fixing Prometheus Target Configuration"
echo "========================================"

# Backup current config
echo "📋 Backing up prometheus.yml..."
cp prometheus/prometheus.yml prometheus/prometheus.yml.backup.$(date +%Y%m%d_%H%M%S)

# Create corrected prometheus.yml
echo "📝 Creating corrected configuration..."

# First, remove the duplicate entries
sed -i '/# Additional scrape configs for transaction monitoring/,$d' prometheus/prometheus.yml 2>/dev/null || \
sed -i '' '/# Additional scrape configs for transaction monitoring/,$d' prometheus/prometheus.yml

# Now update the target names to match actual container names
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' 's/transaction-monitor:5003/transaction-performance-monitor:5003/g' prometheus/prometheus.yml
    sed -i '' 's/performance-aggregator:5004/performance-aggregator-service:5004/g' prometheus/prometheus.yml
    sed -i '' 's/anomaly-injector:5005/anomaly-injector-service:5005/g' prometheus/prometheus.yml
else
    # Linux
    sed -i 's/transaction-monitor:5003/transaction-performance-monitor:5003/g' prometheus/prometheus.yml
    sed -i 's/performance-aggregator:5004/performance-aggregator-service:5004/g' prometheus/prometheus.yml
    sed -i 's/anomaly-injector:5005/anomaly-injector-service:5005/g' prometheus/prometheus.yml
fi

echo "✅ Configuration updated with correct container names"

echo ""
echo "🔄 Reloading Prometheus..."
curl -X POST http://localhost:9090/-/reload 2>/dev/null || docker compose restart prometheus

echo "⏳ Waiting for Prometheus to reload (15 seconds)..."
sleep 15

echo ""
echo "🔍 Verifying targets are now active..."
echo "Current targets:"

# Check specific transaction monitoring targets
targets=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job | test("transaction|performance|anomaly")) | "\(.labels.job): \(.health) (\(.labels.instance))"' 2>/dev/null)

if [ ! -z "$targets" ]; then
    echo -e "✅ Active targets found:\n$targets"
else
    echo "⚠️  Still no targets. Checking all targets..."
    curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
fi

echo ""
echo "📊 Checking if metrics are being scraped..."

# Wait a bit more for scraping
sleep 10

# Check for actual metrics
for metric in "transaction_requests_total" "transaction_performance_score" "slow_transaction_percentage"; do
    echo -n "$metric: "
    value=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result[0].value[1] // "No data"' 2>/dev/null)
    if [ "$value" != "No data" ]; then
        echo "✅ $value"
    else
        echo "❌ No data"
    fi
done

echo ""
echo "✨ Fix complete!"
echo ""
echo "If metrics are still showing 'No data':"
echo "1. Run: ./generate-initial-metrics.sh"
echo "2. Wait 1 minute"
echo "3. Refresh Grafana dashboard"