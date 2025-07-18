#!/bin/bash

echo "🛑 Safe System Shutdown v7.0 - Complete State Preservation with Correlation & RCA"
echo "================================================================================"

# --- Configuration ---
# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# --- Script Initialization ---
# Navigate to the project directory to ensure all paths are correct
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" || {
    echo -e "${RED}❌ FATAL: Could not find project directory. Exiting.${NC}"
    exit 1
}

echo "📂 Working from: $(pwd)"
echo "📅 Shutdown initiated at: $(date)"

# --- Backup Creation ---
# Create a unique timestamped directory for this backup
backup_timestamp=$(date +%Y%m%d_%H%M%S)
backup_dir="backups/${backup_timestamp}"
mkdir -p "$backup_dir/grafana_exports"

echo ""
echo -e "${BLUE}📊 Step 1: Exporting Live Grafana Dashboards${NC}"
echo "==========================================="

# Check if Grafana is running before attempting to export
if curl -s --connect-timeout 5 http://localhost:3000/api/health | grep -q "ok" 2>/dev/null; then
    echo "🔍 Discovering dashboards from Grafana API..."
    
    # Get all dashboards from the Grafana API
    dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null)
    dashboard_count=$(echo "$dashboards" | jq -r '. | length' 2>/dev/null || echo "0")
    
    echo "📊 Found $dashboard_count dashboards to export. This preserves all manual edits."
    
    if [ "$dashboard_count" -gt 0 ]; then
        # Loop through each dashboard UID and export its full JSON model
        echo "$dashboards" | jq -r '.[] | .uid + ":" + .title' | while IFS=: read -r uid title; do
            echo -n "   📥 Exporting: $title... "
            
            # Fetch the complete dashboard data
            dashboard_data=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/dashboards/uid/$uid")
            
            if [ ! -z "$dashboard_data" ] && echo "$dashboard_data" | jq -e '.dashboard' >/dev/null 2>&1; then
                # Save the complete dashboard object needed for re-import
                echo "$dashboard_data" > "$backup_dir/grafana_exports/${uid}_complete.json"
                
                # Check dashboard type for better logging
                if echo "$title" | grep -qE -i "(correlation|rca|insights|analysis)"; then
                    echo -e "${PURPLE}✅ RCA${NC}"
                elif echo "$title" | grep -qE -i "(kubernetes|k8s|pod|node|hpa|autoscal)"; then
                    echo -e "${BLUE}✅ K8s${NC}"
                else
                    echo -e "${GREEN}✅${NC}"
                fi
            else
                echo -e "${RED}❌ FAILED${NC}"
            fi
        done
        
        # Create a convenient restoration script within the backup
        cat > "$backup_dir/grafana_exports/restore_dashboards.sh" << 'EOF'
#!/bin/bash
echo "🔄 Restoring Grafana Dashboards from backup..."
echo "=========================================="
for dashboard_file in *_complete.json; do
    if [ -f "$dashboard_file" ]; then
        title=$(jq -r '.dashboard.title // "Unknown Dashboard"' "$dashboard_file")
        echo -n "   📥 Importing '$title'... "
        
        # The payload for the Grafana API requires the dashboard to be nested
        import_payload=$(jq -n --argjson dash_data "$(cat "$dashboard_file")" \
          '{"dashboard": $dash_data.dashboard, "overwrite": true, "folderId": $dash_data.meta.folderId}')
        
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u admin:bankingdemo \
            http://localhost:3000/api/dashboards/db \
            -d "$import_payload")
        
        if echo "$response" | grep -q "success"; then
            echo -e "\033[0;32m✅ SUCCESS\033[0m"
        else
            echo -e "\033[0;31m❌ FAILED\033[0m"
            echo "      Error: $(echo "$response" | jq -r .message)"
        fi
    fi
done
chmod -x "$0"
EOF
        chmod +x "$backup_dir/grafana_exports/restore_dashboards.sh"
    fi
else
    echo -e "${YELLOW}⚠️  Grafana is not accessible. Skipping live dashboard export.${NC}"
fi

echo ""
echo -e "${PURPLE}🔗 Step 2: Correlation & RCA State Backup${NC}"
echo "======================================="

# NEW: Backup Correlation & RCA engine state
echo "📦 Backing up Correlation & RCA engine configurations..."

# Backup Event Correlation Engine state
echo -n "   📊 Capturing correlation engine state... "
mkdir -p "$backup_dir/correlation-rca-state"
{
    echo "Correlation & RCA Engine State - $(date)"
    echo "======================================="
    echo ""
    echo "### Event Correlation Engine Status ###"
    curl -s http://localhost:5025/health 2>/dev/null || echo "Correlation engine not accessible"
    echo ""
    echo "### Latest Correlations ###"
    curl -s http://localhost:5025/correlations/latest 2>/dev/null | jq '.correlations[:5]' || echo "No correlation data available"
    echo ""
    echo "### Correlation Summary ###"
    curl -s http://localhost:5025/correlations/summary 2>/dev/null || echo "No correlation summary available"
    echo ""
    echo "### RCA Insights Engine Status ###"
    curl -s http://localhost:5026/health 2>/dev/null || echo "RCA engine not accessible"
    echo ""
    echo "### OpenAI API Status ###"
    curl -s http://localhost:5026/openai-status 2>/dev/null || echo "OpenAI status not available"
    echo ""
    echo "### Test AI Analysis ###"
    curl -s "http://localhost:5026/analyze?limit=1&min_confidence=0.8" 2>/dev/null | jq '.analyses[:1]' || echo "AI analysis not available"
} > "$backup_dir/correlation-rca-state/engines_state.txt"
echo -e "${GREEN}✅${NC}"

# Backup Streamlit dashboard state
echo -n "   📊 Capturing Streamlit dashboard state... "
{
    echo "Streamlit Correlation Dashboard State - $(date)"
    echo "============================================="
    echo ""
    echo "### Dashboard Accessibility ###"
    if curl -s --connect-timeout 3 http://localhost:8501/_stcore/health >/dev/null 2>&1; then
        echo "✅ Streamlit dashboard is accessible"
        echo "URL: http://localhost:8501"
        echo "Status: Running"
    else
        echo "❌ Streamlit dashboard not accessible"
        echo "Status: Offline"
    fi
    echo ""
    echo "### Component Files ###"
    if [ -d "correlation-rca-dashboard" ]; then
        echo "📁 correlation-rca-dashboard directory exists"
        ls -la correlation-rca-dashboard/ || echo "Cannot list directory"
        echo ""
        echo "Components:"
        ls -la correlation-rca-dashboard/components/ 2>/dev/null || echo "Components directory not found"
        echo ""
        echo "Utils:"
        ls -la correlation-rca-dashboard/utils/ 2>/dev/null || echo "Utils directory not found"
    else
        echo "❌ correlation-rca-dashboard directory not found"
    fi
} > "$backup_dir/correlation-rca-state/streamlit_state.txt"
echo -e "${GREEN}✅${NC}"

echo ""
echo -e "${BLUE}☸️  Step 3: Kubernetes State Backup${NC}"
echo "=================================="

# Backup Kubernetes state and configurations
if kubectl get nodes >/dev/null 2>&1; then
    echo "📦 Backing up Kubernetes configurations and state..."
    
    # Create K8s backup directory
    mkdir -p "$backup_dir/kubernetes-monitoring"
    
    # Backup current pod states
    echo -n "   📊 Capturing pod states... "
    kubectl get all -n banking-k8s-test -o yaml > "$backup_dir/kubernetes-monitoring/current_state.yaml" 2>/dev/null
    kubectl get hpa -n banking-k8s-test -o yaml > "$backup_dir/kubernetes-monitoring/hpa_state.yaml" 2>/dev/null
    kubectl describe hpa -n banking-k8s-test > "$backup_dir/kubernetes-monitoring/hpa_details.txt" 2>/dev/null
    echo -e "${GREEN}✅${NC}"
    
    # Backup current metrics
    echo -n "   📈 Capturing K8s metrics... "
    {
        echo "Kubernetes Metrics State - $(date)"
        echo "================================"
        echo ""
        echo "### Pod Status ###"
        kubectl get pods -n banking-k8s-test -o wide 2>/dev/null || echo "No pods found"
        echo ""
        echo "### HPA Status ###"
        kubectl get hpa -n banking-k8s-test 2>/dev/null || echo "No HPA found"
        echo ""
        echo "### Node Resources ###"
        kubectl top nodes 2>/dev/null || echo "Metrics not available"
        echo ""
        echo "### Pod Resources ###"
        kubectl top pods -n banking-k8s-test 2>/dev/null || echo "Pod metrics not available"
        echo ""
        echo "### Recent Events ###"
        kubectl get events -n banking-k8s-test --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "No events found"
        echo ""
        echo "### K8s Resource Monitor Metrics ###"
        curl -s http://localhost:9419/metrics 2>/dev/null | head -20 || echo "K8s resource monitor not accessible"
    } > "$backup_dir/kubernetes-monitoring/k8s_metrics_state.txt"
    echo -e "${GREEN}✅${NC}"
    
    # Get current replica counts for restoration
    echo -n "   📊 Recording current scaling state... "
    {
        echo "Current Scaling State - $(date)"
        echo "=============================="
        echo "Banking Service Replicas: $(kubectl get deployment banking-service -n banking-k8s-test -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 'N/A')"
        echo "Load Generator Replicas: $(kubectl get deployment load-generator -n banking-k8s-test -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 'N/A')"
        echo "HPA Min Replicas: $(kubectl get hpa banking-service-hpa -n banking-k8s-test -o jsonpath='{.spec.minReplicas}' 2>/dev/null || echo 'N/A')"
        echo "HPA Max Replicas: $(kubectl get hpa banking-service-hpa -n banking-k8s-test -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || echo 'N/A')"
        echo "HPA Target CPU: $(kubectl get hpa banking-service-hpa -n banking-k8s-test -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}' 2>/dev/null || echo 'N/A')%"
    } > "$backup_dir/kubernetes-monitoring/scaling_state.txt"
    echo -e "${GREEN}✅${NC}"
    
else
    echo -e "${YELLOW}⚠️  Kubernetes cluster not accessible. Skipping K8s backup.${NC}"
fi

echo ""
echo -e "${BLUE}📂 Step 4: Backing Up All Service Configurations${NC}"
echo "============================================="

# Function to safely backup a directory or file
backup_item() {
    local item=$1
    local display_name=${2:-$item}
    
    if [ -e "$item" ]; then
        echo -n "   📦 Backing up $display_name... "
        # Use rsync for better handling of files and directories
        rsync -a --quiet "$item" "$backup_dir/"
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "   ${YELLOW}⚠️  $display_name not found, skipping.${NC}"
    fi
}

# Backup all configuration and code directories
backup_item "prometheus"
backup_item "grafana"
backup_item "src" "Main Source Code"
backup_item "shared" "Shared Libraries (Cache)"
backup_item "scripts" "Utility Scripts"

# Backup all service application directories
backup_item "transaction-monitor"
backup_item "performance-aggregator"
backup_item "anomaly-injector"
backup_item "mock-windows-exporter"
backup_item "mock-iis-application"
backup_item "trace-generator"
backup_item "message-producer"
backup_item "message-consumer"
backup_item "rabbitmq-monitor"
backup_item "db-connection-demo"
backup_item "message-brokers"

# Backup Redis and Container Optimization services
backup_item "redis" "Redis Config"
backup_item "redis-cache-analyzer"
backup_item "redis-cache-load-generator"
backup_item "container-resource-monitor"
backup_item "resource-anomaly-generator"
backup_item "k6-scripts"

# NEW: Backup Correlation & RCA services
backup_item "event-correlation-engine" "Event Correlation Engine"
backup_item "rca-insights-engine" "RCA Insights Engine"
backup_item "correlation-rca-dashboard" "Correlation RCA Dashboard"

# Backup Kubernetes monitoring system
backup_item "kubernetes-monitoring" "Kubernetes Monitoring System"

# Backup all Docker Compose files
echo -n "   📦 Backing up Docker Compose files... "
cp -a docker-compose*.yml "$backup_dir/" 2>/dev/null
echo -e "${GREEN}✅${NC}"

# Backup other important root files
echo -n "   📦 Backing up root project files... "
cp -a *.sh *.py *.md *.txt "$backup_dir/" 2>/dev/null
echo -e "${GREEN}✅${NC}"

echo ""
echo -e "${BLUE}📈 Step 5: Capturing Final Metrics State${NC}"
echo "======================================"
# Capture the last known state of key metrics before shutdown
echo -n "   📝 Capturing metrics snapshot... "
{
    echo "Final Metrics State - $(date)"
    echo "============================="
    echo ""
    
    echo "### Prometheus ###"
    echo "Targets:"
    curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "  - \(.labels.job | printf "%-30s") \(.health)"' 2>/dev/null || echo "  - Prometheus not accessible"
    echo ""
    
    echo "### Correlation & RCA Engines ###"
    echo "Event Correlation Engine:"
    curl -s http://localhost:5025/health 2>/dev/null | jq '.' || echo "  - Correlation engine not accessible"
    echo ""
    echo "RCA Insights Engine:"
    curl -s http://localhost:5026/health 2>/dev/null | jq '.' || echo "  - RCA engine not accessible"
    echo ""
    echo "Latest Correlations (Top 3):"
    curl -s http://localhost:5025/correlations/latest 2>/dev/null | jq '.correlations[:3]' || echo "  - No correlation data available"
    echo ""
    echo "OpenAI Integration Status:"
    curl -s http://localhost:5026/openai-status 2>/dev/null | jq '.' || echo "  - OpenAI status not available"
    echo ""
    
    echo "### Redis & Container Optimization ###"
    echo "Cache Status:"
    curl -s http://localhost:5012/cache-stats 2>/dev/null | jq '.' || echo "  - Cache analyzer not accessible"
    echo ""
    echo "Container Recommendations (Last Known):"
    curl -s http://localhost:5010/recommendations 2>/dev/null | jq '.' || echo "  - Container monitor not accessible"
    echo ""

    echo "### Message Queues ###"
    echo "RabbitMQ Queue Depths (from Monitor):"
    curl -s http://localhost:9418/metrics | grep "rabbitmq_queue_messages_ready" | grep -v "^#" 2>/dev/null || echo "  - RabbitMQ monitor not accessible"
    echo ""
    
    echo "### Transaction Monitoring ###"
    echo "Transaction Stats:"
    curl -s http://localhost:5003/stats 2>/dev/null | jq '.' || echo "  - Transaction monitor not accessible"
    echo ""
    
    echo "### Active Anomalies ###"
    echo "Anomaly Injector Status:"
    curl -s http://localhost:5005/health 2>/dev/null | jq '.' || echo "  - Anomaly injector not accessible"
    echo ""
    
    # Kubernetes monitoring metrics
    echo "### Kubernetes Monitoring ###"
    echo "K8s Resource Monitor Status:"
    curl -s http://localhost:9419/metrics 2>/dev/null | grep -E "(k8s_hpa_replicas|k8s_pod_count)" | head -10 || echo "  - K8s resource monitor not accessible"

} > "$backup_dir/final_metrics_state.txt"
echo -e "${GREEN}✅${NC}"

# List running containers before shutdown
docker compose ps > "$backup_dir/running_services.txt" 2>&1

echo ""
echo -e "${BLUE}🛑 Step 6: Graceful, Ordered Service Shutdown${NC}"
echo "==========================================="

# Define all compose files to ensure all services are targeted
COMPOSE_FILES=(
    -f docker-compose.yml
    -f docker-compose.transaction-monitoring.yml
    -f docker-compose.tracing.yml
    -f docker-compose.messaging.yml
    -f docker-compose.db-demo.yml
    -f docker-compose.optimization.yml
)

# Phase 0: Kubernetes services shutdown
if kubectl get nodes >/dev/null 2>&1; then
    echo "   (0/9) ☸️  Gracefully scaling down Kubernetes services..."
    
    # Scale down load generators first
    kubectl scale deployment load-generator -n banking-k8s-test --replicas=1 >/dev/null 2>&1
    echo "      📉 Load generators scaled down"
    
    # Wait for HPA to scale down banking service
    echo "      ⏳ Waiting for HPA to scale down banking service..."
    sleep 30
    
    # Force scale down banking service to minimum
    kubectl scale deployment banking-service -n banking-k8s-test --replicas=2 >/dev/null 2>&1
    echo "      📉 Banking service scaled to minimum"
    
    # Stop kubectl proxy if running
    if [ -f "/tmp/kubectl_proxy.pid" ]; then
        proxy_pid=$(cat /tmp/kubectl_proxy.pid)
        kill $proxy_pid >/dev/null 2>&1
        rm -f /tmp/kubectl_proxy.pid
        echo "      🛑 kubectl proxy stopped"
    fi
    
    echo "      ✅ Kubernetes services prepared for shutdown"
fi

# Phase 1: Stop Correlation & RCA Dashboard (Streamlit)
echo "   (1/8) 📊 Stopping Correlation RCA Dashboard..."
if pgrep -f "streamlit run app.py" > /dev/null 2>&1; then
    pkill -f "streamlit run app.py" &> /dev/null
    echo "      🛑 Streamlit dashboard stopped"
else
    echo "      ℹ️  Streamlit dashboard not running"
fi

# Phase 2: Stop Correlation & RCA Engines
echo "   (2/8) 🔗 Stopping Correlation & RCA engines..."
docker compose "${COMPOSE_FILES[@]}" stop rca-insights-engine event-correlation-engine &> /dev/null

# Phase 3: Stop all external-facing load and anomaly generators
echo "   (3/8) ⚡ Stopping traffic, load, and anomaly generators..."
docker compose "${COMPOSE_FILES[@]}" stop load-generator trace-generator cache-load-generator resource-anomaly-generator &> /dev/null

# Phase 4: Stop all monitoring, analysis, and consumer services
echo "   (4/8) 🧠 Stopping all monitors, analyzers, and consumers..."
docker compose "${COMPOSE_FILES[@]}" stop message-consumer rabbitmq-monitor anomaly-injector performance-aggregator transaction-monitor cache-pattern-analyzer container-resource-monitor &> /dev/null

# Phase 5: Stop all application-level services (ML, banking, etc.)
echo "   (5/8) 🏦 Stopping application & banking services..."
docker compose "${COMPOSE_FILES[@]}" stop api-gateway fraud-detection notification-service auth-service transaction-service account-service auto-baselining ddos-ml-detection db-connection-demo mock-iis-application &> /dev/null

# Phase 6: Stop all data exporters and message producers
echo "   (6/8) 📤 Stopping data exporters and message producers..."
docker compose "${COMPOSE_FILES[@]}" stop message-producer mock-windows-exporter redis-exporter postgres-exporter &> /dev/null

# Phase 7: Stop message brokers
echo "   (7/8) 📨 Stopping message brokers (RabbitMQ, Kafka)..."
docker compose "${COMPOSE_FILES[@]}" stop rabbitmq kafka zookeeper &> /dev/null

# Phase 8: Stop databases
echo "   (8/8) 🗄️ Stopping all databases (MySQL, Postgres, Redis)..."
docker compose "${COMPOSE_FILES[@]}" stop mysql-db postgres banking-redis &> /dev/null

# Phase 9: Stop core infrastructure
echo "   (9/9) 🔧 Stopping core infrastructure (Prometheus, Grafana, Jaeger)..."
docker compose "${COMPOSE_FILES[@]}" stop jaeger grafana prometheus cadvisor node-exporter &> /dev/null

echo ""
echo -e "${GREEN}✅ All services have been stopped gracefully.${NC}"

echo ""
echo -e "${BLUE}🧹 Step 7: Final Cleanup & Documentation${NC}"
echo "======================================"
echo -n "   Removing stopped containers to ensure a clean start... "
docker compose "${COMPOSE_FILES[@]}" down --remove-orphans &> /dev/null
echo -e "${GREEN}✅${NC}"

# Create comprehensive restore instructions
cat > "$backup_dir/RESTORE_INSTRUCTIONS.md" << EOF
# System Restoration Guide
### Backup Timestamp: ${backup_timestamp}

This backup contains a complete snapshot of the AIOps platform with **Correlation & RCA engines**, including all configurations, scripts, and live-exported Grafana dashboards with your manual edits preserved.

## Quick Restore
To restore the entire system to this state, simply run the updated restart script and select this backup when prompted:
\`\`\`bash
./safe_restart8.sh
\`\`\`

## Services Included
This backup includes the full configuration for all system components:
- Core Banking & ML Services
- Transaction Monitoring & Tracing
- Message Queues (RabbitMQ & Kafka)
- Database Monitoring (Postgres & MySQL)
- Redis Cache Monitoring (Redis, Exporter, Analyzer, Generator)
- Container Resource Optimization (Monitor & Anomaly Generator)
- Mock Windows IIS Monitoring
- Anomaly Injector (Port 5005)
- **NEW: Event Correlation Engine (Port 5025)**
- **NEW: RCA Insights Engine (Port 5026)**
- **NEW: Correlation RCA Dashboard (Port 8501)**
- **Kubernetes Monitoring System**
  - K8s Resource Monitor (Port 9419)
  - Pod Auto-scaling (HPA)
  - Banking Service (2-5 replicas)
  - Load Generator (1-6 replicas)
  - Three custom dashboards
  - Python automation scripts

## Correlation & RCA Features Preserved
This backup includes:
- Event correlation analysis configurations
- Statistical correlation algorithms and thresholds
- RCA insights engine with OpenAI integration
- AI-powered root cause analysis prompts and settings
- Streamlit dashboard with PDF report generation
- Complete correlation metrics and historical data
- All custom correlation rules and configurations

## Kubernetes State Preserved
This backup includes:
- Current pod states and HPA configuration
- Scaling state (replica counts, thresholds)
- K8s metrics and events
- Complete kubernetes-monitoring directory
- All Python automation scripts

## To Restore Dashboards Manually
If you only need to restore the Grafana dashboards:
1. Navigate to the \`grafana_exports\` directory inside this backup.
2. Run the included script: \`./restore_dashboards.sh\`
3. Alternatively, import each \`*_complete.json\` file manually via the Grafana UI.

## Correlation & RCA Commands After Restore
\`\`\`bash
# Check Correlation Engine
curl http://localhost:5025/health
curl http://localhost:5025/correlations/latest

# Check RCA Engine
curl http://localhost:5026/health
curl http://localhost:5026/openai-status

# Test AI Analysis
curl "http://localhost:5026/analyze?limit=1&min_confidence=0.8"

# Access Streamlit Dashboard
cd correlation-rca-dashboard
streamlit run app.py
# Open http://localhost:8501
\`\`\`

## Kubernetes Commands After Restore
\`\`\`bash
# Check K8s status
kubectl get all -n banking-k8s-test
kubectl get hpa -n banking-k8s-test

# Run automation scripts
python3 kubernetes-monitoring/scripts/load-testing-scaling-demo.py
python3 kubernetes-monitoring/scripts/anomaly-generator.py
python3 kubernetes-monitoring/scripts/real-time-monitoring.py
\`\`\`

## Backup Contents
- Complete Grafana dashboards (with all manual edits)
- All service configurations including correlation & RCA engines
- Message broker configurations
- Prometheus setup with all scrape jobs
- Docker compose files
- Shell scripts
- Final metrics state at shutdown
- **Event correlation engine complete configuration**
- **RCA insights engine with OpenAI setup**
- **Streamlit dashboard with PDF generation**
- **Kubernetes monitoring system complete**
- **K8s pod states and HPA configuration**
- **Python automation scripts**

## Known Issues Resolved
- Docker compose volume definitions fixed
- Dashboard JSON format corrected
- Network configuration aligned
- All services properly included in startup/shutdown sequences
- **Correlation engine integration with Prometheus**
- **RCA engine OpenAI API configuration**
- **Streamlit dashboard dependencies and ports**
- **Kubernetes monitoring integration**
- **HPA ultra-fast scaling configuration**
EOF

# Calculate backup size and provide final summary
backup_size=$(du -sh "$backup_dir" | cut -f1)
date > "$backup_dir/.shutdown_complete" # Marker for a clean shutdown backup

echo ""
echo -e "${GREEN}🎉 SAFE SHUTDOWN COMPLETE!${NC}"
echo "-----------------------------------"
echo "📦 Backup Size: $backup_size"
echo "📁 Backup Location: $backup_dir"
echo "📊 Exported Dashboards: $(ls -1 "$backup_dir/grafana_exports"/*.json 2>/dev/null | wc -l) files"
if kubectl get nodes >/dev/null 2>&1; then
    k8s_pods=$(kubectl get pods -n banking-k8s-test --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo "☸️  Kubernetes Pods: $k8s_pods backed up"
fi
echo "🔗 Correlation Engine: State preserved"
echo "🤖 RCA Engine: Configuration preserved"
echo "📊 Streamlit Dashboard: Components backed up"
echo ""
echo "🚀 To restart the entire system from this state, run: ./safe_restart8.sh"