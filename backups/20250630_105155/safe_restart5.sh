#!/bin/bash

echo "🚀 Safe System Restart v5 - Complete AIOps with Messaging & DB"
echo "=============================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to project directory
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" || {
    echo -e "${RED}❌ Could not find project directory${NC}"
    exit 1
}

echo "📂 Working from: $(pwd)"
echo "📅 Restart initiated at: $(date)"

echo ""
echo -e "${BLUE}🔍 Step 1: Pre-Restart Verification${NC}"
echo "===================================="

# Validate docker-compose.yml first
echo "🔍 Validating docker-compose.yml..."
if docker compose -f docker-compose.yml config > /dev/null 2>&1; then
    echo -e "  ${GREEN}✅ docker-compose.yml is valid${NC}"
else
    echo -e "  ${RED}❌ docker-compose.yml has errors:${NC}"
    docker compose -f docker-compose.yml config 2>&1 | grep -E "(error|Error)" | head -5
    echo -e "  ${YELLOW}Please fix the errors before proceeding${NC}"
    exit 1
fi

# Check for running containers
running_containers=$(docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml -f docker-compose.messaging.yml -f docker-compose.db-demo.yml ps --services --filter "status=running" 2>/dev/null | wc -l)

if [ "$running_containers" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $running_containers running services${NC}"
    read -p "Stop them first? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml -f docker-compose.messaging.yml -f docker-compose.db-demo.yml down --remove-orphans
        echo "✅ Services stopped"
    fi
fi

# Ensure network exists
echo ""
echo "🌐 Ensuring Docker network exists..."
docker network create ddos-detection-system_banking-network 2>/dev/null || echo "   Network already exists"

echo ""
echo -e "${BLUE}📥 Step 2: Backup Selection & Restoration${NC}"
echo "========================================"

# Find available backups
if [ -d "backups" ]; then
    echo "📁 Available backups:"
    backups=($(ls -t backups/ | head -10))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo "No backups found. Starting with current configuration."
    else
        for i in "${!backups[@]}"; do
            backup_info="${backups[$i]}"
            if [ -f "backups/$backup_info/final_metrics_state.txt" ]; then
                dashboard_count=$(ls -1 "backups/$backup_info/grafana_exports"/*.json 2>/dev/null | wc -l)
                echo "  $((i+1)). $backup_info (📊 $dashboard_count dashboards)"
            else
                echo "  $((i+1)). $backup_info"
            fi
        done
        
        echo ""
        read -p "Select backup to restore (1-${#backups[@]}) or press Enter to skip: " backup_choice
        
        if [ ! -z "$backup_choice" ] && [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le ${#backups[@]} ]; then
            selected_backup="${backups[$((backup_choice-1))]}"
            echo "📦 Restoring from: $selected_backup"
            
            # Check for shutdown marker
            if [ -f "backups/$selected_backup/.shutdown_complete" ]; then
                echo "   ✅ This is a complete shutdown backup"
            fi
            
            # Restore configs
            if [ -d "backups/$selected_backup/prometheus" ]; then
                cp -r "backups/$selected_backup/prometheus"/* prometheus/ 2>/dev/null
                echo "   ✅ Prometheus config restored"
            fi
            
            # Restore rabbitmq-monitor if it exists
            if [ -d "backups/$selected_backup/rabbitmq-monitor" ]; then
                cp -r "backups/$selected_backup/rabbitmq-monitor"/* rabbitmq-monitor/ 2>/dev/null
                echo "   ✅ RabbitMQ Monitor config restored"
            fi
            
            # Mark for dashboard restoration
            RESTORE_DASHBOARDS="backups/$selected_backup/grafana_exports"
        fi
    fi
fi

echo ""
echo -e "${BLUE}🏗️ Step 3: Infrastructure Startup${NC}"
echo "=================================="

# Phase 1: Core infrastructure (with network)
echo "🗄️ Starting core infrastructure..."
docker compose up -d mysql-db prometheus grafana cadvisor node-exporter
echo "⏳ Waiting 60 seconds for initialization..."
sleep 60

# Phase 2: Databases
echo "🗄️ Starting PostgreSQL database..."
docker compose -f docker-compose.db-demo.yml up -d postgres postgres-exporter db-connection-demo
sleep 30

# Phase 3: Message brokers
echo "📨 Starting message brokers..."
docker compose -f docker-compose.messaging.yml up -d zookeeper
sleep 20
docker compose -f docker-compose.messaging.yml up -d rabbitmq kafka kafka-exporter

# Enable RabbitMQ plugins
echo "🔌 Enabling RabbitMQ plugins..."
sleep 30  # Wait for RabbitMQ to fully start
docker exec banking-rabbitmq rabbitmq-plugins enable rabbitmq_management rabbitmq_prometheus 2>/dev/null || echo "   ⚠️  Could not enable plugins (RabbitMQ may still be starting)"

# Start RabbitMQ monitor after RabbitMQ is ready
echo "📊 Starting RabbitMQ Queue Monitor..."
sleep 10  # Give RabbitMQ a bit more time
docker compose -f docker-compose.messaging.yml up -d rabbitmq-monitor

# Start message producer and consumer
docker compose -f docker-compose.messaging.yml up -d message-producer message-consumer

# Phase 4: Jaeger
echo "🔍 Starting Jaeger tracing..."
docker compose -f docker-compose.tracing.yml up -d jaeger
sleep 30

# Phase 5: Banking services
echo "🏦 Starting banking services..."
docker compose up -d account-service transaction-service auth-service notification-service fraud-detection
sleep 45

# Phase 6: API Gateway
echo "🌐 Starting API gateway..."
docker compose up -d api-gateway
sleep 30

# Phase 7: ML services
echo "🤖 Starting ML services..."
docker compose up -d ddos-ml-detection auto-baselining
sleep 45

# Phase 8: Monitoring services - FIXED TO INCLUDE MAIN COMPOSE FILE
echo "💰 Starting monitoring services..."
# Include both docker-compose.yml and docker-compose.transaction-monitoring.yml
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml up -d transaction-monitor performance-aggregator anomaly-injector
sleep 45

# Phase 9: Windows monitoring
echo "🪟 Starting Windows IIS monitoring..."
docker compose up -d mock-windows-exporter mock-iis-application
sleep 30

# Phase 10: Database connection demo
echo "🗄️ Starting database connection demo..."
docker compose -f docker-compose.db-demo.yml up -d db-connection-demo
sleep 20

# Phase 11: Trace generator
echo "🔍 Starting trace generator..."
docker compose -f docker-compose.tracing.yml up -d trace-generator
sleep 30

# Phase 12: Load generator
echo "⚡ Starting load generator..."
docker compose up -d load-generator

echo ""
echo -e "${BLUE}🏥 Step 4: Health Verification${NC}"
echo "=============================="

# Extended health check list
services=(
    "Banking API:http://localhost:8080/health"
    "DDoS Detection:http://localhost:5001/health"
    "Auto-Baselining:http://localhost:5002/health"
    "Transaction Monitor:http://localhost:5003/health"
    "Performance Aggregator:http://localhost:5004/health"
    "Anomaly Injector:http://localhost:5005/health"
    "Message Producer:http://localhost:5007/health"
    "Message Consumer:http://localhost:5008/health"
    "DB Connection Demo:http://localhost:5009/health"
    "RabbitMQ Monitor:http://localhost:9418/health"
    "Windows Exporter:http://localhost:9182/health"
    "IIS Application:http://localhost:8090/health"
    "Trace Generator:http://localhost:9414/health"
    "RabbitMQ Management:http://localhost:15672/api/overview"
    "Jaeger:http://localhost:16686"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
)

all_healthy=true
for service_info in "${services[@]}"; do
    IFS=: read -r name url <<< "$service_info"
    echo -n "  $name: "
    
    # Special handling for RabbitMQ (needs auth)
    if [[ "$name" == "RabbitMQ Management" ]]; then
        if curl -s -u admin:bankingdemo "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅${NC}"
        else
            echo -e "${RED}❌${NC}"
            all_healthy=false
        fi
    else
        if curl -s "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅${NC}"
        else
            echo -e "${RED}❌${NC}"
            all_healthy=false
        fi
    fi
done

echo ""
echo -e "${BLUE}📊 Step 5: Dashboard Restoration${NC}"
echo "================================"

# Wait for Grafana
echo "⏳ Ensuring Grafana is ready..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:3000/api/health | grep -q "ok"; then
        break
    fi
    sleep 2
    ((attempt++))
done

if [ $attempt -lt $max_attempts ]; then
    echo -e "${GREEN}✅ Grafana is ready${NC}"
    
    # Check existing dashboards
    existing_dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | jq -r '.[].title' 2>/dev/null)
    dashboard_count=$(echo "$existing_dashboards" | grep -v '^$' | wc -l)
    echo "📊 Found $dashboard_count dashboards in Grafana"
    
    # Restore if specified
    if [ ! -z "$RESTORE_DASHBOARDS" ] && [ -d "$RESTORE_DASHBOARDS" ]; then
        echo "📥 Restoring dashboards from backup..."
        
        if [ -f "$RESTORE_DASHBOARDS/restore_dashboards.sh" ]; then
            cd "$RESTORE_DASHBOARDS"
            ./restore_dashboards.sh
            cd - > /dev/null
        else
            # Manual restoration
            for dashboard in "$RESTORE_DASHBOARDS"/*_complete.json; do
                if [ -f "$dashboard" ]; then
                    dashboard_name=$(basename "$dashboard" _complete.json)
                    echo -n "   Importing $dashboard_name..."
                    
                    # Import dashboard
                    response=$(curl -s -X POST \
                        -H "Content-Type: application/json" \
                        -u admin:bankingdemo \
                        http://localhost:3000/api/dashboards/db \
                        -d @"$dashboard")
                    
                    if echo "$response" | grep -q "success"; then
                        echo -e " ${GREEN}✅${NC}"
                    else
                        echo -e " ${RED}❌${NC}"
                    fi
                fi
            done
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Grafana not ready after $max_attempts attempts${NC}"
fi

echo ""
echo -e "${BLUE}📈 Step 6: Metrics Verification${NC}"
echo "=============================="

echo "🔍 Verifying key metrics..."

# Check Prometheus targets
echo -n "  Prometheus targets: "
target_count=$(curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length' 2>/dev/null || echo "0")
echo "discovered $target_count"

# Check RabbitMQ monitor
echo -n "  RabbitMQ Monitor: "
queue_metrics=$(curl -s http://localhost:9418/metrics | grep -c "rabbitmq_queue_messages_ready" 2>/dev/null || echo "0")
echo "monitoring $queue_metrics queues"

# Check trace generation
echo -n "  Trace generation: "
trace_count=$(curl -s "http://localhost:9090/api/v1/query?query=traces_generated_total" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0")
echo "$trace_count total traces"

# Check message publishing
echo -n "  Message publishing: "
message_count=$(curl -s http://localhost:5007/metrics 2>/dev/null | grep -E "messages_published_total" | awk '{print $2}' | head -1 || echo "0")
echo "$message_count total messages"

# Check DB pool
echo -n "  DB pool status: "
pool_usage=$(curl -s http://localhost:5009/metrics 2>/dev/null | grep -E "db_pool_usage_percent" | awk '{print $2}' | head -1 || echo "0")
echo "${pool_usage}% utilized"

echo ""
echo -e "${BLUE}🎯 Step 7: Final Configuration${NC}"
echo "============================="

# Final system check
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}✅ ALL SYSTEMS OPERATIONAL${NC}"
    echo "All services are running and healthy!"
else
    echo -e "${YELLOW}⚠️  PARTIAL RESTART${NC}"
    echo "Some services need attention"
fi

echo ""
echo -e "${BLUE}🔗 Quick Access:${NC}"
echo "==============="
echo "📊 Grafana Dashboards: http://localhost:3000 (admin/bankingdemo)"
echo "🐰 RabbitMQ Management: http://localhost:15672 (admin/bankingdemo)"
echo "🔍 Jaeger UI: http://localhost:16686"
echo "📈 Prometheus: http://localhost:9090"
echo "📊 RabbitMQ Monitor Metrics: http://localhost:9418/metrics"
echo ""
echo "📊 Key Dashboards:"
echo "  • DDoS Detection: http://localhost:3000/d/ddos-detection"
echo "  • Auto-Baselining: http://localhost:3000/d/auto-baselining"
echo "  • Transaction Performance: http://localhost:3000/d/transaction-performance"
echo "  • Windows IIS: http://localhost:3000/d/windows-iis"
echo "  • Transaction Tracing: http://localhost:3000/d/transaction-tracing"
echo "  • Message Queue: http://localhost:3000/d/banking-message-queue"
echo "  • DB Connection Pool: http://localhost:3000/d/banking-db-connection"
echo "  • RabbitMQ Monitor: http://localhost:3000/d/rabbitmq-monitor-v1"
echo ""
echo "✨ System ready with messaging, database monitoring, and RabbitMQ queue monitoring!"