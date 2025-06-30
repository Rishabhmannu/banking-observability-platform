#!/bin/bash

echo "📊 Checking Metrics Collection Status"
echo "===================================="

# Wait a bit for Prometheus to update health status
echo "⏳ Waiting 30 seconds for Prometheus to update target health..."
sleep 30

echo ""
echo "🎯 Current Target Status:"
echo "------------------------"
curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job | test("transaction|performance|anomaly")) | "\(.labels.job): \(.health) (\(.lastScrape))"'

echo ""
echo "📈 Checking if metrics are now available:"
echo "----------------------------------------"

# Check key metrics
metrics=(
    "transaction_requests_total"
    "transaction_performance_score"
    "slow_transaction_percentage"
    "active_anomalies"
    "anomaly_injections_total"
    "aggregation_calculations_total"
)

for metric in "${metrics[@]}"; do
    echo -n "$metric: "
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result | length' 2>/dev/null)
    if [ "$result" -gt 0 ] 2>/dev/null; then
        value=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result[0].value[1]' 2>/dev/null)
        echo "✅ Found ($value)"
    else
        echo "❌ No data"
    fi
done

echo ""
echo "🔄 Generating fresh traffic to populate metrics..."
echo "------------------------------------------------"

# Generate some transactions
for i in {1..20}; do
    curl -s -X POST http://localhost:5003/simulate-transaction \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"transfer\",
            \"duration\": 0.3,
            \"status\": \"success\"
        }" > /dev/null
done

echo "✅ Sent 20 test transactions"

# Trigger calculations
curl -s -X POST http://localhost:5004/trigger-calculation \
    -H "Content-Type: application/json" \
    -d '{"type": "all"}' > /dev/null

echo "✅ Triggered aggregation calculations"

# Wait for metrics to be scraped
echo ""
echo "⏳ Waiting 20 seconds for metrics to be scraped..."
sleep 20

echo ""
echo "📊 Final metrics check:"
echo "----------------------"

# Check metrics again
for metric in "transaction_requests_total" "transaction_performance_score"; do
    echo -n "$metric: "
    result=$(curl -s "http://localhost:9090/api/v1/query?query=$metric")
    value=$(echo "$result" | jq -r '.data.result[0].value[1] // "No data"' 2>/dev/null)
    if [ "$value" != "No data" ]; then
        echo "✅ $value"
    else
        echo "❌ Still no data"
        # Show the raw result for debugging
        echo "  Debug: $(echo "$result" | jq -c '.status,.data.result | length' 2>/dev/null)"
    fi
done

echo ""
echo "🌐 Quick Links:"
echo "--------------"
echo "• Prometheus Targets: http://localhost:9090/targets"
echo "• Prometheus Graph: http://localhost:9090/graph"
echo "  (Search for 'transaction_requests_total')"
echo "• Grafana Dashboard: http://localhost:3000"
echo ""
echo "If metrics are still not showing:"
echo "1. Check http://localhost:9090/targets - look for transaction-monitor job"
echo "2. Click on the endpoint URL to see the raw metrics"
echo "3. In Grafana, edit a panel and use the query browser to test queries"