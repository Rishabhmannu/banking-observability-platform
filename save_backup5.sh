#!/bin/bash

echo "💾 Save Backup v4.1 - Create Full System Backup with Kubernetes (No Shutdown)"
echo "============================================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Navigate to project directory
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" || {
    echo -e "${RED}❌ Could not find project directory${NC}"
    exit 1
}

echo "📂 Working from: $(pwd)"
echo "📅 Backup initiated at: $(date)"

# Create backup directory with timestamp
backup_timestamp=$(date +%Y%m%d_%H%M%S)
backup_dir="backups/$backup_timestamp"
mkdir -p "$backup_dir"

echo ""
echo -e "${BLUE}📥 Step 1: System Status Check${NC}"
echo "=============================="

# Check if system is running
running_containers=$(docker compose -f docker-compose.yml -f docker-compose.optimization.yml ps --services --filter "status=running" 2>/dev/null | wc -l)
if [ "$running_containers" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No Docker services are running. Backup will include current files only.${NC}"
else
    echo -e "${GREEN}✅ Found $running_containers running Docker services${NC}"
fi

# NEW: Check Kubernetes status
if kubectl get nodes >/dev/null 2>&1; then
    k8s_pods=$(kubectl get pods -n banking-k8s-test --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    k8s_total=$(kubectl get pods -n banking-k8s-test --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✅ Kubernetes cluster accessible: $k8s_pods/$k8s_total pods running${NC}"
else
    echo -e "${YELLOW}⚠️  Kubernetes cluster not accessible${NC}"
fi

echo ""
echo -e "${CYAN}☸️  Step 2: Kubernetes State Backup${NC}"
echo "=================================="

# NEW: Backup Kubernetes state and configurations
if kubectl get nodes >/dev/null 2>&1; then
    echo "📦 Capturing Kubernetes state and configurations..."
    mkdir -p "$backup_dir/kubernetes-state"
    
    # Backup current cluster state
    echo -n "   📊 Capturing cluster state... "
    kubectl get nodes -o yaml > "$backup_dir/kubernetes-state/nodes.yaml" 2>/dev/null
    kubectl get namespaces -o yaml > "$backup_dir/kubernetes-state/namespaces.yaml" 2>/dev/null
    echo -e "${GREEN}✅${NC}"
    
    # Backup banking-k8s-test namespace state
    echo -n "   🏦 Capturing banking namespace state... "
    kubectl get all -n banking-k8s-test -o yaml > "$backup_dir/kubernetes-state/banking-namespace-state.yaml" 2>/dev/null
    kubectl get hpa -n banking-k8s-test -o yaml > "$backup_dir/kubernetes-state/hpa-state.yaml" 2>/dev/null
    kubectl describe hpa -n banking-k8s-test > "$backup_dir/kubernetes-state/hpa-description.txt" 2>/dev/null
    echo -e "${GREEN}✅${NC}"
    
    # Backup current metrics and status
    echo -n "   📈 Capturing current metrics... "
    {
        echo "Kubernetes Live Metrics Backup - $(date)"
        echo "======================================="
        echo ""
        echo "### Cluster Overview ###"
        kubectl get nodes -o wide 2>/dev/null || echo "No nodes available"
        echo ""
        echo "### Namespace Status ###"
        kubectl get all -n banking-k8s-test 2>/dev/null || echo "Namespace not found"
        echo ""
        echo "### HPA Details ###"
        kubectl get hpa -n banking-k8s-test 2>/dev/null || echo "No HPA found"
        kubectl describe hpa -n banking-k8s-test 2>/dev/null || echo "No HPA details"
        echo ""
        echo "### Current Scaling State ###"
        banking_replicas=$(kubectl get deployment banking-service -n banking-k8s-test -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "N/A")
        banking_ready=$(kubectl get deployment banking-service -n banking-k8s-test -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "N/A")
        load_replicas=$(kubectl get deployment load-generator -n banking-k8s-test -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "N/A")
        load_ready=$(kubectl get deployment load-generator -n banking-k8s-test -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "N/A")
        echo "Banking Service: $banking_ready/$banking_replicas replicas"
        echo "Load Generator: $load_ready/$load_replicas replicas"
        echo ""
        echo "### Node Resource Usage ###"
        kubectl top nodes 2>/dev/null || echo "Node metrics not available"
        echo ""
        echo "### Pod Resource Usage ###"
        kubectl top pods -n banking-k8s-test 2>/dev/null || echo "Pod metrics not available"
        echo ""
        echo "### Recent Events ###"
        kubectl get events -n banking-k8s-test --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "No events found"
        echo ""
        echo "### K8s Resource Monitor Metrics ###"
        curl -s http://localhost:9419/metrics 2>/dev/null | head -20 || echo "K8s resource monitor not accessible"
        echo ""
        echo "### HPA Scaling Configuration ###"
        kubectl get hpa banking-service-hpa -n banking-k8s-test -o yaml 2>/dev/null | grep -A 20 "behavior:" || echo "No HPA behavior config found"
        
    } > "$backup_dir/kubernetes-state/live-metrics.txt"
    echo -e "${GREEN}✅${NC}"
    
    # Create restoration script for K8s state
    echo -n "   📜 Creating K8s restoration script... "
    cat > "$backup_dir/kubernetes-state/restore_k8s_state.sh" << 'EOF'
#!/bin/bash
echo "🔄 Restoring Kubernetes state from backup..."
echo "==========================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "❌ Kubernetes cluster is not accessible"
    exit 1
fi

echo "📦 Applying Kubernetes manifests..."
if [ -f "../kubernetes-monitoring/k8s-manifests/namespace.yaml" ]; then
    kubectl apply -f ../kubernetes-monitoring/k8s-manifests/namespace.yaml
    echo "✅ Namespace applied"
else
    echo "⚠️  Namespace manifest not found"
fi

if [ -d "../kubernetes-monitoring/k8s-manifests/deployments/" ]; then
    kubectl apply -f ../kubernetes-monitoring/k8s-manifests/deployments/
    echo "✅ Deployments applied"
else
    echo "⚠️  Deployment manifests not found"
fi

if [ -d "../kubernetes-monitoring/k8s-manifests/services/" ]; then
    kubectl apply -f ../kubernetes-monitoring/k8s-manifests/services/
    echo "✅ Services applied"
else
    echo "⚠️  Service manifests not found"
fi

if [ -d "../kubernetes-monitoring/k8s-manifests/hpa/" ]; then
    kubectl apply -f ../kubernetes-monitoring/k8s-manifests/hpa/
    echo "✅ HPA applied"
else
    echo "⚠️  HPA manifests not found"
fi

if [ -d "../kubernetes-monitoring/monitoring/kube-state-metrics/" ]; then
    kubectl apply -f ../kubernetes-monitoring/monitoring/kube-state-metrics/
    echo "✅ Kube-state-metrics applied"
else
    echo "⚠️  Kube-state-metrics manifests not found"
fi

echo ""
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod -l app=banking-service -n banking-k8s-test --timeout=300s
kubectl wait --for=condition=Ready pod -l app=load-generator -n banking-k8s-test --timeout=300s
kubectl wait --for=condition=Ready pod -l app=k8s-resource-monitor -n banking-k8s-test --timeout=300s

echo ""
echo "📊 Final status:"
kubectl get all -n banking-k8s-test
kubectl get hpa -n banking-k8s-test

echo ""
echo "🎉 Kubernetes state restoration complete!"
echo "📊 Check status with: kubectl get all -n banking-k8s-test"
echo "🎯 Run automation: python3 kubernetes-monitoring/scripts/load-testing-scaling-demo.py"
EOF
    chmod +x "$backup_dir/kubernetes-state/restore_k8s_state.sh"
    echo -e "${GREEN}✅${NC}"
    
else
    echo -e "${YELLOW}⚠️  Kubernetes cluster not accessible. Skipping K8s state backup.${NC}"
fi

echo ""
echo -e "${BLUE}📊 Step 3: Backing Up Grafana Dashboards${NC}"
echo "======================================="

# Export all Grafana dashboards if Grafana is running
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo "💾 Exporting all Grafana dashboards..."
    echo "   This preserves your manual edits including K8s dashboards!"
    
    # Get all dashboards
    dashboards=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null)
    
    if [ ! -z "$dashboards" ]; then
        mkdir -p "$backup_dir/grafana_exports"
        
        dashboard_count=0
        k8s_dashboards=0
        echo "$dashboards" | jq -r '.[] | .uid + ":" + .title' | while IFS=: read -r uid title; do
            echo -n "   Exporting $title... "
            
            # Get the CURRENT state of the dashboard (including unsaved changes)
            dashboard_json=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/dashboards/uid/$uid" 2>/dev/null)
            
            if [ ! -z "$dashboard_json" ]; then
                # Save complete dashboard with metadata
                echo "$dashboard_json" > "$backup_dir/grafana_exports/${uid}_complete.json"
                
                # Also save just the dashboard portion for easier import
                echo "$dashboard_json" | jq '.dashboard' > "$backup_dir/grafana_exports/${title// /_}.json"
                
                # Save dashboard metadata separately
                echo "$dashboard_json" | jq '{meta: .meta, uid: .dashboard.uid, version: .dashboard.version}' > "$backup_dir/grafana_exports/${uid}_metadata.json"
                
                # Check if this is a Kubernetes dashboard
                if echo "$title" | grep -qE -i "(kubernetes|k8s|pod|node|hpa|autoscal)"; then
                    echo -e "${CYAN}✅ K8s${NC}"
                    ((k8s_dashboards++))
                else
                    echo -e "${GREEN}✅${NC}"
                fi
                ((dashboard_count++))
            else
                echo -e "${RED}❌${NC}"
            fi
        done
        
        echo "   📊 Total dashboards exported: $dashboard_count"
        echo "   ☸️  Kubernetes dashboards: $k8s_dashboards"
        
        # Create dashboard restore script
        cat > "$backup_dir/grafana_exports/restore_dashboards.sh" << 'EOF'
#!/bin/bash
echo "🔄 Restoring Grafana dashboards..."
for file in *_complete.json; do
    if [ -f "$file" ]; then
        uid=$(basename "$file" _complete.json)
        title=$(jq -r '.dashboard.title // "Unknown"' "$file")
        echo -n "Restoring '$title'... "
        
        dashboard_data=$(cat "$file" | jq '.dashboard')
        import_payload=$(jq -n --argjson dash "$dashboard_data" '{"dashboard": $dash, "overwrite": true, "inputs": [], "folderId": 0}')
        
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -u admin:bankingdemo \
            -d "$import_payload" \
            http://localhost:3000/api/dashboards/import)
        
        if echo "$response" | grep -q "success"; then
            echo "✅"
        else
            echo "❌"
            echo "Error: $response"
        fi
    fi
done
echo "✅ Dashboard restoration complete!"
EOF
        chmod +x "$backup_dir/grafana_exports/restore_dashboards.sh"
        
        echo -e "${GREEN}✅ Exported all dashboards successfully${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Grafana not accessible. Skipping dashboard export.${NC}"
fi

echo ""
echo -e "${BLUE}📁 Step 4: Backing Up Configuration Files${NC}"
echo "========================================"

# Function to backup directory/file
backup_item() {
    local item=$1
    local display_name=${2:-$item}
    
    if [ -e "$item" ]; then
        echo -n "   Backing up $display_name... "
        cp -r "$item" "$backup_dir/"
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "   ${YELLOW}⚠️  $display_name not found${NC}"
    fi
}

# Backup all important directories and files
backup_item "prometheus" "Prometheus configuration"
backup_item "grafana" "Grafana configuration"
backup_item "grafana-dashboards" "Grafana dashboard files"
backup_item "src" "Source code"
backup_item "transaction-monitor" "Transaction Monitor"
backup_item "performance-aggregator" "Performance Aggregator"
backup_item "anomaly-injector" "Anomaly Injector"
backup_item "mock-windows-exporter" "Windows Exporter"
backup_item "mock-iis-application" "IIS Application"
backup_item "trace-generator" "Trace Generator"
backup_item "message-producer" "Message Producer"
backup_item "message-consumer" "Message Consumer"
backup_item "rabbitmq-monitor" "RabbitMQ Monitor"
backup_item "db-connection-demo" "DB Connection Demo"
backup_item "message-brokers" "Message Brokers Config"
backup_item "scripts" "Shell scripts"

# Backup Redis & Container Optimization services
backup_item "redis" "Redis Config"
backup_item "redis-cache-analyzer" "Redis Cache Analyzer"
backup_item "redis-cache-load-generator" "Redis Load Generator"
backup_item "container-resource-monitor" "Container Monitor"
backup_item "resource-anomaly-generator" "Resource Anomaly Generator"
backup_item "k6-scripts" "k6 Load Testing Scripts"
backup_item "shared" "Shared Libraries (Cache)"

# NEW: Backup Kubernetes monitoring system
backup_item "kubernetes-monitoring" "Kubernetes Monitoring System"

# Backup compose files
echo -n "   Backing up Docker Compose files... "
for file in docker-compose*.yml; do
    [ -f "$file" ] && cp "$file" "$backup_dir/"
done
echo -e "${GREEN}✅${NC}"

# Backup shell scripts
echo -n "   Backing up shell scripts... "
cp *.sh "$backup_dir/" 2>/dev/null
echo -e "${GREEN}✅${NC}"

echo ""
echo -e "${BLUE}📈 Step 5: Capturing Current Metrics State${NC}"
echo "========================================="

# Capture current metrics state if services are running
if [ "$running_containers" -gt 0 ]; then
    echo -n "   Capturing metrics state... "
    {
        echo "Metrics State Snapshot - $(date)"
        echo "================================"
        echo ""
        
        # Prometheus targets
        echo "Prometheus Targets:"
        curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"' 2>/dev/null || echo "Prometheus not accessible"
        echo ""
        
        # Redis and Container Optimization Metrics
        echo "Redis Cache Status:"
        curl -s http://localhost:5012/cache-stats 2>/dev/null | jq '.' || echo "Cache analyzer not accessible"
        echo ""

        echo "Container Optimization Recommendations:"
        curl -s http://localhost:5010/recommendations 2>/dev/null | jq '.' || echo "Container monitor not accessible"
        echo ""
        
        # RabbitMQ Monitor metrics
        echo "RabbitMQ Queue Monitor Status:"
        curl -s http://localhost:9418/health 2>/dev/null | jq '.' || echo "RabbitMQ monitor not accessible"
        echo ""
        
        echo "RabbitMQ Queue Depths (from Monitor):"
        curl -s http://localhost:9418/metrics | grep "rabbitmq_queue_messages_ready" | grep -v "^#" 2>/dev/null || echo "No queue metrics available"
        echo ""
        
        # Message queue stats
        echo "Message Queue Stats:"
        curl -s http://localhost:5007/metrics | grep -E "(messages_published_total|message_publish_duration_seconds_count)" 2>/dev/null || echo "Message producer not accessible"
        echo ""
        
        # DB connection stats
        echo "Database Connection Pool:"
        curl -s http://localhost:5009/metrics | grep -E "(db_pool_|db_query_)" 2>/dev/null || echo "DB connection demo not accessible"
        echo ""
        
        # Jaeger traces
        echo "Jaeger Traces:"
        curl -s "http://localhost:16686/api/services" | jq -r '.data[]' 2>/dev/null || echo "Jaeger not accessible"
        echo ""
        
        # NEW: Kubernetes monitoring metrics
        echo "Kubernetes Monitoring Metrics:"
        curl -s http://localhost:9419/metrics 2>/dev/null | head -30 || echo "K8s resource monitor not accessible"
        
    } > "$backup_dir/live_metrics_snapshot.txt"
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️  No running services to capture metrics from${NC}"
fi

# List running containers
if [ "$running_containers" -gt 0 ]; then
    echo -n "   Listing running services... "
    docker compose -f docker-compose.yml -f docker-compose.optimization.yml ps > "$backup_dir/running_services.txt" 2>&1
    echo -e "${GREEN}✅${NC}"
fi

echo ""
echo -e "${BLUE}📋 Step 6: Creating Backup Documentation${NC}"
echo "========================================"

# Create comprehensive restore instructions
cat > "$backup_dir/RESTORE_INSTRUCTIONS.md" << EOF
# System Backup with Kubernetes Monitoring - $backup_timestamp
Generated while system was $([ "$running_containers" -gt 0 ] && echo "RUNNING" || echo "STOPPED")

## Quick Restore
Run: \`./safe_restart6.sh\` and select this backup when prompted

## Backup Contents
- Complete Grafana dashboards (including all manual edits)
- All service configurations including RabbitMQ Monitor
- Redis Cache and Container Optimization configs
- Message broker configurations  
- Prometheus setup with monitor scrape job
- Docker compose files
- Shell scripts including updated system management scripts
- **NEW: Complete Kubernetes Monitoring System**
  - K8s Resource Monitor (Port 9419)
  - Pod Auto-scaling (HPA) configurations
  - Banking Service and Load Generator manifests
  - Kubernetes state snapshots
  - Python automation scripts
$([ "$running_containers" -gt 0 ] && echo "- Live metrics snapshot with cache & container status")
$([ "$running_containers" -gt 0 ] && echo "- Running services list")
$(kubectl get nodes >/dev/null 2>&1 && echo "- Kubernetes cluster state and pod configurations")

## Kubernetes Components Included
- **Namespace**: banking-k8s-test with resource quotas
- **Deployments**: banking-service (2-5 replicas), load-generator (1-6 replicas)
- **HPA**: Ultra-fast scaling configuration (6% CPU threshold)
- **Services**: banking-service, k8s-resource-monitor  
- **Monitoring**: kube-state-metrics, custom resource monitor
- **Automation Scripts**: 
  - load-testing-scaling-demo.py
  - anomaly-generator.py
  - real-time-monitoring.py
- **Dashboards**: Kubernetes Overview, Pod Auto-scaling, Node Consumption

## Manual Dashboard Restoration
If dashboards need to be restored manually:
1. Navigate to grafana_exports directory
2. Run: ./restore_dashboards.sh
3. Or import each *_complete.json file via Grafana UI

## Kubernetes Restoration
If K8s services need to be restored manually:
1. Navigate to kubernetes-state directory
2. Run: ./restore_k8s_state.sh
3. Or apply manifests individually from kubernetes-monitoring/k8s-manifests/

## Services Included in Backup
- Core banking services
- DDoS detection and auto-baselining
- Transaction monitoring suite
- Windows IIS monitoring
- Transaction tracing with Jaeger
- RabbitMQ and Kafka messaging
- RabbitMQ Queue Monitor (port 9418)
- PostgreSQL connection pool demo
- Redis Cache Monitoring (6379, 9121, 5012, 5013)
- Container Resource Optimization (5010, 5011)
- **Kubernetes Monitoring System (9419)**
- **Pod Auto-scaling with HPA**
- **K8s Resource Monitor and Dashboards**

## To Use This Backup
1. Run: ./safe_restart6.sh
2. When prompted for backup selection, choose: $backup_timestamp
3. The system will restore all configurations and dashboards
4. Kubernetes services will be automatically deployed

## Post-Restore Verification
### Docker Services
\`\`\`bash
./system_status6.sh
\`\`\`

### Kubernetes Services
\`\`\`bash
kubectl get all -n banking-k8s-test
kubectl get hpa -n banking-k8s-test
kubectl top nodes
\`\`\`

### Run Automation Scripts
\`\`\`bash
python3 kubernetes-monitoring/scripts/load-testing-scaling-demo.py
python3 kubernetes-monitoring/scripts/real-time-monitoring.py
\`\`\`

## Notes
- This backup was created without stopping the system
- All dashboard edits and configurations are preserved
- Kubernetes state and HPA configurations are captured
- The backup can be used to restore the system to this exact state
- Redis Cache, Container monitor, and K8s monitoring configurations are included
- Ultra-fast HPA scaling configuration is preserved
EOF

# Calculate backup size
backup_size=$(du -sh "$backup_dir" | cut -f1)

# Create a marker file to indicate this is a valid backup
date > "$backup_dir/.backup_complete"

echo ""
echo -e "${GREEN}🎉 BACKUP COMPLETE!${NC}"
echo ""
echo "📦 Backup size: $backup_size"
echo "📁 Backup location: $backup_dir"
echo "📊 Dashboard exports: $(ls -1 $backup_dir/grafana_exports/*.json 2>/dev/null | wc -l) files"
echo "🏃 Docker status: $([ "$running_containers" -gt 0 ] && echo "Running ($running_containers services)" || echo "Stopped")"
if kubectl get nodes >/dev/null 2>&1; then
    k8s_pods=$(kubectl get pods -n banking-k8s-test --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    echo "☸️  Kubernetes status: $k8s_pods pods running"
fi
echo ""
echo "✨ Your backup has been created successfully!"
echo "🔄 To restore from this backup: ./safe_restart6.sh"
echo ""
echo -e "${BLUE}💡 Tip:${NC} This backup can be used to:"
echo "  • Restore after system issues"
echo "  • Replicate your setup on another machine"
echo "  • Create a checkpoint before major changes"
echo "  • Preserve Redis, Container, RabbitMQ, and K8s Monitor configuration"
echo "  • Restore Kubernetes monitoring with all dashboards and automation"
echo ""
echo -e "${CYAN}☸️  Kubernetes Features Backed Up:${NC}"
echo "  • Pod auto-scaling (HPA) with ultra-fast configuration"
echo "  • Banking service and load generator deployments"
echo "  • Custom resource monitoring (port 9419)"
echo "  • Three professional Grafana dashboards"
echo "  • Python automation scripts for load testing and monitoring"
echo "  • Complete namespace configuration with resource quotas"