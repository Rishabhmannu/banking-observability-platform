#!/bin/bash

# Message Queue Metrics Tester
# This script demonstrates message queue behavior by controlling the consumer

echo "📨 Message Queue Metrics Tester"
echo "================================"
echo "This script will demonstrate queue depth changes by pausing the consumer"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check queue metrics
check_queue_metrics() {
    echo -e "\n${YELLOW}📊 Current Queue Depths:${NC}"
    curl -s http://localhost:5008/metrics | grep "banking_unprocessed_messages" | grep -v "^#" | while read line; do
        queue=$(echo $line | grep -o 'queue_topic="[^"]*"' | cut -d'"' -f2)
        value=$(echo $line | awk '{print $2}' | cut -d'.' -f1)
        if [ "$value" -gt 0 ]; then
            echo -e "  ${RED}$queue: $value messages${NC}"
        else
            echo -e "  ${GREEN}$queue: $value messages${NC}"
        fi
    done
}

# Function to check message rates
check_message_rates() {
    echo -e "\n${YELLOW}📈 Message Publishing Rate (last minute):${NC}"
    
    # Get current totals
    curl -s http://localhost:5007/metrics | grep "messages_published_total" | grep -v "^#" > /tmp/msg_current.txt
    
    # Calculate rates (rough estimate based on totals)
    while read line; do
        queue=$(echo $line | grep -o 'queue_topic="[^"]*"' | cut -d'"' -f2)
        total=$(echo $line | awk '{print $2}' | cut -d'.' -f1)
        echo "  $queue: ~$(( total / 60 )) msgs/min (total: $total)"
    done < /tmp/msg_current.txt
    
    rm -f /tmp/msg_current.txt
}

# Function to check consumer status
check_consumer_status() {
    if docker ps | grep -q "banking-message-consumer"; then
        echo -e "${GREEN}✅ Message Consumer: RUNNING${NC}"
        return 0
    else
        echo -e "${RED}❌ Message Consumer: STOPPED${NC}"
        return 1
    fi
}

# Initial state
echo -e "${YELLOW}📋 Initial State:${NC}"
check_consumer_status
check_queue_metrics
check_message_rates

echo -e "\n${YELLOW}Press Enter to PAUSE the message consumer and watch queues build up...${NC}"
read -r

# Stop consumer
echo -e "\n${RED}⏸️  Stopping message consumer...${NC}"
docker stop banking-message-consumer > /dev/null 2>&1

# Monitor queue buildup
echo -e "\n${YELLOW}📈 Monitoring queue buildup for 30 seconds...${NC}"
echo "Watch your Grafana dashboard: http://localhost:3000"

for i in {1..6}; do
    sleep 5
    echo -e "\n⏱️  After $((i*5)) seconds:"
    check_queue_metrics
done

echo -e "\n${YELLOW}Press Enter to RESTART the consumer and watch queues drain...${NC}"
read -r

# Restart consumer
echo -e "\n${GREEN}▶️  Starting message consumer...${NC}"
docker start banking-message-consumer > /dev/null 2>&1

# Monitor queue drain
echo -e "\n${YELLOW}📉 Monitoring queue drain for 30 seconds...${NC}"

for i in {1..6}; do
    sleep 5
    echo -e "\n⏱️  After $((i*5)) seconds:"
    check_queue_metrics
done

# Final state
echo -e "\n${YELLOW}📋 Final State:${NC}"
check_consumer_status
check_queue_metrics

echo -e "\n${GREEN}✅ Test complete!${NC}"
echo ""
echo "💡 Key observations:"
echo "  1. When consumer is stopped, unprocessed messages accumulate"
echo "  2. When consumer is restarted, it processes the backlog"
echo "  3. The dashboard shows these changes in real-time"
echo ""
echo "📊 Check your Message Queue dashboard to see the history:"
echo "   http://localhost:3000/d/banking-message-queue"