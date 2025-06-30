#!/bin/bash
echo "========================================="
echo "  NETWORK LATENCY TEST - Manual Approach"
echo "========================================="
echo "Starting network latency simulation..."
echo "Started at: $(date)"

# Create artificial network delays by overwhelming notification service
echo "Generating high-frequency notification requests..."

for i in {1..10}; do
    {
        while true; do
            # Rapidly hit notification endpoints
            curl -s http://localhost:8080/notifications/history/1 > /dev/null
            curl -s http://localhost:8080/notifications/history/2 > /dev/null
            curl -s http://localhost:8080/notifications/history/3 > /dev/null
            
            # Send notifications
            curl -s -X POST -H "Content-Type: application/json" \
            -d '{"userId":1,"message":"High frequency test notification"}' \
            http://localhost:8080/notifications/send > /dev/null
            
            # Very small delay - overwhelm the service
            sleep 0.05
        done
    } &
    echo $! >> /tmp/latency_pids.txt
done

echo ""
echo "🌐 NETWORK LATENCY SIMULATION IS ACTIVE! 🌐"
echo "Monitor your tools NOW:"
echo "  - New Relic: Check response time for notification endpoints"  
echo "  - Datadog: APM > Services > Response times"
echo "  - Grafana: API Response Time panels"
echo ""
echo "Press Ctrl+C to stop, or run: ./stop_latency_test.sh"

trap 'echo "Stopping latency test..."; kill $(cat /tmp/latency_pids.txt 2>/dev/null); rm -f /tmp/latency_pids.txt; exit' INT
wait
