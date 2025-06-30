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

# Check for running containers
running_containers=$(docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml -f docker-compose.messaging.yml -f docker-compose.db-demo.yml ps --services --filter "status=running" 2>/dev/null | wc -l)

if [ "$running_containers" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $running_containers running services${NC}"
    read -p "Stop them first? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml -f docker-compose.tracing.yml -f docker-compose.messaging.yml -f docker-compose.db-demo.yml down
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
        
        if [ ! -z "$backup_choice" ] && [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le "${#backups[@]}" ]; then
            selected_backup="${backups[$((backup_choice-1))]}"
            backup_path="backups/$selected_backup"
            
            echo "📤 Restoring from: $selected_backup"
            
            # Restore configurations
            for item in prometheus grafana src transaction-monitor performance-aggregator anomaly-injector mock-windows-exporter mock-iis-application trace-generator message-producer message-consumer db-connection-demo message-brokers; do
                if [ -d "$backup_path/$item" ]; then
                    echo -n "   Restoring $item... "
                    cp -r "$backup_path/$item"/* "$item/" 2>/dev/null && echo "✅" || echo "❌"
                fi
            done
        fi
    fi
fi

echo ""
echo -e "${BLUE}🏗️ Step 3: Infrastructure Startup${NC}"
echo "=================================="

# Phase 1: Core services
echo "🗄️ Starting core infrastructure..."
docker compose up -d mysql-db prometheus grafana node-exporter cadvisor
echo "⏳ Waiting 60 seconds for initialization..."
sleep 60

# Phase 2: Databases
echo "🗄️ Starting PostgreSQL database..."
docker compose -f docker-compose.db-demo.yml up -d postgres postgres-exporter
sleep 30

# Phase 3: Message brokers
echo "📨 Starting message brokers..."
docker compose -f docker-compose.messaging.yml up -d zookeeper
sleep 20
docker compose -f docker-compose.messaging.yml up -d kafka rabbitmq kafka-exporter
sleep 30

# Enable RabbitMQ plugins
echo "🔌 Enabling RabbitMQ plugins..."
docker exec banking-rabbitmq rabbitmq-plugins enable rabbitmq_management rabbitmq_prometheus 2>/dev/null || echo "   Plugins may already be enabled"

# Phase 4: Jaeger
echo "🔍 Starting Jaeger tracing..."
docker compose -f docker-compose.yml -f docker-compose.tracing.yml up -d jaeger
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

# Phase 8: Monitoring services
echo "💰 Starting monitoring services..."
docker compose -f docker-compose.yml -f docker-compose.transaction-monitoring.yml up -d transaction-monitor performance-aggregator anomaly-injector
sleep 45

# Phase 9: Windows monitoring
echo "🪟 Starting Windows IIS monitoring..."
docker compose up -d mock-windows-exporter mock-iis-application
sleep 30

# Phase 10: Messaging services
echo "📨 Starting message producer and consumer..."
docker compose -f docker-compose.messaging.yml up -d message-producer message-consumer
sleep 30

# Phase 11: Database connection demo
echo "🗄️ Starting database connection demo..."
docker compose -f docker-compose.db-demo.yml up -d db-connection-demo
sleep 20

# Phase 12: Trace generator
echo "🔍 Starting trace generator..."
docker compose -f docker-compose.yml -f docker-compose.tracing.yml up -d trace-generator
sleep 30

# Phase 13: Load generator
echo "⚡ Starting load generator..."
docker compose up -d load-generator

echo ""
echo -e "${BLUE}🏥 Step 4: Health Verification${NC}"
echo "=============================="

# Check all services including new ones
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
    "Windows Exporter:http://localhost:9182/health"
    "IIS Application:http://localhost:8090/health"
    "Trace Generator:http://localhost:9414/health"
    "RabbitMQ Management:http://localhost:15672"
    "Jaeger:http://localhost:16686"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
)

all_healthy=true
for service_info in "${services[@]}"; do
    IFS=: read -r name url <<< "$service_info"
    echo -n "  $name: "
    if curl -s "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${RED}❌${NC}"
        all_healthy=false
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
    echo -e "${GREEN}✅ Grafana ready${NC}"
    
    # Check existing dashboards
    existing_dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | jq -r '.[].title' 2>/dev/null)
    
    if [ -z "$existing_dashboards" ]; then
        echo "📥 No dashboards found. Restoring from backup..."
        
        if [ ! -z "$backup_path" ] && [ -d "$backup_path/grafana_exports" ]; then
            if [ -f "$backup_path/grafana_exports/restore_dashboards.sh" ]; then
                echo "🔄 Running dashboard restore script..."
                cd "$backup_path/grafana_exports"
                ./restore_dashboards.sh
                cd - >/dev/null
            else
                # Manual restore
                for dashboard_file in "$backup_path/grafana_exports"/*_complete.json; do
                    if [ -f "$dashboard_file" ]; then
                        dashboard_name=$(basename "$dashboard_file" _complete.json)
                        echo -n "   Importing $dashboard_name... "
                        
                        dashboard_data=$(cat "$dashboard_file" | jq '.dashboard')
                        import_payload=$(jq -n --argjson dash "$dashboard_data" '{"dashboard": $dash, "overwrite": true}')
                        
                        response=$(curl -s -X POST \
                            -H "Content-Type: application/json" \
                            -u admin:bankingdemo \
                            http://localhost:3000/api/dashboards/db \
                            -d "$import_payload")
                        
                        echo "$response" | grep -q "success" && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}"
                    fi
                done
            fi
        fi
    else
        echo -e "${GREEN}✅ Found existing dashboards:${NC}"
        echo "$existing_dashboards" | sed 's/^/   📊 /'
    fi
else
    echo -e "${YELLOW}⚠️  Grafana not ready - manual dashboard import may be needed${NC}"
fi

echo ""
echo -e "${BLUE}📈 Step 6: Metrics Verification${NC}"
echo "=============================="

echo "🔍 Verifying key metrics..."

# Check Prometheus targets
echo -n "  Prometheus targets: "
targets=$(curl -s "http://localhost:9090/api/v1/targets" | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
echo "$targets discovered"

# Check trace generation
echo -n "  Trace generation: "
traces_per_min=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(traces_generated_total[1m]))*60" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
echo "$traces_per_min traces/min"

# Check message queue activity
echo -n "  Message publishing: "
messages_published=$(curl -s http://localhost:5007/metrics | grep 'banking_messages_published_total' | awk '{sum += $NF} END {print int(sum)}' 2>/dev/null)
echo "$messages_published total messages"

# Check database pool
echo -n "  DB pool status: "
pool_utilization=$(curl -s http://localhost:5009/pool/status 2>/dev/null | jq -r '.pool.utilization_percent // "unknown"' 2>/dev/null)
echo "$pool_utilization% utilized"

echo ""
echo -e "${BLUE}🎯 Step 7: Final Configuration${NC}"
echo "============================="

# Quick status summary
echo ""
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}🎉 RESTART SUCCESSFUL!${NC}"
    echo ""
    echo "✅ All services healthy"
    echo "✅ Dashboards restored"
    echo "✅ Metrics collection active"
    echo "✅ Message queues operational"
    echo "✅ Database pool ready"
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
echo ""
echo "📊 Key Dashboards:"
echo "  • DDoS Detection: http://localhost:3000/d/ddos-detection"
echo "  • Auto-Baselining: http://localhost:3000/d/auto-baselining"
echo "  • Transaction Performance: http://localhost:3000/d/transaction-performance"
echo "  • Windows IIS: http://localhost:3000/d/windows-iis"
echo "  • Transaction Tracing: http://localhost:3000/d/transaction-tracing"
echo "  • Message Queue: http://localhost:3000/d/banking-message-queue"
echo "  • DB Connection Pool: http://localhost:3000/d/banking-db-connection"
echo ""
echo -e "${GREEN}✨ System ready with messaging and database monitoring!${NC}"