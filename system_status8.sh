#!/bin/bash

echo "📊 System Status v8.0 - Complete AIOps Platform with Correlation & RCA Engines"
echo "=============================================================================="
echo "$(date)"
echo ""

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
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" 2>/dev/null || {
    echo -e "${RED}⚠️  Warning: Could not find project directory. Running from current location.${NC}"
}

# Define all docker-compose files used by the system. This makes the script modular and easy to manage.
COMPOSE_FILES=(
    -f docker-compose.yml
    -f docker-compose.transaction-monitoring.yml
    -f docker-compose.tracing.yml
    -f docker-compose.messaging.yml
    -f docker-compose.db-demo.yml
    -f docker-compose.optimization.yml
)

echo -e "${BLUE}🐳 Docker Container Overview${NC}"
echo "============================="
running=$(docker compose "${COMPOSE_FILES[@]}" ps --services --filter "status=running" 2>/dev/null | wc -l | tr -d '[:space:]')
total=$(docker compose "${COMPOSE_FILES[@]}" ps --services 2>/dev/null | wc -l | tr -d '[:space:]')
echo "Containers: $running/$total running"

# Kubernetes Overview
echo ""
echo -e "${CYAN}☸️  Kubernetes Cluster Overview${NC}"
echo "==============================="
if kubectl get nodes >/dev/null 2>&1; then
    # Cluster status
    cluster_status=$(kubectl get nodes --no-headers | awk '{print $2}' | head -1)
    echo "Cluster Status: ${cluster_status}"
    
    # Namespace status
    if kubectl get namespace banking-k8s-test >/dev/null 2>&1; then
        running_pods=$(kubectl get pods -n banking-k8s-test --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        total_pods=$(kubectl get pods -n banking-k8s-test --no-headers 2>/dev/null | wc -l | tr -d ' ')
        echo "K8s Pods: $running_pods/$total_pods running"
        
        # HPA status
        hpa_status=$(kubectl get hpa banking-service-hpa -n banking-k8s-test --no-headers 2>/dev/null)
        if [ ! -z "$hpa_status" ]; then
            current_replicas=$(echo "$hpa_status" | awk '{print $7}')
            desired_replicas=$(echo "$hpa_status" | awk '{print $6}')
            cpu_percent=$(echo "$hpa_status" | awk '{print $3}' | cut -d'/' -f1)
            cpu_target=$(echo "$hpa_status" | awk '{print $3}' | cut -d'/' -f2)
            echo "HPA Status: $current_replicas/$desired_replicas replicas, CPU: $cpu_percent/$cpu_target"
        else
            echo "HPA Status: Not configured"
        fi
    else
        echo "Banking K8s Namespace: Not found"
    fi
else
    echo -e "${RED}❌ Kubernetes cluster not accessible${NC}"
fi

echo ""

# --- Health Checks by Service Group ---

echo -e "${BLUE}🏥 Core Infrastructure Health${NC}"
echo "============================"
# Banking API
echo -n "🏦 Banking API Gateway (8080): "
if curl -s --connect-timeout 2 http://localhost:8080/health >/dev/null 2>&1; then echo -e "${GREEN}✅ HEALTHY${NC}"; else echo -e "${RED}❌ DOWN${NC}"; fi
# Prometheus
echo -n "📊 Prometheus (9090): "
if curl -s --connect-timeout 2 http://localhost:9090/-/healthy >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    targets_up=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -r '[.data.activeTargets[] | select(.health=="up")] | length' 2>/dev/null || echo "0")
    targets_total=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
    echo "   🎯 Targets: $targets_up/$targets_total UP"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Grafana
echo -n "📈 Grafana (3000): "
if curl -s --connect-timeout 2 http://localhost:3000/api/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    dashboard_count=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    echo "   🎨 Dashboards: $dashboard_count loaded"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${PURPLE}🗄️ Database & Cache Layer${NC}"
echo "=========================="
# MySQL
echo -n "🐬 MySQL DB (3306): "
if docker exec banking-mysql mysqladmin ping --silent >/dev/null 2>&1; then echo -e "${GREEN}✅ HEALTHY${NC}"; else echo -e "${RED}❌ DOWN${NC}"; fi
# PostgreSQL
echo -n "🐘 PostgreSQL (5432): "
if docker exec banking-postgres pg_isready -q -U bankinguser >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    conn_count=$(docker exec banking-postgres psql -U bankinguser -d bankingdb -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='bankingdb';" 2>/dev/null | tr -d ' ' || echo 0)
    echo "   🔗 Active connections: ${conn_count:-0}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Redis Cache
echo -n "💾 Redis Cache (6379): "
if docker exec banking-redis redis-cli ping | grep -q "PONG" 2>/dev/null; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    keys_count=$(docker exec banking-redis redis-cli DBSIZE 2>/dev/null | tr -d '\r')
    memory_usage=$(docker exec banking-redis redis-cli INFO memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
    echo "   🔑 Keys: $keys_count | 🧠 Memory:$memory_usage"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# DB Connection Demo Service
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
echo -e "${BLUE}📨 Message Queue Services${NC}"
echo "========================="
# RabbitMQ
echo -n "🐰 RabbitMQ (5672/15672): "
if docker exec banking-rabbitmq rabbitmq-diagnostics ping >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    queue_count=$(docker exec banking-rabbitmq rabbitmqctl list_queues -p / name messages | grep -v "name" | wc -l 2>/dev/null || echo "0")
    echo "   📋 Queues: $queue_count configured"
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
echo -n "⚫ Kafka (9092): "
if docker exec banking-kafka timeout 5 kafka-topics.sh --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    topics=$(docker exec banking-kafka kafka-topics.sh --bootstrap-server localhost:9092 --list 2>/dev/null | wc -l | tr -d ' ')
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
    messages_published=$(curl -s http://localhost:5007/metrics | grep 'banking_messages_published_total' | awk '{sum += $NF} END {print int(sum)}' 2>/dev/null)
    echo "   🔗 Connections: RabbitMQ($rabbitmq_status) Kafka($kafka_status) | 📨 Published: ${messages_published:-0}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Message Consumer
echo -n "📥 Message Consumer (5008): "
if curl -s --connect-timeout 2 http://localhost:5008/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    messages_consumed=$(curl -s http://localhost:5008/metrics | grep 'banking_messages_consumed_total' | awk '{sum += $NF} END {print int(sum)}' 2>/dev/null)
    echo "   📨 Messages consumed: ${messages_consumed:-0}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${CYAN}🤖 AIOps & Core Monitoring Services${NC}"
echo "===================================="
# DDoS Detection
echo -n "🛡️  DDoS ML Detection (5001): "
if curl -s --connect-timeout 2 http://localhost:5001/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    score=$(curl -s "http://localhost:9090/api/v1/query?query=ddos_detection_score" | jq -r '.data.result[0].value[1] // "N/A"' 2>/dev/null)
    echo "   📊 Current score: $score"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Auto-Baselining
echo -n "🎯 Auto-Baselining (5002): "
if curl -s --connect-timeout 2 http://localhost:5002/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    health=$(curl -s http://localhost:5002/health 2>/dev/null)
    algorithms=$(echo "$health" | jq -r '.algorithms | length' 2>/dev/null || echo "0")
    recommendations=$(echo "$health" | jq -r '.recommendations_count' 2>/dev/null || echo "0")
    echo "   🧠 Algorithms: $algorithms | 📊 Recommendations: $recommendations"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Transaction Monitor
echo -n "💰 Transaction Monitor (5003): "
if curl -s --connect-timeout 2 http://localhost:5003/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    stats=$(curl -s http://localhost:5003/stats 2>/dev/null)
    total=$(echo "$stats" | jq -r '.total_count // 0' 2>/dev/null)
    echo "   💳 Transactions: $total processed"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Performance Aggregator
echo -n "📈 Performance Aggregator (5004): "
if curl -s --connect-timeout 2 http://localhost:5004/health >/dev/null 2>&1; then echo -e "${GREEN}✅ HEALTHY${NC}"; else echo -e "${RED}❌ DOWN${NC}"; fi
# Anomaly Injector
echo -n "🎭 Anomaly Injector (5005): "
if curl -s --connect-timeout 2 http://localhost:5005/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    active=$(curl -s http://localhost:5005/health | jq -r '.active_injections // 0' 2>/dev/null)
    echo "   💉 Active anomalies: $active"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo ""
echo -e "${PURPLE}🔗 Correlation & RCA Services${NC}"
echo "============================="
# Event Correlation Engine
echo -n "🔗 Event Correlation Engine (5025): "
correlation_health=$(curl -s http://localhost:5025/health 2>/dev/null)
if [ ! -z "$correlation_health" ]; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    correlation_status=$(echo "$correlation_health" | jq -r '.status // "UNKNOWN"' 2>/dev/null)
    correlation_count=$(curl -s http://localhost:5025/correlations/latest 2>/dev/null | jq -r '.correlations | length // 0' 2>/dev/null)
    echo "   📊 Status: $correlation_status | Recent correlations: $correlation_count"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# RCA Insights Engine
echo -n "🤖 RCA Insights Engine (5026): "
rca_health=$(curl -s http://localhost:5026/health 2>/dev/null)
if [ ! -z "$rca_health" ]; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    rca_status=$(echo "$rca_health" | jq -r '.status // "UNKNOWN"' 2>/dev/null)
    openai_status=$(curl -s http://localhost:5026/openai-status 2>/dev/null | jq -r '.status // "UNKNOWN"' 2>/dev/null)
    echo "   🧠 Status: $rca_status | OpenAI: $openai_status"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Correlation RCA Dashboard
echo -n "📊 Correlation RCA Dashboard (8501): "
if curl -s --connect-timeout 3 http://localhost:8501/_stcore/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    echo "   🌐 Dashboard: Accessible via web interface"
else
    echo -e "${RED}❌ DOWN${NC}"
    # Check if Streamlit process is running
    if pgrep -f "streamlit run app.py" > /dev/null 2>&1; then
        echo "   ⚠️  Process running but not responding"
    else
        echo "   🔴 Process not running"
    fi
fi

echo ""
echo -e "${YELLOW}🔍 Distributed Tracing & IIS${NC}"
echo "==========================="
# Jaeger
echo -n "🔍 Jaeger UI (16686): "
if curl -sL --connect-timeout 2 http://localhost:16686 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    services=$(curl -s "http://localhost:16686/jaeger/api/services" 2>/dev/null | jq -r '.data | length' 2>/dev/null || echo "0")
    echo "   📊 Services traced: $services"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Trace Generator
echo -n "🔄 Trace Generator (9414): "
if curl -s --connect-timeout 2 http://localhost:9414/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    traces_total=$(curl -s http://localhost:9414/metrics 2>/dev/null | grep -E "traces_generated_total{" | awk '{sum += $NF} END {print int(sum)}')
    traces_per_min=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(traces_generated_total[1m]))*60" | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null | cut -d. -f1)
    echo "   📊 Total: ${traces_total:-0} | Rate: ${traces_per_min:-0}/min"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Windows Exporter
echo -n "🪟 Windows Exporter (9182): "
if curl -s --connect-timeout 2 http://localhost:9182/health >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    iis_metrics=$(curl -s http://localhost:9182/metrics 2>/dev/null | grep -c "windows_iis_requests_total" || echo "0")
    echo "   📈 IIS sites monitored: $((iis_metrics / 3))"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# IIS Application
echo -n "🌐 IIS Mock App (8090): "
if curl -s --connect-timeout 2 http://localhost:8090/health >/dev/null 2>&1; then echo -e "${GREEN}✅ HEALTHY${NC}"; else echo -e "${RED}❌ DOWN${NC}"; fi

echo ""
echo -e "${CYAN}⚙️ Cache & Container Optimization${NC}"
echo "================================="
# Cache Pattern Analyzer
echo -n "🧠 Cache Analyzer (5012): "
if curl -s --connect-timeout 2 http://localhost:5012/metrics > /dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    hit_ratio=$(curl -s http://localhost:5012/metrics 2>/dev/null | grep 'redis_cache_hit_ratio' | awk '{print $2}')
    if [[ ! -z "$hit_ratio" ]]; then
        printf "   🎯 Hit Ratio: %.1f%%\n" $(echo "$hit_ratio * 100" | bc -l)
    else
        echo "   🎯 Hit Ratio: N/A"
    fi
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Container Resource Monitor
echo -n "💪 Container Monitor (5010): "
if curl -s --connect-timeout 2 http://localhost:5010/metrics > /dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    recs=$(curl -s http://localhost:5010/recommendations 2>/dev/null)
    analyzed_count=$(echo "$recs" | jq -r '.total_containers_analyzed // 0' 2>/dev/null)
    savings=$(echo "$recs" | jq -r '.total_potential_savings_dollars // 0' 2>/dev/null)
    echo "   📦 Containers Analyzed: $analyzed_count | 💵 Potential Savings: \$$savings"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Cache Load Gen (5013):
echo -n "🚦 Cache Load Gen (5013): "
if curl -s --connect-timeout 2 http://localhost:5013/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    status=$(curl -s http://localhost:5013/stats 2>/dev/null | jq -r '.is_generating // false' | sed 's/true/active/;s/false/inactive/')
    echo "   📋 Status: $status"
else
    echo -e "${RED}❌ DOWN${NC}"
fi
# Resource Anomaly Generator
echo -n "🔥 Resource Anomaly Gen (5011): "
if curl -s --connect-timeout 2 http://localhost:5011/status >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HEALTHY${NC}"
    active_anomalies=$(curl -s http://localhost:5011/status 2>/dev/null | jq -r '.active_scenarios | length')
    echo "   📋 Active Anomalies: ${active_anomalies:-0}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

# Kubernetes Monitoring Services
echo ""
echo -e "${CYAN}☸️  Kubernetes Monitoring Services${NC}"
echo "=================================="
if kubectl get nodes >/dev/null 2>&1; then
    # K8s Resource Monitor
    echo -n "📊 K8s Resource Monitor (9419): "
    if curl -s --connect-timeout 2 http://localhost:9419/metrics >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
        hpa_metrics=$(curl -s http://localhost:9419/metrics 2>/dev/null | grep -c "k8s_hpa_replicas" || echo "0")
        pod_metrics=$(curl -s http://localhost:9419/metrics 2>/dev/null | grep -c "k8s_pod_count" || echo "0")
        echo "   📈 HPA Metrics: $hpa_metrics | Pod Metrics: $pod_metrics"
    else
        echo -e "${RED}❌ DOWN${NC}"
    fi
    
    # Banking Service Pods
    echo -n "🏦 Banking Service Pods: "
    banking_pods=$(kubectl get pods -n banking-k8s-test -l app=banking-service --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    banking_total=$(kubectl get pods -n banking-k8s-test -l app=banking-service --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$banking_pods" -gt 0 ]; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
        echo "   🐳 Pods: $banking_pods/$banking_total running"
    else
        echo -e "${RED}❌ DOWN${NC}"
    fi
    
    # Load Generator Pods
    echo -n "⚡ Load Generator Pods: "
    load_pods=$(kubectl get pods -n banking-k8s-test -l app=load-generator --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    load_total=$(kubectl get pods -n banking-k8s-test -l app=load-generator --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$load_pods" -gt 0 ]; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
        echo "   🐳 Pods: $load_pods/$load_total running"
    else
        echo -e "${RED}❌ DOWN${NC}"
    fi
    
    # HPA Status
    echo -n "🎯 HPA Auto-scaler: "
    if kubectl get hpa banking-service-hpa -n banking-k8s-test >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
        hpa_details=$(kubectl get hpa banking-service-hpa -n banking-k8s-test --no-headers 2>/dev/null)
        if [ ! -z "$hpa_details" ]; then
            current_replicas=$(echo "$hpa_details" | awk '{print $7}')
            desired_replicas=$(echo "$hpa_details" | awk '{print $6}')
            cpu_current=$(echo "$hpa_details" | awk '{print $3}' | cut -d'/' -f1)
            cpu_target=$(echo "$hpa_details" | awk '{print $3}' | cut -d'/' -f2)
            min_replicas=$(echo "$hpa_details" | awk '{print $4}')
            max_replicas=$(echo "$hpa_details" | awk '{print $5}')
            
            echo "   📊 Replicas: $current_replicas/$desired_replicas (min: $min_replicas, max: $max_replicas)"
            echo "   🔥 CPU: $cpu_current/$cpu_target"
            
            # Scaling status
            if [ "$current_replicas" -lt "$desired_replicas" ]; then
                echo "   📈 Status: SCALING UP"
            elif [ "$current_replicas" -gt "$desired_replicas" ]; then
                echo "   📉 Status: SCALING DOWN"
            else
                echo "   ✅ Status: STABLE"
            fi
        fi
    else
        echo -e "${RED}❌ DOWN${NC}"
    fi
    
    # Node Resource Usage
    echo -n "🖥️  Node Resources: "
    node_resources=$(kubectl top nodes 2>/dev/null | tail -n +2 | head -1)
    if [ ! -z "$node_resources" ]; then
        echo -e "${GREEN}✅ MONITORED${NC}"
        cpu_usage=$(echo "$node_resources" | awk '{print $2}')
        cpu_percent=$(echo "$node_resources" | awk '{print $3}')
        memory_usage=$(echo "$node_resources" | awk '{print $4}')
        memory_percent=$(echo "$node_resources" | awk '{print $5}')
        echo "   💾 CPU: $cpu_usage ($cpu_percent) | Memory: $memory_usage ($memory_percent)"
    else
        echo -e "${RED}❌ NO METRICS${NC}"
    fi
    
else
    echo -e "${RED}❌ Kubernetes cluster not accessible${NC}"
fi

echo ""
echo -e "${BLUE}🎯 System Integration Summary${NC}"
echo "============================="
healthy_count=0
services_to_check=(
    "http://localhost:8080/health" "http://localhost:5001/health" "http://localhost:5002/health" "http://localhost:5003/health"
    "http://localhost:5004/health" "http://localhost:5005/health" "http://localhost:5007/health" "http://localhost:5008/health"
    "http://localhost:5009/health" "http://localhost:9418/health" "http://localhost:9182/health" "http://localhost:8090/health"
    "http://localhost:9414/health" "http://localhost:16686" "http://localhost:9090/-/healthy" "http://localhost:3000/api/health"
    "http://localhost:5012/metrics" "http://localhost:5010/metrics" "http://localhost:5013/status" "http://localhost:5011/status"
    "http://localhost:5025/health" "http://localhost:5026/health"
)

# Add Kubernetes service check
if kubectl get nodes >/dev/null 2>&1; then
    services_to_check+=("http://localhost:9419/metrics")
fi

# Add Streamlit dashboard check
if pgrep -f "streamlit run app.py" > /dev/null 2>&1; then
    services_to_check+=("http://localhost:8501/_stcore/health")
fi

auth_services=("http://admin:bankingdemo@localhost:15672/api/overview")
docker_checks=("banking-rabbitmq:rabbitmq-diagnostics ping" "banking-postgres:pg_isready -q -U bankinguser" "banking-redis:redis-cli ping" "banking-mysql:mysqladmin ping --silent")

# Add Kubernetes checks
k8s_checks=0
if kubectl get nodes >/dev/null 2>&1; then
    k8s_checks=3  # cluster, namespace, HPA
fi

total_services=$((${#services_to_check[@]} + ${#docker_checks[@]} + ${#auth_services[@]} + k8s_checks))

for url in "${services_to_check[@]}"; do
    curl -sL --connect-timeout 2 "$url" >/dev/null 2>&1 && ((healthy_count++))
done

for url in "${auth_services[@]}"; do
    curl -sL --connect-timeout 2 "$url" >/dev/null 2>&1 && ((healthy_count++))
done

for check in "${docker_checks[@]}"; do
    IFS=: read -r c cmd <<<"$check"
    docker exec "$c" $cmd >/dev/null 2>&1 && ((healthy_count++))
done

# Kubernetes health checks
if kubectl get nodes >/dev/null 2>&1; then
    kubectl get nodes | grep -q "Ready" && ((healthy_count++))
    kubectl get namespace banking-k8s-test >/dev/null 2>&1 && ((healthy_count++))
    kubectl get hpa banking-service-hpa -n banking-k8s-test >/dev/null 2>&1 && ((healthy_count++))
fi

if [ $healthy_count -eq $total_services ]; then
    echo -e "🏆 ${GREEN}PERFECT HEALTH${NC}: All $healthy_count/$total_services services are operational!"
elif [ $healthy_count -ge $((total_services - 3)) ]; then
    echo -e "💪 ${YELLOW}EXCELLENT${NC}: $healthy_count/$total_services services running. Minor issues detected."
else
    echo -e "🚨 ${RED}CRITICAL ISSUES${NC}: Only $healthy_count/$total_services services are running. Please investigate."
fi

echo ""
echo -e "${BLUE}🚀 Quick Commands & UIs${NC}"
echo "========================"
echo "# View all logs combined:"
echo "docker compose ${COMPOSE_FILES[@]} logs -f"
echo ""
echo "# Test Cache & Container systems:"
echo "curl -X POST http://localhost:5013/start -H 'Content-Type: application/json' -d '{\"pattern\": \"normal\"}' && sleep 10 && curl -X POST http://localhost:5013/stop"
echo "curl -X POST http://localhost:5011/start/cpu_spike -H 'Content-Type: application/json' -d '{\"spike_duration\": 10}'"
echo ""
echo "# Test Correlation & RCA engines:"
echo "curl http://localhost:5025/correlations/latest"
echo "curl http://localhost:5026/openai-status"
echo "curl \"http://localhost:5026/analyze?limit=1&min_confidence=0.8\""
echo ""

# Kubernetes commands
if kubectl get nodes >/dev/null 2>&1; then
    echo "# Kubernetes monitoring commands:"
    echo "kubectl get all -n banking-k8s-test"
    echo "kubectl get hpa -n banking-k8s-test -w"
    echo "kubectl top nodes && kubectl top pods -n banking-k8s-test"
    echo ""
    echo "# Run K8s automation scripts:"
    echo "python3 kubernetes-monitoring/scripts/load-testing-scaling-demo.py"
    echo "python3 kubernetes-monitoring/scripts/anomaly-generator.py"
    echo "python3 kubernetes-monitoring/scripts/real-time-monitoring.py"
    echo ""
fi

echo "# Access UIs:"
echo "   Grafana: http://localhost:3000 (admin/bankingdemo)"
echo "   RabbitMQ: http://localhost:15672 (admin/bankingdemo)"
echo "   Jaeger: http://localhost:16686"
echo "   Prometheus: http://localhost:9090"
echo "   Cache Analyzer: http://localhost:5012/cache-stats"
echo "   Container Monitor: http://localhost:5010/recommendations"
echo "   Event Correlation: http://localhost:5025/correlations/latest"
echo "   RCA Insights: http://localhost:5026/health"
echo "   Correlation Dashboard: http://localhost:8501"
if kubectl get nodes >/dev/null 2>&1; then
    echo "   K8s Metrics: http://localhost:9419/metrics"
fi
echo ""

echo -e "${GREEN}✨ Status check complete!${NC}"