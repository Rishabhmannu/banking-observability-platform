#!/bin/bash
echo "========================================="
echo "  MEMORY STRESS TEST - Manual Approach"
echo "========================================="
echo "Starting memory pressure simulation..."
echo "Started at: $(date)"

# Method 1: Create memory-consuming containers
echo "Creating memory-hungry containers..."

docker run -d --name memory-hog-1 --memory=512m alpine sh -c 'dd if=/dev/zero of=/tmp/memory.fill bs=1M count=400; sleep 300'
docker run -d --name memory-hog-2 --memory=512m alpine sh -c 'dd if=/dev/zero of=/tmp/memory.fill bs=1M count=400; sleep 300'

# Method 2: Stress the auth service with rapid authentication requests
echo "Generating rapid auth requests to increase memory usage..."

{
    for i in {1..1000}; do
        curl -s -X POST -H "Content-Type: application/json" \
        -d '{"username":"john.doe","password":"password123"}' \
        http://localhost:8080/auth/login > /dev/null
        
        curl -s -X POST -H "Content-Type: application/json" \
        -d '{"username":"jane.smith","password":"password456"}' \
        http://localhost:8080/auth/login > /dev/null
        
        curl -s -X POST -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123"}' \
        http://localhost:8080/auth/login > /dev/null
        
        # Small delay to not overwhelm the system
        sleep 0.1
    done
} &

echo ""
echo "🧠 MEMORY PRESSURE IS NOW ACTIVE! 🧠"
echo "Monitor your tools NOW:"
echo "  - New Relic: Check memory usage for auth service"
echo "  - Datadog: Infrastructure > Containers > Memory metrics"
echo "  - Grafana: Banking Services dashboard > Memory panels"
echo ""
echo "Memory stress will run for 5 minutes, then auto-cleanup"
echo "Or run: ./stop_memory_test.sh to stop early"

# Auto cleanup after 5 minutes
sleep 300
./stop_memory_test.sh
