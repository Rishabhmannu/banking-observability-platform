#!/bin/bash

echo "🔍 Debugging Prometheus Target Discovery"
echo "======================================="

echo ""
echo "1️⃣ Container Network Status"
echo "-------------------------"
echo "Transaction monitoring containers:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(transaction|performance|anomaly)" || echo "No containers found"

echo ""
echo "2️⃣ Network Connectivity Test"
echo "--------------------------"
echo "Testing from Prometheus container:"
docker exec prometheus sh -c 'wget -q -O- http://transaction-monitor:5003/metrics | head -5' 2>/dev/null || echo "Cannot reach transaction-monitor from Prometheus"

echo ""
echo "3️⃣ Current Prometheus Config"
echo "--------------------------"
echo "Scrape configs for transaction services:"
grep -A 5 -E "(transaction-monitor|performance-aggregator|anomaly-injector)" prometheus/prometheus.yml || echo "No transaction configs found"

echo ""
echo "4️⃣ Prometheus Targets API"
echo "-----------------------"
echo "All active targets:"
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .job, instance: .instance, health: .health}' | head -20

echo ""
echo "5️⃣ Direct Metrics Check"
echo "---------------------"
echo "Transaction Monitor metrics endpoint:"
curl -s http://localhost:5003/metrics | grep -E "^transaction_" | head -5 || echo "No metrics found"

echo ""
echo "✅ Debug info collected"