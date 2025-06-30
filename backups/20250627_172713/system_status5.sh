#!/bin/bash

echo "📊 System Status v5 - Complete AIOps Platform with Messaging & DB"
echo "================================================================"
echo "$(date)"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Navigate to project directory
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" 2>/dev/null || {
    echo "⚠️  Warning: Could not find project directory"
}

echo -e "${BLUE}🐳 Docker Container Overview:${NC}"
echo "============================="
# Show running containers count
running=$(docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml -f docker-compose.messaging.yml -f docker-compose.db-demo.yml ps --services --filter "status=running" 2>/dev/null | wc -l)
total=$(docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml -f docker-compose.messaging.yml -f docker-compose.db-demo.yml ps --services 2>/dev/null | wc -l)
echo "Containers: $running/$total running"
echo ""

echo -e "${BLUE}🏥 Core Services Health:${NC}"
echo "======================="

# Banking API
echo -n "🏦 Banking API Gateway (8080): "
if curl -s http://localhost:8080/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Prometheus
echo -n "📊 Prometheus (9090): "
if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    targets_up=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -r '[.data.activeTargets[] | select(.health=="up")] | length' 2>/dev/null || echo "0")
    targets_total=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
    echo "   🎯 Targets: $targets_up/$targets_total UP"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Grafana
echo -n "📈 Grafana (3000): "
if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    dashboard_count=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    echo "   📊 Dashboards: $dashboard_count loaded"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}📨 Message Queue Services:${NC}"
echo "========================="

# RabbitMQ
echo -n "🐰 RabbitMQ (5672/15672): "
if docker exec banking-rabbitmq rabbitmq-diagnostics ping >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    # Check queues via monitor
    monitor_metrics=$(curl -s http://localhost:9418/metrics 2>/dev/null)
    if [ ! -z "$monitor_metrics" ]; then
        transaction_q=$(echo "$monitor_metrics" | grep 'rabbitmq_queue_messages_ready{queue="transaction_processing_q"' | awk '{print $2}' | cut -d'.' -f1)
        notification_q=$(echo "$monitor_metrics" | grep 'rabbitmq_queue_messages_ready{queue="notification_dispatch_q"' | awk '{print $2}' | cut -d'.' -f1)
        fraud_q=$(echo "$monitor_metrics" | grep 'rabbitmq_queue_messages_ready{queue="fraud_check_q"' | awk '{print $2}' | cut -d'.' -f1)
        echo "   📬 Queues: Transaction(${transaction_q:-0}) Notification(${notification_q:-0}) Fraud(${fraud_q:-0})"
    fi
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# RabbitMQ Monitor
echo -n "📊 RabbitMQ Monitor (9418): "
monitor_health=$(curl -s http://localhost:9418/health 2>/dev/null)
if [ ! -z "$monitor_health" ]; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    monitor_status=$(echo "$monitor_health" | jq -r '.status // "UNKNOWN"' 2>/dev/null)
    monitored_queues=$(echo "$monitor_health" | jq -r '.monitored_queues | length // 0' 2>/dev/null)
    echo "   📋 Status: $monitor_status | Monitoring: $monitored_queues queues"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Kafka
echo -n "📊 Kafka (9092): "
if docker exec banking-kafka kafka-topics --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    topics=$(docker exec banking-kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null | wc -l)
    echo "   📋 Topics: $topics configured"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Message Producer
echo -n "📤 Message Producer (5007): "
producer_health=$(curl -s http://localhost:5007/health 2>/dev/null)
if [ ! -z "$producer_health" ]; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    rabbitmq_status=$(echo "$producer_health" | jq -r '.rabbitmq // "unknown"' 2>/dev/null)
    kafka_status=$(echo "$producer_health" | jq -r '.kafka // "unknown"' 2>/dev/null)
    echo "   🔗 Connections: RabbitMQ($rabbitmq_status) Kafka($kafka_status)"
    
    # Check message publishing stats
    messages_published=$(curl -s http://localhost:5007/metrics | grep 'banking_messages_published_total' | awk '{sum += $NF} END {print int(sum)}' 2>/dev/null)
    echo "   📨 Messages published: ${messages_published:-0}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Message Consumer
echo -n "📥 Message Consumer (5008): "
if curl -s http://localhost:5008/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    messages_consumed=$(curl -s http://localhost:5008/metrics | grep 'banking_messages_consumed_total' | awk '{sum += $NF} END {print int(sum)}' 2>/dev/null)
    echo "   📨 Messages consumed: ${messages_consumed:-0}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}🗄️ Database Services:${NC}"
echo "===================="

# PostgreSQL
echo -n "🐘 PostgreSQL (5432): "
if docker exec banking-postgres pg_isready -U bankinguser >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    # Check connections
    conn_count=$(docker exec banking-postgres psql -U bankinguser -d bankingdb -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='bankingdb';" 2>/dev/null | tr -d ' ')
    echo "   🔗 Active connections: ${conn_count:-0}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# DB Connection Demo
echo -n "🔗 DB Connection Demo (5009): "
db_health=$(curl -s http://localhost:5009/health 2>/dev/null)
if [ ! -z "$db_health" ]; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    pool_status=$(curl -s http://localhost:5009/pool/status 2>/dev/null)
    if [ ! -z "$pool_status" ]; then
        pool_util=$(echo "$pool_status" | jq -r '.pool.utilization_percent // 0' 2>/dev/null)
        active_conn=$(echo "$pool_status" | jq -r '.pool.active_connections // 0' 2>/dev/null)
        idle_conn=$(echo "$pool_status" | jq -r '.pool.idle_connections // 0' 2>/dev/null)
        echo "   🏊 Pool: ${pool_util}% utilized (Active: $active_conn, Idle: $idle_conn)"
    fi
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}🤖 ML/Detection Services:${NC}"
echo "========================"

# DDoS Detection
echo -n "🛡️  DDoS ML Detection (5001): "
if curl -s http://localhost:5001/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    score=$(curl -s "http://localhost:9090/api/v1/query?query=ddos_detection_score" | jq -r '.data.result[0].value[1] // "N/A"' 2>/dev/null)
    echo "   📊 Current score: $score"
else
    echo -e "${YELLOW}⏸️  STOPPED${NC} (Optional service)"
fi

# Auto-Baselining
echo -n "🎯 Auto-Baselining (5002): "
if curl -s http://localhost:5002/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    health=$(curl -s http://localhost:5002/health 2>/dev/null)
    algorithms=$(echo "$health" | jq -r '.algorithms | length' 2>/dev/null || echo "0")
    recommendations=$(echo "$health" | jq -r '.recommendations_count' 2>/dev/null || echo "0")
    echo "   🧠 Algorithms: $algorithms | 📊 Recommendations: $recommendations"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}💰 Transaction Monitoring:${NC}"
echo "========================="

# Transaction Monitor
echo -n "📊 Transaction Monitor (5003): "
if curl -s http://localhost:5003/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    stats=$(curl -s http://localhost:5003/stats 2>/dev/null)
    if [ ! -z "$stats" ]; then
        total=$(echo "$stats" | jq -r '.total_count // 0' 2>/dev/null)
        echo "   💳 Transactions: $total processed"
    fi
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Performance Aggregator
echo -n "📈 Performance Aggregator (5004): "
if curl -s http://localhost:5004/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Anomaly Injector
echo -n "🎭 Anomaly Injector (5005): "
if curl -s http://localhost:5005/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    active=$(curl -s http://localhost:5005/health | jq -r '.active_injections // 0' 2>/dev/null)
    echo "   💉 Active anomalies: $active"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}🔍 Transaction Tracing:${NC}"
echo "======================"

# Jaeger
echo -n "🔍 Jaeger UI (16686): "
if curl -s http://localhost:16686 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    services=$(curl -s "http://localhost:16686/jaeger/api/services" 2>/dev/null | jq -r '.data | length' 2>/dev/null || echo "0")
    echo "   📊 Services traced: $services"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Trace Generator
echo -n "🔄 Trace Generator (9414): "
if curl -s http://localhost:9414/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    traces_total=$(curl -s http://localhost:9414/metrics 2>/dev/null | grep -E "traces_generated_total{" | awk '{sum += $NF} END {print int(sum)}')
    traces_per_min=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(traces_generated_total[1m]))*60" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
    echo "   📊 Total: ${traces_total:-0} | Rate: ${traces_per_min:-0}/min"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}🪟 Windows IIS Monitoring:${NC}"
echo "========================="

# Windows Exporter
echo -n "📊 Windows Exporter (9182): "
if curl -s http://localhost:9182/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    iis_metrics=$(curl -s http://localhost:9182/metrics 2>/dev/null | grep -c "windows_iis_requests_total" || echo "0")
    echo "   📈 IIS sites monitored: $((iis_metrics / 3))"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# IIS Application
echo -n "🌐 IIS Mock App (8090): "
if curl -s http://localhost:8090/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${BLUE}📊 Key Metrics Summary:${NC}"
echo "======================"

# Message Queue Activity
echo "📨 Message Queue Activity:"
if [ "$messages_published" != "" ] && [ "$messages_consumed" != "" ]; then
    queue_lag=$((messages_published - messages_consumed))
    echo "   Published: $messages_published | Consumed: $messages_consumed | Lag: $queue_lag"
else
    echo "   No message activity detected"
fi

# RabbitMQ Queue Status from Monitor
echo ""
echo "🐰 RabbitMQ Queue Status (from Monitor):"
if [ ! -z "$monitor_metrics" ]; then
    echo "   Transaction Queue: ${transaction_q:-0} messages"
    echo "   Notification Queue: ${notification_q:-0} messages"
    echo "   Fraud Check Queue: ${fraud_q:-0} messages"
    
    # Check monitor health
    monitor_up=$(curl -s http://localhost:9418/metrics 2>/dev/null | grep 'rabbitmq_monitor_up' | awk '{print $2}' | cut -d'.' -f1)
    if [ "$monitor_up" = "1" ]; then
        echo -e "   Monitor Status: ${GREEN}✅ Operational${NC}"
    else
        echo -e "   Monitor Status: ${RED}❌ Issues detected${NC}"
    fi
else
    echo "   Monitor not accessible"
fi

# Database Pool Activity
echo ""
echo "🗄️ Database Connection Pool:"
if [ ! -z "$pool_status" ]; then
    echo "   Utilization: ${pool_util}% | Active: $active_conn | Idle: $idle_conn"
    
    # Check for connection pool issues
    if [ "$pool_util" = "0" ] && [ "$active_conn" = "0" ]; then
        echo -e "   ${YELLOW}⚠️  No active connections - run stress test to generate activity${NC}"
    fi
else
    echo "   Status unavailable"
fi

echo ""
echo -e "${BLUE}🎯 System Integration Summary:${NC}"
echo "============================="

# Count healthy services
healthy_count=0
total_services=19  # Updated count to include RabbitMQ Monitor

services_to_check=(
    "http://localhost:8080/health"
    "http://localhost:5001/health"
    "http://localhost:5002/health"
    "http://localhost:5003/health"
    "http://localhost:5004/health"
    "http://localhost:5005/health"
    "http://localhost:5007/health"
    "http://localhost:5008/health"
    "http://localhost:5009/health"
    "http://localhost:9418/health"
    "http://localhost:9182/health"
    "http://localhost:8090/health"
    "http://localhost:9414/health"
    "http://localhost:15672"
    "http://localhost:16686"
    "http://localhost:9090/-/healthy"
    "http://localhost:3000/api/health"
)

for url in "${services_to_check[@]}"; do
    curl -s "$url" >/dev/null 2>&1 && ((healthy_count++))
done

# Add Docker health checks
docker exec banking-rabbitmq rabbitmq-diagnostics ping >/dev/null 2>&1 && ((healthy_count++))
docker exec banking-postgres pg_isready -U bankinguser >/dev/null 2>&1 && ((healthy_count++))

if [ $healthy_count -eq $total_services ]; then
    echo -e "🏆 ${GREEN}PERFECT HEALTH${NC}: All $total_services services operational!"
elif [ $healthy_count -ge 16 ]; then
    echo -e "💪 ${GREEN}EXCELLENT${NC}: $healthy_count/$total_services services running"
elif [ $healthy_count -ge 11 ]; then
    echo -e "⚠️  ${YELLOW}PARTIAL${NC}: $healthy_count/$total_services services running"
else
    echo -e "🚨 ${RED}CRITICAL${NC}: Only $healthy_count/$total_services services running"
fi

echo ""
echo -e "${BLUE}🚀 Quick Commands:${NC}"
echo "=================="
echo "# View all logs:"
echo "docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml -f docker-compose.messaging.yml -f docker-compose.db-demo.yml logs -f"
echo ""
echo "# Test RabbitMQ queue monitoring:"
echo "./scripts/message-queue-tester-v2.sh"
echo ""
echo "# Check RabbitMQ monitor metrics:"
echo "curl http://localhost:9418/metrics | grep rabbitmq_queue_messages_ready"
echo ""
echo "# Generate traffic:"
echo "./continuous-traffic-generator.sh"
echo ""
echo "# Test message queues:"
echo "curl -X POST http://localhost:5007/publish/transaction"
echo "curl -X POST http://localhost:5007/publish/notification"
echo ""
echo "# Test database pool:"
echo "curl -X POST http://localhost:5009/pool/stress-test"
echo ""
echo "# Test anomalies:"
echo "./test-anomaly-injection.sh"
echo ""
echo "# Access UIs:"
echo "Grafana: http://localhost:3000 (admin/bankingdemo)"
echo "RabbitMQ: http://localhost:15672 (admin/bankingdemo)"
echo "Jaeger: http://localhost:16686"
echo "Prometheus: http://localhost:9090"
echo "RabbitMQ Monitor: http://localhost:9418/metrics"
echo ""

# Suggestions if metrics are zero
if [ "$pool_util" = "0" ] || [ "${transaction_q:-0}" = "0" ]; then
    echo -e "${YELLOW}💡 Tip: Metrics showing zero? Try these commands:${NC}"
    echo "  # Generate message queue activity:"
    echo "  ./generate-queue-activity.sh"
    echo "  # Generate database activity:"
    echo "  ./generate-db-activity.sh"
    echo "  # Test queue monitoring:"
    echo "  ./message-queue-tester-v2.sh"
    echo "  # Generate continuous traffic:"
    echo "  ./continuous-traffic-generator.sh"
    echo "  # Test Windows IIS Monitoring under load"
    echo "  ./test_windows_iis_anomalies_v2.sh"
    echo ""
fi

echo -e "${GREEN}✨ Status check complete!${NC}"
echo "Generated at: $(date '+%Y-%m-%d %H:%M:%S')"