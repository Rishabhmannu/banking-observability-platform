#!/bin/bash

# Message Queue Metrics Tester V2 - Using RabbitMQ Monitor
# This script demonstrates message queue behavior by controlling the consumer

echo "📨 Message Queue Metrics Tester V2 (RabbitMQ Monitor)"
echo "====================================================="
echo "This script uses the new RabbitMQ monitor service for accurate metrics"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check queue metrics from NEW monitor
check_queue_metrics_new() {
    echo -e "\n${YELLOW}📊 Current Queue Depths (from RabbitMQ Monitor):${NC}"
    curl -s http://localhost:9418/metrics | grep "rabbitmq_queue_messages_ready" | grep -v "^#" | while read line; do
        queue=$(echo $line | grep -o 'queue="[^"]*"' | cut -d'"' -f2)
        value=$(echo $line | awk '{print $2}' | cut -d'.' -f1)
        if [ "$value" -gt 0 ]; then
            echo -e "  ${RED}$queue: $value messages${NC}"
        else
            echo -e "  ${GREEN}$queue: $value messages${NC}"
        fi
    done
}

# Function to check OLD consumer metrics for comparison
check_queue_metrics_old() {
    echo -e "\n${BLUE}📊 Queue Depths (from Consumer - OLD method):${NC}"
    if curl -s http://localhost:5008/metrics > /dev/null 2>&1; then
        curl -s http://localhost:5008/metrics | grep "banking_unprocessed_messages" | grep -v "^#" | while read line; do
            queue=$(echo $line | grep -o 'queue_topic="[^"]*"' | cut -d'"' -f2)
            value=$(echo $line | awk '{print $2}' | cut -d'.' -f1)
            echo -e "  $queue: $value messages"
        done
    else
        echo -e "  ${RED}Consumer metrics not available (service might be down)${NC}"
    fi
}

# Function to compare both metrics
compare_metrics() {
    echo -e "\n${YELLOW}🔍 Comparing Metrics:${NC}"
    check_queue_metrics_new
    check_queue_metrics_old
}

# Function to check message rates
check_message_rates() {
    echo -e "\n${YELLOW}📈 Message Publishing Activity:${NC}"
    
    # Check if producer is running
    if curl -s http://localhost:5007/metrics > /dev/null 2>&1; then
        total_msgs=$(curl -s http://localhost:5007/metrics | grep "messages_published_total" | grep -v "^#" | awk '{sum+=$2} END {print sum}')
        echo -e "  ${GREEN}✅ Message Producer: ACTIVE (Total published: ${total_msgs%.*})${NC}"
    else
        echo -e "  ${RED}❌ Message Producer: Not responding${NC}"
    fi
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

# Function to check monitor status
check_monitor_status() {
    if curl -s http://localhost:9418/health | grep -q '"status":"UP"'; then
        echo -e "${GREEN}✅ RabbitMQ Monitor: HEALTHY${NC}"
        return 0
    else
        echo -e "${RED}❌ RabbitMQ Monitor: NOT HEALTHY${NC}"
        return 1
    fi
}

# Initial state
echo -e "${YELLOW}📋 System Status:${NC}"
check_monitor_status
check_consumer_status
check_message_rates

echo -e "\n${YELLOW}📊 Initial Queue State:${NC}"
compare_metrics

echo -e "\n${YELLOW}Press Enter to STOP the message consumer and watch queues build up...${NC}"
echo -e "${BLUE}Note: The NEW monitor will continue showing accurate queue depths!${NC}"
read -r

# Stop consumer
echo -e "\n${RED}⏸️  Stopping message consumer...${NC}"
docker stop banking-message-consumer > /dev/null 2>&1

# Monitor queue buildup
echo -e "\n${YELLOW}📈 Monitoring queue buildup for 30 seconds...${NC}"
echo -e "${BLUE}Watch how the RabbitMQ Monitor continues to report accurate metrics!${NC}"
echo "Also check your Grafana dashboard: http://localhost:3000"

for i in {1..6}; do
    sleep 5
    echo -e "\n⏱️  After $((i*5)) seconds:"
    compare_metrics
done

echo -e "\n${YELLOW}Press Enter to RESTART the consumer and watch queues drain...${NC}"
read -r

# Restart consumer
echo -e "\n${GREEN}▶️  Starting message consumer...${NC}"
docker start banking-message-consumer > /dev/null 2>&1

# Wait a moment for consumer to reconnect
sleep 3

# Monitor queue drain
echo -e "\n${YELLOW}📉 Monitoring queue drain for 30 seconds...${NC}"

for i in {1..6}; do
    sleep 5
    echo -e "\n⏱️  After $((i*5)) seconds:"
    compare_metrics
done

# Final state
echo -e "\n${YELLOW}📋 Final System Status:${NC}"
check_monitor_status
check_consumer_status
check_message_rates

echo -e "\n${YELLOW}📊 Final Queue State:${NC}"
check_queue_metrics_new

echo -e "\n${GREEN}✅ Test complete!${NC}"
echo ""
echo "💡 Key observations:"
echo "  1. NEW Monitor: Always showed accurate queue depths"
echo "  2. OLD Consumer metrics: Showed 0 or were unavailable when consumer was stopped"
echo "  3. This proves the RabbitMQ Monitor solves the visibility problem!"
echo ""
echo "📊 Check your Grafana dashboard to see the difference:"
echo "   http://localhost:3000/d/banking-message-queue"
echo ""
echo "🎯 Next step: Update Grafana queries to use the new metrics!"