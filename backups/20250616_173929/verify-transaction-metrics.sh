#!/bin/bash

echo "🔍 Verifying Transaction Monitoring Metrics"
echo "=========================================="

echo ""
echo "1️⃣ Checking Service Health"
echo "------------------------"
for port in 5003 5004 5005; do
    echo -n "Port $port: "
    curl -s "http://localhost:$port/health" | jq -r '.status // "DOWN"'
done

echo ""
echo "2️⃣ Checking Prometheus Scraping"
echo "-----------------------------"
echo "Active targets:"
curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.job | test("transaction|performance|anomaly")) | "\(.job): \(.health)"' 2>/dev/null || echo "No targets found"

echo ""
echo "3️⃣ Sample Metrics Values"
echo "----------------------"
metrics=(
    "transaction_requests_total"
    "transaction_performance_score"
    "slow_transaction_percentage"
    "active_anomalies"
)

for metric in "${metrics[@]}"; do
    echo -n "$metric: "
    value=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result[0].value[1] // "No data"' 2>/dev/null)
    echo "$value"
done

echo ""
echo "4️⃣ Recent Transactions"
echo "--------------------"
curl -s http://localhost:5003/stats | jq '.'

echo ""
echo "✅ Verification complete!"