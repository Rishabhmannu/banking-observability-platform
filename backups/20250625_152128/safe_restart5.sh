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
            echo "📤 Restoring from: $selected_backup"
            
            # Restore key directories
            for dir in prometheus grafana src transaction-monitor performance-aggregator anomaly-injector mock-windows-exporter mock-iis-application trace-generator message-producer message-consumer db-connection-demo message-brokers; do
                if [ -d "backups/$selected_backup/$dir" ]; then
                    echo -n "   Restoring $dir... "
                    rm -rf "./$dir.old" 2>/dev/null
                    [ -d "./$dir" ] && mv "./$dir" "./$dir.old"
                    cp -r "backups/$selected_backup/$dir" "./"
                    echo "✅"
                fi
            done
            
            # Fix dashboard JSON format if needed
            if [ -d "./grafana/dashboards" ]; then
                echo "   Checking dashboard format..."
                for file in ./grafana/dashboards/*.json; do
                    if [ -f "$file" ] && grep -q '"dashboard"[[:space:]]*:' "$file"; then
                        echo -n "   Fixing $(basename "$file")... "
                        jq '.dashboard // .' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
                        echo "✅"
                    fi
                done
            fi
        fi
    fi
fi

echo ""
echo -e "${BLUE}🏗️ Step 3: Infrastructure Startup${NC}"
echo "=================================="

# Start core infrastructure first
echo "🗄️ Starting core infrastructure..."
docker compose -f docker-compose.yml up -d mysql-db prometheus grafana node-exporter cadvisor

echo "⏳ Waiting 60 seconds for initialization..."
sleep 60

# Start PostgreSQL database
echo "🗄️ Starting PostgreSQL database..."
docker compose -f docker-compose.db-demo.yml up -d

# Start message brokers
echo "📨 Starting message brokers..."
docker compose -f docker-compose.messaging.yml up -d zookeeper
sleep 10
docker compose -f docker-compose.messaging.yml up -d

# Enable RabbitMQ plugins
echo "🔌 Enabling RabbitMQ plugins..."
sleep 5
docker exec banking-rabbitmq rabbitmq-plugins enable rabbitmq_management rabbitmq_prometheus

# Start Jaeger tracing
echo "🔍 Starting Jaeger tracing..."
docker compose -f docker-compose.tracing.yml up -d jaeger

# Start banking services
echo "🏦 Starting banking services..."
docker compose -f docker-compose.yml up -d account-service transaction-service auth-service notification-service fraud-detection

# Start API gateway
echo "🌐 Starting API gateway..."
docker compose -f docker-compose.yml up -d api-gateway

# Start ML services
echo "🤖 Starting ML services..."
docker compose -f docker-compose.yml up -d ddos-ml-detection auto-baselining

# Start monitoring services
echo "💰 Starting monitoring services..."
docker compose -f docker-compose.transaction-monitoring.yml up -d

# Start Windows IIS monitoring
echo "🪟 Starting Windows IIS monitoring..."
docker compose -f docker-compose.yml up -d mock-windows-exporter mock-iis-application

# Start message producer and consumer
echo "📨 Starting message producer and consumer..."
docker compose -f docker-compose.messaging.yml up -d message-producer message-consumer

# Start database connection demo
echo "🗄️ Starting database connection demo..."
docker compose -f docker-compose.db-demo.yml up -d db-connection-demo

# Start trace generator
echo "🔍 Starting trace generator..."
docker compose -f docker-compose.tracing.yml up -d trace-generator

# Start load generator
echo "⚡ Starting load generator..."
docker compose -f docker-compose.yml up -d load-generator

echo ""
echo -e "${BLUE}🏥 Step 4: Health Verification${NC}"
echo "=============================="

# Health check function
check_health() {
    local service=$1
    local url=$2
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo -e "  $service: ${GREEN}✅${NC}"
        return 0
    else
        echo -e "  $service: ${RED}❌${NC}"
        return 1
    fi
}

# Check all services
check_health "Banking API" "http://localhost:8080/health"
check_health "DDoS Detection" "http://localhost:5001/health"
check_health "Auto-Baselining" "http://localhost:5002/health"
check_health "Transaction Monitor" "http://localhost:5003/health"
check_health "Performance Aggregator" "http://localhost:5004/health"
check_health "Anomaly Injector" "http://localhost:5005/health"
check_health "Message Producer" "http://localhost:5007/health"
check_health "Message Consumer" "http://localhost:5008/health"
check_health "DB Connection Demo" "http://localhost:5009/health"
check_health "Windows Exporter" "http://localhost:9182/health"
check_health "IIS Application" "http://localhost:8090/health"
check_health "Trace Generator" "http://localhost:9414/health"
check_health "RabbitMQ Management" "http://localhost:15672/api/health/checks/alarms"
check_health "Jaeger" "http://localhost:16686/"
check_health "Prometheus" "http://localhost:9090/-/healthy"
check_health "Grafana" "http://localhost:3000/api/health"

echo ""
echo -e "${BLUE}📊 Step 5: Dashboard Restoration${NC}"
echo "================================"

# Wait for Grafana to be ready
echo "⏳ Ensuring Grafana is ready..."
for i in {1..30}; do
    if curl -s http://localhost:3000/api/health | grep -q "ok"; then
        echo -e "${GREEN}✅ Grafana is ready${NC}"
        
        # Check if dashboards need to be imported
        dashboard_count=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" | jq '. | length')
        echo "📊 Found $dashboard_count dashboards in Grafana"
        
        if [ "$dashboard_count" -lt 8 ] && [ -d "./grafana_exports" ]; then
            echo "📥 Importing missing dashboards..."
            cd grafana_exports
            if [ -f "restore_dashboards.sh" ]; then
                chmod +x restore_dashboards.sh
                ./restore_dashboards.sh
            fi
            cd ..
        fi
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo -e "${BLUE}📈 Step 6: Metrics Verification${NC}"
echo "=============================="

# Verify key metrics
echo "🔍 Verifying key metrics..."
echo -n "  Prometheus targets: "
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length' | xargs echo "discovered"

echo -n "  Trace generation: "
curl -s http://localhost:16686/api/traces?service=trace-generator | jq '.data | length' | xargs echo "traces/min"

echo -n "  Message publishing: "
curl -s http://localhost:5007/metrics | grep -E "messages_published_total" | awk '{print $2}' | xargs echo "total messages"

echo -n "  DB pool status: "
curl -s http://localhost:5009/metrics | grep -E "db_pool_utilization" | head -1 | awk '{print $2*100}' | xargs printf "%.1f%% utilized\n"

echo ""
echo -e "${BLUE}🎯 Step 7: Final Configuration${NC}"
echo "============================="

# Display status and access URLs
all_healthy=$(docker compose ps --format json | jq -r '.Health' | grep -v "healthy" | wc -l)

if [ "$all_healthy" -eq 0 ]; then
    echo -e "${GREEN}✅ SYSTEM FULLY OPERATIONAL${NC}"
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
echo -e "${BLUE}📊 Key Dashboards:${NC}"
echo "  • DDoS Detection: http://localhost:3000/d/ddos-detection"
echo "  • Auto-Baselining: http://localhost:3000/d/auto-baselining"
echo "  • Transaction Performance: http://localhost:3000/d/transaction-performance"
echo "  • Windows IIS: http://localhost:3000/d/windows-iis"
echo "  • Transaction Tracing: http://localhost:3000/d/transaction-tracing"
echo "  • Message Queue: http://localhost:3000/d/banking-message-queue"
echo "  • DB Connection Pool: http://localhost:3000/d/banking-db-connection"

echo ""
echo -e "${GREEN}✨ System ready with messaging and database monitoring!${NC}"