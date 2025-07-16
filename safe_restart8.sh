#!/bin/bash

echo "🚀 Safe System Restart v8.0 - Complete AIOps Platform with Correlation & RCA Engines"
echo "===================================================================================="

# --- Configuration ---
# Colors for console output, making it easier to read
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Script Initialization ---
# Navigate to the project directory to ensure all paths and docker-compose files are found correctly.
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" || {
    echo -e "${RED}❌ FATAL: Could not find project directory. Please run this script from the project root. Exiting.${NC}"
    exit 1
}

echo "📂 Working from: $(pwd)"
echo "📅 Restart initiated at: $(date)"

# Define all docker-compose files used by the system. This makes the script modular and easy to manage.
COMPOSE_FILES=(
    -f docker-compose.yml
    -f docker-compose.transaction-monitoring.yml
    -f docker-compose.tracing.yml
    -f docker-compose.messaging.yml
    -f docker-compose.db-demo.yml
    -f docker-compose.optimization.yml
)

# --- Step 1: Pre-Restart Verification ---
echo ""
echo -e "${BLUE}🔍 Step 1: Pre-Restart Verification & Cleanup${NC}"
echo "============================================="

# Validate that the main docker-compose file is syntactically correct
echo -n "   🔍 Validating all docker-compose configurations... "
if docker compose "${COMPOSE_FILES[@]}" config > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Valid${NC}"
else
    echo -e "\n${RED}❌ FATAL: A Docker compose file has a syntax error. Please fix it before proceeding.${NC}"
    # Show the user the error from docker-compose
    docker compose "${COMPOSE_FILES[@]}" config
    exit 1
fi

# Check Kubernetes cluster health
echo -n "   ☸️  Checking Kubernetes cluster status... "
if kubectl get nodes >/dev/null 2>&1; then
    node_status=$(kubectl get nodes --no-headers | awk '{print $2}' | head -1)
    if [ "$node_status" = "Ready" ]; then
        echo -e "${GREEN}✅ Cluster Ready${NC}"
    else
        echo -e "${YELLOW}⚠️  Cluster Not Ready${NC}"
    fi
else
    echo -e "${RED}❌ Cluster Unavailable${NC}"
    echo -e "${YELLOW}   📝 Note: Kubernetes monitoring will be skipped${NC}"
fi

# Check for any running containers from this project
running_containers=$(docker compose "${COMPOSE_FILES[@]}" ps --services --filter "status=running" 2>/dev/null | wc -l | tr -d ' ')
if [ "$running_containers" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $running_containers running services.${NC}"
    read -p "   Stop them before restarting? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "   🛑 Stopping all services for a clean restart..."
        docker compose "${COMPOSE_FILES[@]}" down --remove-orphans
        echo -e "   ${GREEN}✅ Services stopped and removed.${NC}"
    else
        echo "   Skipping shutdown. Attempting to restart over existing services."
    fi
fi

# Ensure the shared Docker network exists, creating it if necessary.
echo -n "   🌐 Ensuring Docker network 'ddos-detection-system_banking-network' exists... "
if docker network inspect ddos-detection-system_banking-network >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Already exists.${NC}"
else
    docker network create ddos-detection-system_banking-network > /dev/null 2>&1
    echo -e "${GREEN}✅ Created.${NC}"
fi

# --- Step 2: Backup Selection & Restoration ---
echo ""
echo -e "${BLUE}📥 Step 2: Backup Selection & Restoration${NC}"
echo "========================================"
RESTORE_DASHBOARDS="" # Initialize variable

if [ -d "backups" ]; then
    # Find the 10 most recent backups based on directory name
    backups=($(ls -t backups/ | grep -E '^[0-9]{8}_[0-9]{6}$' | head -10))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${YELLOW}No valid backups found in 'backups/'. Starting with current on-disk configuration.${NC}"
    else
        echo "📁 Available backups (latest first):"
        for i in "${!backups[@]}"; do
            backup_info="${backups[$i]}"
            # Check for the shutdown marker to provide more info to the user
            if [ -f "backups/$backup_info/.shutdown_complete" ]; then
                echo -e "   $((i+1)). ${GREEN}$backup_info (Complete Shutdown Backup)${NC}"
            else
                echo "   $((i+1)). $backup_info (Live Snapshot)"
            fi
        done
        
        echo ""
        read -p "   👉 Select a backup to restore configs from (1-${#backups[@]}), or press Enter to skip: " backup_choice
        
        if [[ "$backup_choice" =~ ^[0-9]+$ ]] && [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le ${#backups[@]} ]; then
            selected_backup="backups/${backups[$((backup_choice-1))]}"
            echo -e "   ${GREEN}📦 Restoring configurations from: $selected_backup${NC}"
            
            # Restore all key configuration directories that exist in the backup
            for dir in prometheus grafana redis container-resource-monitor redis-cache-analyzer kubernetes-monitoring event-correlation-engine rca-insights-engine correlation-rca-dashboard; do
                if [ -d "$selected_backup/$dir" ]; then
                    echo "      Restoring $dir..."
                    # rsync is robust for copying directories, --delete ensures the target matches the source
                    rsync -a --delete "$selected_backup/$dir/" "$dir/"
                fi
            done
            
            # Set the path for the dashboard restoration step later
            if [ -d "$selected_backup/grafana_exports" ]; then
                RESTORE_DASHBOARDS="$selected_backup/grafana_exports"
                echo "      ✅ Marked Grafana dashboards for restoration."
            fi
        else
            echo -e "${YELLOW}Skipping backup restoration. Using current files.${NC}"
        fi
    fi
else
    echo -e "${YELLOW}No 'backups' directory found. Starting with current on-disk configuration.${NC}"
fi

# --- Step 3: Staged Infrastructure Startup ---
echo ""
echo -e "${BLUE}🏗️ Step 3: Staged Infrastructure Startup${NC}"
echo "======================================"
# The startup is phased to manage dependencies. Databases and core infra first.

# Phase 1: Core infrastructure
echo "   (1/10) 🔧 Starting core infrastructure (Prometheus, Grafana, cAdvisor)..."
docker compose "${COMPOSE_FILES[@]}" up -d prometheus grafana cadvisor node-exporter
echo "      ⏳ Waiting 30 seconds for core infra to initialize..."
sleep 30

# Phase 2: Databases (including Redis)
echo "   (2/10) 🗄️ Starting all databases (MySQL, Postgres, Redis)..."
docker compose "${COMPOSE_FILES[@]}" up -d mysql-db postgres banking-redis
echo "      ⏳ Waiting 45 seconds for databases to become fully available..."
sleep 45

# Phase 3: Message brokers
echo "   (3/10) 📨 Starting message brokers (RabbitMQ, Kafka)..."
docker compose "${COMPOSE_FILES[@]}" up -d zookeeper
sleep 20
docker compose "${COMPOSE_FILES[@]}" up -d rabbitmq kafka kafka-exporter
echo "      ⏳ Waiting 30 seconds for brokers to stabilize and enable plugins..."
# Give RabbitMQ time to start before trying to enable plugins
sleep 15
docker exec banking-rabbitmq rabbitmq-plugins enable rabbitmq_management rabbitmq_prometheus >/dev/null 2>&1 || echo "   (plugins already enabled or failed, will continue)"
sleep 15

# Phase 4: Data Exporters & Core Monitors
echo "   (4/10) 📈 Starting data exporters and core monitors..."
docker compose "${COMPOSE_FILES[@]}" up -d postgres-exporter redis-exporter rabbitmq-monitor container-resource-monitor
echo "      ⏳ Waiting 20 seconds..."
sleep 20

# Phase 5: Jaeger Tracing
echo "   (5/10) 🔍 Starting Jaeger tracing..."
docker compose "${COMPOSE_FILES[@]}" up -d jaeger
sleep 20

# Phase 6: Correlation & RCA Engines
echo "   (6/10) 🔗 Starting Correlation & RCA engines..."
docker compose "${COMPOSE_FILES[@]}" up -d event-correlation-engine rca-insights-engine
echo "      ⏳ Waiting 30 seconds for engines to initialize..."
sleep 30

# Phase 7: Application Services (Banking, ML, Analyzers)
echo "   (7/10) 🏦 Starting all application services..."
docker compose "${COMPOSE_FILES[@]}" up -d \
    db-connection-demo \
    message-producer \
    message-consumer \
    account-service \
    transaction-service \
    auth-service \
    notification-service \
    fraud-detection \
    ddos-ml-detection \
    auto-baselining \
    transaction-monitor \
    performance-aggregator \
    anomaly-injector \
    mock-windows-exporter \
    mock-iis-application \
    cache-pattern-analyzer
echo "      ⏳ Waiting 45 seconds for applications to connect to dependencies..."
sleep 45

# Phase 8: API Gateway (starts after backend services are up)
echo "   (8/10) 🌐 Starting API gateway..."
docker compose "${COMPOSE_FILES[@]}" up -d api-gateway
sleep 20

# Phase 9: Generators (start last as they depend on the whole system)
echo "   (9/10) ⚡ Starting all generators..."
docker compose "${COMPOSE_FILES[@]}" up -d load-generator trace-generator cache-load-generator resource-anomaly-generator
sleep 15

# Phase 10: Kubernetes Monitoring Services
echo "   (10/10) ☸️  Starting Kubernetes monitoring services..."
if kubectl get nodes >/dev/null 2>&1; then
    # Start kubectl proxy for metrics access
    echo "      🔧 Starting kubectl proxy for metrics access..."
    kubectl proxy --port=8001 &
    KUBECTL_PROXY_PID=$!
    sleep 10
    
    # Apply all Kubernetes manifests
    echo "      📦 Applying Kubernetes manifests..."
    if [ -d "kubernetes-monitoring/k8s-manifests" ]; then
        kubectl apply -f kubernetes-monitoring/k8s-manifests/namespace.yaml >/dev/null 2>&1
        kubectl apply -f kubernetes-monitoring/k8s-manifests/deployments/ >/dev/null 2>&1
        kubectl apply -f kubernetes-monitoring/k8s-manifests/services/ >/dev/null 2>&1
        kubectl apply -f kubernetes-monitoring/k8s-manifests/hpa/ >/dev/null 2>&1
        kubectl apply -f kubernetes-monitoring/monitoring/kube-state-metrics/ >/dev/null 2>&1
        echo "      ✅ Kubernetes services deployed"
    else
        echo -e "      ${YELLOW}⚠️  Kubernetes manifests not found, skipping...${NC}"
    fi
    
    # Wait for pods to be ready
    echo "      ⏳ Waiting for pods to be ready..."
    sleep 30
    
    # Check pod status
    running_pods=$(kubectl get pods -n banking-k8s-test --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    echo "      📊 Kubernetes pods running: $running_pods"
    
    # Save kubectl proxy PID for cleanup
    echo $KUBECTL_PROXY_PID > /tmp/kubectl_proxy.pid
else
    echo -e "      ${YELLOW}⚠️  Kubernetes cluster not available, skipping...${NC}"
fi

# Phase 11: Correlation RCA Dashboard (Streamlit)
echo "   (11/10) 📊 Starting Correlation RCA Dashboard..."
if [ -d "correlation-rca-dashboard" ]; then
    echo "      🔧 Starting Streamlit dashboard..."
    cd correlation-rca-dashboard
    nohup streamlit run app.py --server.port=8501 --server.address=0.0.0.0 > /dev/null 2>&1 &
    STREAMLIT_PID=$!
    cd ..
    echo $STREAMLIT_PID > /tmp/streamlit.pid
    sleep 10
    echo "      ✅ Streamlit dashboard started on port 8501"
else
    echo -e "      ${YELLOW}⚠️  Correlation RCA Dashboard not found, skipping...${NC}"
fi

# --- Step 4: Comprehensive System Health Verification ---
echo ""
echo -e "${BLUE}🏥 Step 4: Health Verification${NC}"
echo "=============================="

# Define all service endpoints and their names for the health check loop
services_to_check=(
    "Banking API Gateway:http://localhost:8080/health"
    "DDoS ML Detection:http://localhost:5001/health"
    "Auto-Baselining:http://localhost:5002/health"
    "Transaction Monitor:http://localhost:5003/health"
    "Performance Aggregator:http://localhost:5004/health"
    "Anomaly Injector:http://localhost:5005/health"
    "Message Producer:http://localhost:5007/health"
    "Message Consumer:http://localhost:5008/health"
    "DB Connection Demo:http://localhost:5009/health"
    "Mock IIS Application:http://localhost:8090/health"
    "Mock Windows Exporter:http://localhost:9182/health"
    "Trace Generator:http://localhost:9414/health"
    "RabbitMQ Monitor:http://localhost:9418/health"
    "Cache Analyzer:http://localhost:5012/metrics"
    "Container Monitor:http://localhost:5010/metrics"
    "Cache Load Generator:http://localhost:5013/health"
    "Resource Anomaly Gen:http://localhost:5011/status"
    "Event Correlation Engine:http://localhost:5025/health"
    "RCA Insights Engine:http://localhost:5026/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
    "Jaeger Query UI:http://localhost:16686"
    "RabbitMQ Mgmt UI:http://admin:bankingdemo@localhost:15672/api/overview"
)

# Add Kubernetes service check
if kubectl get nodes >/dev/null 2>&1; then
    services_to_check+=("K8s Resource Monitor:http://localhost:9419/metrics")
fi

# Check Streamlit dashboard
if [ -f "/tmp/streamlit.pid" ]; then
    services_to_check+=("Correlation RCA Dashboard:http://localhost:8501/_stcore/health")
fi

all_healthy=true

for service_info in "${services_to_check[@]}"; do
    IFS=: read -r name url_protocol url_path <<< "$service_info"
    url="${url_protocol}:${url_path}"
    echo -n "   Checking $name... "
    # Use --fail to return a non-zero exit code on HTTP errors, with a connection timeout
    if curl -sL --fail --connect-timeout 5 "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ UP${NC}"
    else
        echo -e "${RED}❌ DOWN${NC}"
        all_healthy=false
    fi
done

# Special checks for databases via docker exec for more reliability
for db_check in "banking-redis:redis-cli ping" "banking-postgres:pg_isready -q -U bankinguser" "banking-mysql:mysqladmin ping -h localhost --silent"; do
    IFS=: read -r container command <<< "$db_check"
    echo -n "   Checking $container... "
    if docker exec "$container" $command >/dev/null 2>&1; then
        echo -e "${GREEN}✅ UP${NC}"
    else
        echo -e "${RED}❌ DOWN${NC}"
        all_healthy=false
    fi
done

# Kubernetes health checks
if kubectl get nodes >/dev/null 2>&1; then
    echo -n "   Checking Kubernetes cluster... "
    if kubectl get nodes | grep -q "Ready"; then
        echo -e "${GREEN}✅ UP${NC}"
    else
        echo -e "${RED}❌ DOWN${NC}"
        all_healthy=false
    fi
    
    echo -n "   Checking K8s banking namespace... "
    if kubectl get namespace banking-k8s-test >/dev/null 2>&1; then
        pod_count=$(kubectl get pods -n banking-k8s-test --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        echo -e "${GREEN}✅ UP${NC} ($pod_count pods)"
    else
        echo -e "${RED}❌ DOWN${NC}"
        all_healthy=false
    fi
fi

# --- Step 5: Grafana Dashboard Restoration ---
echo ""
echo -e "${BLUE}📊 Step 5: Grafana Dashboard Restoration${NC}"
echo "======================================"

if [ -z "$RESTORE_DASHBOARDS" ]; then
    echo -e "${YELLOW}Skipping dashboard restoration as no backup was selected.${NC}"
else
    echo "⏳ Ensuring Grafana is ready for imports..."
    max_attempts=30
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:3000/api/health | grep -q "ok"; then
            break
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done; echo ""

    if [ $attempt -lt $max_attempts ]; then
        echo -e "${GREEN}   ✅ Grafana is ready.${NC}"
        if [ -f "$RESTORE_DASHBOARDS/restore_dashboards.sh" ]; then
            echo "   📥 Executing restore script from backup..."
            # Execute the restore script from within its own directory to resolve relative paths
            (cd "$RESTORE_DASHBOARDS" && ./restore_dashboards.sh)
        else
            echo -e "${RED}   ❌ Restore script not found in backup '$RESTORE_DASHBOARDS/restore_dashboards.sh'. Skipping.${NC}"
        fi
    else
        echo -e "${RED}   ❌ Grafana did not become ready in time. Skipping dashboard restoration.${NC}"
    fi
fi

# --- Final Summary ---
echo ""
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}🎉 SYSTEM RESTART COMPLETE! All services are running.${NC}"
else
    echo -e "${YELLOW}⚠️  SYSTEM RESTART PARTIALLY COMPLETE. Some services failed to start.${NC}"
    echo -e "${YELLOW}   Please check the logs for the services marked as DOWN.${NC}"
fi

echo ""
echo -e "${BLUE}🔗 Quick Access Links:${NC}"
echo "====================="
echo "   📊 Grafana:            http://localhost:3000 (admin/bankingdemo)"
echo "   📈 Prometheus:          http://localhost:9090"
echo "   🐰 RabbitMQ Management: http://localhost:15672 (admin/bankingdemo)"
echo "   🔍 Jaeger UI:          http://localhost:16686"
echo "   🧠 Cache Analyzer:     http://localhost:5012/cache-stats"
echo "   💪 Container Monitor:  http://localhost:5010/recommendations"
echo "   🔗 Event Correlation:  http://localhost:5025/correlations/latest"
echo "   🤖 RCA Insights:       http://localhost:5026/health"
echo "   📊 Correlation Dashboard: http://localhost:8501"
if kubectl get nodes >/dev/null 2>&1; then
    echo "   ☸️  K8s Resource Monitor: http://localhost:9419/metrics"
    echo ""
    echo -e "${CYAN}🎯 Kubernetes Commands:${NC}"
    echo "   kubectl get all -n banking-k8s-test"
    echo "   kubectl get hpa -n banking-k8s-test"
    echo "   python3 kubernetes-monitoring/scripts/load-testing-scaling-demo.py"
    echo "   python3 kubernetes-monitoring/scripts/real-time-monitoring.py"
fi
echo ""
echo -e "${PURPLE}🔗 Correlation & RCA Commands:${NC}"
echo "   curl http://localhost:5025/correlations/latest"
echo "   curl http://localhost:5026/openai-status"
echo "   curl \"http://localhost:5026/analyze?limit=1&min_confidence=0.8\""
echo ""
echo "✨ System is now operational. You can start running tests or generating traffic."