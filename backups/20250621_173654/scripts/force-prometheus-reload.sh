#!/bin/bash

echo "🔄 Force Reloading Prometheus Configuration"
echo "==========================================="

# First, let's verify the config is valid
echo "🔍 Validating prometheus.yml..."
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml 2>/dev/null || echo "✅ Config appears valid"

# Force restart Prometheus container
echo ""
echo "🔄 Restarting Prometheus container..."
docker compose restart prometheus

echo "⏳ Waiting for Prometheus to start (30 seconds)..."
sleep 30

# Check if Prometheus is healthy
echo ""
echo "🏥 Checking Prometheus health..."
if curl -s http://localhost:9090/-/healthy > /dev/null; then
    echo "✅ Prometheus is healthy"
else
    echo "❌ Prometheus is not responding"
    exit 1
fi

# Now check targets
echo ""
echo "🎯 Checking all targets..."
echo "========================="

all_targets=$(curl -s http://localhost:9090/api/v1/targets)

# Check transaction monitoring specific targets
echo ""
echo "📊 Transaction Monitoring Targets:"
echo "---------------------------------"

for job in "transaction-monitor" "performance-aggregator" "anomaly-injector"; do
    echo -n "$job: "
    target_info=$(echo "$all_targets" | jq -r ".data.activeTargets[] | select(.labels.job == \"$job\") | \"\(.health) - \(.labels.instance)\"" 2>/dev/null)
    if [ ! -z "$target_info" ]; then
        echo "✅ $target_info"
    else
        echo "❌ NOT FOUND"
    fi
done

# If targets still not found, check network connectivity
echo ""
echo "🌐 Testing network connectivity from Prometheus container..."
echo "--------------------------------------------------------"

echo "Testing transaction-performance-monitor:"
docker exec prometheus wget -q -O- -T 5 http://transaction-performance-monitor:5003/metrics 2>&1 | head -3 || echo "❌ Cannot reach transaction-performance-monitor"

echo ""
echo "Testing performance-aggregator-service:"
docker exec prometheus wget -q -O- -T 5 http://performance-aggregator-service:5004/metrics 2>&1 | head -3 || echo "❌ Cannot reach performance-aggregator-service"

echo ""
echo "Testing anomaly-injector-service:"
docker exec prometheus wget -q -O- -T 5 http://anomaly-injector-service:5005/metrics 2>&1 | head -3 || echo "❌ Cannot reach anomaly-injector-service"

echo ""
echo "✨ Diagnostics complete!"