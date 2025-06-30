#!/bin/bash

# Database Activity Generator
# This script generates database activity to observe connection pool metrics

echo "🔄 Starting Database Activity Generator"
echo "======================================="
echo "This will run for 90 seconds and generate database load"
echo ""

# Function to check current metrics
check_metrics() {
    echo -n "Pool Utilization: "
    curl -s http://localhost:5009/metrics | grep "banking_db_pool_utilization_percent" | grep -v "^#" | awk '{print $2"%"}'
    echo -n "Active Connections: "
    curl -s http://localhost:5009/metrics | grep "banking_db_pool_connections_active" | grep -v "^#" | awk '{print $2}'
    echo -n "Idle Connections: "
    curl -s http://localhost:5009/metrics | grep "banking_db_pool_connections_idle" | grep -v "^#" | awk '{print $2}'
    echo ""
}

# Check initial state
echo "📊 Initial metrics:"
check_metrics

# Start time
start_time=$(date +%s)
end_time=$((start_time + 90))

echo "🚀 Starting load generation..."
echo "Watch your Grafana dashboard at: http://localhost:3000"
echo ""

# Generate parallel database activity
while [ $(date +%s) -lt $end_time ]; do
    # Run 5 parallel requests
    for i in {1..5}; do
        {
            # Trigger database queries through the service
            curl -s http://localhost:5009/health > /dev/null
            
            # If there's a query endpoint, use it
            # You might need to check what endpoints are available
            # curl -s http://localhost:5009/query > /dev/null
        } &
    done
    
    # Check metrics every 10 seconds
    if [ $(($(date +%s) % 10)) -eq 0 ]; then
        echo "📊 Current metrics ($(date +%T)):"
        check_metrics
    fi
    
    # Small delay to prevent overwhelming
    sleep 0.2
done

# Wait for background jobs
wait

echo ""
echo "✅ Load generation complete!"
echo ""
echo "📊 Final metrics:"
check_metrics

echo ""
echo "💡 Check your Grafana dashboard to see the metrics changes:"
echo "   http://localhost:3000/d/banking-db-connection"