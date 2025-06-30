#!/bin/bash

echo "🎬 Quick Transaction Monitoring Demo"
echo "==================================="

# Start services if not running
if ! curl -s http://localhost:5003/health > /dev/null; then
    echo "Starting transaction monitoring services..."
    ./start-transaction-monitoring.sh
    sleep 30
fi

echo ""
echo "📊 Phase 1: Generate Normal Traffic"
echo "--------------------------------"
./simulate-realistic-traffic.sh &
TRAFFIC_PID=$!

sleep 30

echo ""
echo "🎯 Phase 2: Inject Anomalies"
echo "-------------------------"
echo "Injecting latency anomaly..."
curl -s -X POST http://localhost:5005/inject/latency \
    -H "Content-Type: application/json" \
    -d '{
        "target": "transaction-service",
        "delay_ms": 800,
        "probability": 0.3,
        "duration_minutes": 2
    }' > /dev/null

echo "✅ Latency injection active"

sleep 30

echo "Injecting failure anomaly..."
curl -s -X POST http://localhost:5005/inject/failure \
    -H "Content-Type: application/json" \
    -d '{
        "target": "transaction-service",
        "error_code": 500,
        "probability": 0.1,
        "duration_minutes": 2
    }' > /dev/null

echo "✅ Failure injection active"

echo ""
echo "📈 Demo Running!"
echo "==============="
echo ""
echo "👀 What to observe in Grafana:"
echo "1. Request Count - should show steady traffic"
echo "2. Request Failures - will spike after failure injection"
echo "3. Avg Response Time - will increase after latency injection"
echo "4. Slow Requests % - will increase significantly"
echo "5. Anomaly Score - should detect the unusual patterns"
echo ""
echo "🌐 Open: http://localhost:3000"
echo "📊 Dashboard: Transaction Performance Monitoring"
echo ""
echo "Press Ctrl+C to stop the demo"

# Keep running until interrupted
wait $TRAFFIC_PID