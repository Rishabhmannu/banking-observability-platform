#!/bin/bash

echo "🌐 Fixing Docker Network Configuration"
echo "====================================="

# List all containers and their networks
echo "📋 Current container networks:"
docker inspect prometheus transaction-performance-monitor performance-aggregator-service anomaly-injector-service 2>/dev/null | jq -r '.[] | "\(.Name): \(.NetworkSettings.Networks | keys | join(", "))"'

# Ensure all containers are on banking-network
echo ""
echo "🔧 Connecting all containers to banking-network..."

for container in prometheus transaction-performance-monitor performance-aggregator-service anomaly-injector-service; do
    echo -n "Connecting $container: "
    docker network connect banking-network $container 2>/dev/null && echo "✅ Connected" || echo "✅ Already connected"
done

# Restart Prometheus to pick up network changes
echo ""
echo "🔄 Restarting Prometheus..."
docker restart prometheus

echo "⏳ Waiting 20 seconds..."
sleep 20

# Test again
echo ""
echo "🧪 Testing connectivity again..."
docker exec prometheus wget -q -O- -T 5 http://transaction-performance-monitor:5003/health | jq '.' || echo "Still cannot connect"

echo ""
echo "✨ Network fix complete!"