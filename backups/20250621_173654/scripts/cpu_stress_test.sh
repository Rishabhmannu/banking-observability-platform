#!/bin/bash
echo "========================================="
echo "  CPU STRESS TEST - Manual Approach"
echo "========================================="
echo "Starting high CPU load simulation..."
echo "Started at: $(date)"

# Create multiple background processes to consume CPU
echo "Creating 20 concurrent traffic generators..."

for i in {1..20}; do
    {
        echo "Starting background process $i"
        while true; do
            # Mix of different API calls to stress multiple services
            curl -s http://localhost:8080/accounts/accounts > /dev/null
            curl -s http://localhost:8080/transactions/transactions > /dev/null
            curl -s -X POST -H "Content-Type: application/json" \
            -d '{"username":"john.doe","password":"password123"}' \
            http://localhost:8080/auth/login > /dev/null
            curl -s -X POST -H "Content-Type: application/json" \
            -d '{"accountId":1,"amount":100,"type":"DEPOSIT"}' \
            http://localhost:8080/transactions/transactions > /dev/null
            curl -s http://localhost:8080/notifications/history/1 > /dev/null
        done
    } &
    # Store the PID for cleanup
    echo $! >> /tmp/stress_pids.txt
done

echo ""
echo "🔥 HIGH CPU LOAD IS NOW ACTIVE! 🔥"
echo "Monitor your tools NOW:"
echo "  - New Relic: Check CPU usage charts"
echo "  - Datadog: Infrastructure > Containers > CPU metrics" 
echo "  - Grafana: Banking Services dashboard > CPU panels"
echo ""
echo "Press Ctrl+C to stop the stress test"
echo "Or run: ./stop_stress_test.sh"

# Keep the script running until interrupted
trap 'echo "Stopping stress test..."; kill $(cat /tmp/stress_pids.txt 2>/dev/null); rm -f /tmp/stress_pids.txt; exit' INT
wait
