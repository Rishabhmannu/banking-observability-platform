#!/bin/bash

echo "🔧 Fixing RabbitMQ Connection Issues"
echo "===================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Check RabbitMQ status
echo "1️⃣ Checking RabbitMQ status..."
if docker exec banking-rabbitmq rabbitmq-diagnostics ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ RabbitMQ is running${NC}"
else
    echo -e "${RED}❌ RabbitMQ is not responding, restarting...${NC}"
    docker restart banking-rabbitmq
    echo "Waiting for RabbitMQ to start..."
    sleep 15
fi

# Step 2: Enable management plugin
echo ""
echo "2️⃣ Ensuring RabbitMQ plugins are enabled..."
docker exec banking-rabbitmq rabbitmq-plugins enable rabbitmq_management rabbitmq_prometheus

# Step 3: Check RabbitMQ users
echo ""
echo "3️⃣ Checking RabbitMQ users..."
docker exec banking-rabbitmq rabbitmqctl list_users

# Step 4: Restart message services
echo ""
echo "4️⃣ Restarting message producer and consumer..."
docker restart banking-message-producer banking-message-consumer

# Wait for services to connect
echo ""
echo "⏳ Waiting for services to reconnect (30 seconds)..."
sleep 30

# Step 5: Check connection status
echo ""
echo "5️⃣ Checking connection status..."
producer_health=$(curl -s http://localhost:5007/health)
echo "Producer health: $producer_health"

consumer_health=$(curl -s http://localhost:5008/health)
echo "Consumer health: $consumer_health"

# Step 6: Test message publishing
echo ""
echo "6️⃣ Testing message publishing..."
echo "Publishing transaction message..."
transaction_result=$(curl -s -X POST http://localhost:5007/publish/transaction)
echo "Result: $transaction_result"

echo ""
echo "Publishing notification message..."
notification_result=$(curl -s -X POST http://localhost:5007/publish/notification)
echo "Result: $notification_result"

# Check if messages are being consumed
echo ""
echo "7️⃣ Checking queue status..."
consumer_status=$(curl -s http://localhost:5008/consumer/status)
echo "Consumer status: $consumer_status"

# Check RabbitMQ Management UI
echo ""
echo "📊 RabbitMQ Management UI: http://localhost:15672"
echo "   Username: admin"
echo "   Password: bankingdemo"

echo ""
echo "✨ Fix complete! Check the results above."