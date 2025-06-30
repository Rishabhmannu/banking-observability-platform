#!/bin/bash

# Emergency fix for Docker Compose issues
# This script does the absolute minimum to get the system running

echo "🚑 Emergency Docker Compose Fix"
echo "=============================="

# 1. Add missing volumes to docker-compose.yml
echo "📝 Adding missing volumes..."
if ! grep -q "grafana-storage:" docker-compose.yml; then
    # Remove any incomplete volumes section at the end
    sed -i '/^volumes:$/,$d' docker-compose.yml
    
    # Add complete volumes section
    echo "" >> docker-compose.yml
    echo "volumes:" >> docker-compose.yml
    echo "  mysql-data:" >> docker-compose.yml
    echo "  prometheus-data:" >> docker-compose.yml
    echo "  grafana-storage:" >> docker-compose.yml
    echo "✅ Volumes added"
else
    echo "✅ Volumes already present"
fi

# 2. Create the external network
echo "🌐 Creating network..."
docker network create ddos-detection-system_banking-network 2>/dev/null || echo "✅ Network already exists"

# 3. Stop everything cleanly
echo "🛑 Stopping all services..."
docker compose down 2>/dev/null || true

echo ""
echo "✅ Emergency fixes applied!"
echo ""
echo "Now run: ./safe_restart5.sh"