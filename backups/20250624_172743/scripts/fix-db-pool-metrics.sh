#!/bin/bash

echo "🔧 Fixing Database Connection Pool Metrics"
echo "========================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Check PostgreSQL
echo "1️⃣ Checking PostgreSQL status..."
if docker exec banking-postgres pg_isready -U bankinguser > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL is ready${NC}"
else
    echo -e "${RED}❌ PostgreSQL is not ready${NC}"
    exit 1
fi

# Step 2: Check db-connection-demo service
echo ""
echo "2️⃣ Checking db-connection-demo service..."
demo_health=$(curl -s http://localhost:5009/health | jq -r '.status // "unknown"')
if [ "$demo_health" = "UP" ]; then
    echo -e "${GREEN}✅ DB Connection Demo is healthy${NC}"
else
    echo -e "${RED}❌ DB Connection Demo is not healthy${NC}"
    echo "Restarting service..."
    docker restart banking-db-connection-demo
    sleep 10
fi

# Step 3: Check current pool status
echo ""
echo "3️⃣ Current pool status:"
curl -s http://localhost:5009/pool/status | jq '.'

# Step 4: Check if background operations are running
echo ""
echo "4️⃣ Checking if background operations are generating activity..."
echo "Looking at recent logs:"
docker logs banking-db-connection-demo --tail 20 | grep -E "(Operation error|Acquired connection|Released)"

# Step 5: Trigger manual database activity
echo ""
echo "5️⃣ Triggering database activity..."

# Run stress test
echo "Running connection pool stress test..."
curl -s -X POST http://localhost:5009/pool/stress-test | jq '.'

# Wait for stress test to run
echo "Waiting for stress test to execute..."
sleep 10

# Check pool status again
echo ""
echo "6️⃣ Pool status after stress test:"
curl -s http://localhost:5009/pool/status | jq '.'

# Check metrics
echo ""
echo "7️⃣ Checking Prometheus metrics:"
echo "Active connections:"
curl -s http://localhost:5009/metrics | grep -E "banking_db_pool_connections_active|banking_db_pool_utilization_percent" | grep -v "#"

# Generate continuous load
echo ""
echo "8️⃣ Starting continuous database load..."
echo "This will generate database queries for 30 seconds..."

for i in {1..30}; do
    # Silently trigger some database activity
    curl -s http://localhost:5009/pool/status > /dev/null
    echo -n "."
    sleep 1
done
echo ""

# Final check
echo ""
echo "9️⃣ Final pool status:"
curl -s http://localhost:5009/pool/status | jq '.'

echo ""
echo "🔍 Debugging tips:"
echo "================="
echo "1. Check if operations are running:"
echo "   docker logs banking-db-connection-demo --tail 50"
echo ""
echo "2. Check raw metrics:"
echo "   curl http://localhost:5009/metrics | grep banking_db"
echo ""
echo "3. Restart if needed:"
echo "   docker restart banking-db-connection-demo"
echo ""
echo "✨ Fix complete!"