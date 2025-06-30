#!/bin/bash

echo "🐳 Docker Hub Project Upload Script v3 - Complete AIOps Platform"
echo "=============================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_NAME="ddos-detection-banking"
VERSION="v3.0"  # Updated for transaction tracing & Windows IIS

echo ""
echo -e "${BLUE}📋 Step 1: Docker Hub Setup${NC}"
echo "==========================="

read -p "Enter your Docker Hub username: " DOCKER_HUB_USERNAME

if [ -z "$DOCKER_HUB_USERNAME" ]; then
    echo -e "${RED}❌ Docker Hub username is required${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🔐 Step 2: Docker Hub Login${NC}"
echo "=========================="

echo "Logging into Docker Hub..."
if ! docker login; then
    echo -e "${RED}❌ Docker Hub login failed${NC}"
    exit 1
fi

echo -e "✅ ${GREEN}Docker Hub login successful${NC}"

echo ""
echo -e "${BLUE}🏗️ Step 3: Build All Images${NC}"
echo "============================"

# Navigate to project directory
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" || {
    echo -e "${RED}❌ Could not find project directory${NC}"
    exit 1
}

echo "📂 Working from: $(pwd)"

# Define all service categories
BANKING_SERVICES=(
    "api-gateway"
    "account-service"
    "transaction-service"
    "auth-service"
    "notification-service"
    "fraud-detection"
    "load-generator"
)

TRANSACTION_SERVICES=(
    "transaction-monitor"
    "performance-aggregator"
    "anomaly-injector"
)

WINDOWS_SERVICES=(
    "mock-windows-exporter"
    "mock-iis-application"
)

TRACING_SERVICES=(
    "trace-generator"
)

SPECIAL_SERVICES=(
    "auto-baselining:Dockerfile.auto-baselining"
    "ml-detection:Dockerfile.ml-service"
)

# Build function
build_service() {
    local service=$1
    local dockerfile=$2
    local build_path=$3
    
    echo ""
    echo -e "${YELLOW}📦 Building $service...${NC}"
    
    if [ -z "$dockerfile" ]; then
        # Standard build
        if docker build -t "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" "$build_path"; then
            echo -e "  ✅ ${GREEN}$service built successfully${NC}"
            docker tag "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:latest"
            echo -e "  ✅ ${GREEN}$service tagged as latest${NC}"
            return 0
        else
            echo -e "  ❌ ${RED}$service build failed${NC}"
            return 1
        fi
    else
        # Custom dockerfile build
        if docker build -f "$dockerfile" -t "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" "$build_path"; then
            echo -e "  ✅ ${GREEN}$service built successfully${NC}"
            docker tag "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:latest"
            echo -e "  ✅ ${GREEN}$service tagged as latest${NC}"
            return 0
        else
            echo -e "  ❌ ${RED}$service build failed${NC}"
            return 1
        fi
    fi
}

# Push function
push_service() {
    local service=$1
    
    echo ""
    echo -e "${YELLOW}📤 Pushing $service...${NC}"
    
    if docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION"; then
        echo -e "  ✅ ${GREEN}$service:$VERSION pushed${NC}"
    else
        echo -e "  ❌ ${RED}$service:$VERSION push failed${NC}"
    fi
    
    if docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:latest"; then
        echo -e "  ✅ ${GREEN}$service:latest pushed${NC}"
    else
        echo -e "  ❌ ${RED}$service:latest push failed${NC}"
    fi
}

# Build all services
echo ""
echo "🔨 Building banking services..."
for service in "${BANKING_SERVICES[@]}"; do
    if [ -d "$service" ] && [ -f "$service/Dockerfile" ]; then
        build_service "$service" "" "$service"
    fi
done

echo ""
echo "🔨 Building transaction monitoring services..."
for service in "${TRANSACTION_SERVICES[@]}"; do
    if [ -d "$service" ] && [ -f "$service/Dockerfile" ]; then
        build_service "$service" "" "$service"
    fi
done

echo ""
echo "🔨 Building Windows IIS monitoring services..."
for service in "${WINDOWS_SERVICES[@]}"; do
    if [ -d "$service" ] && [ -f "$service/Dockerfile" ]; then
        build_service "$service" "" "$service"
    fi
done

echo ""
echo "🔨 Building tracing services..."
for service in "${TRACING_SERVICES[@]}"; do
    if [ -d "$service" ] && [ -f "$service/Dockerfile" ]; then
        build_service "$service" "" "$service"
    fi
done

echo ""
echo "🔨 Building special services..."
for service_info in "${SPECIAL_SERVICES[@]}"; do
    service_name=$(echo "$service_info" | cut -d: -f1)
    dockerfile=$(echo "$service_info" | cut -d: -f2)
    
    if [ -f "$dockerfile" ]; then
        build_service "$service_name" "$dockerfile" "."
    fi
done

echo ""
echo -e "${BLUE}📤 Step 4: Push All Images to Docker Hub${NC}"
echo "========================================"

# Push all services
echo "🚀 Pushing banking services..."
for service in "${BANKING_SERVICES[@]}"; do
    push_service "$service"
done

echo ""
echo "🚀 Pushing transaction monitoring services..."
for service in "${TRANSACTION_SERVICES[@]}"; do
    push_service "$service"
done

echo ""
echo "🚀 Pushing Windows IIS monitoring services..."
for service in "${WINDOWS_SERVICES[@]}"; do
    push_service "$service"
done

echo ""
echo "🚀 Pushing tracing services..."
for service in "${TRACING_SERVICES[@]}"; do
    push_service "$service"
done

echo ""
echo "🚀 Pushing special services..."
for service_info in "${SPECIAL_SERVICES[@]}"; do
    service_name=$(echo "$service_info" | cut -d: -f1)
    push_service "$service_name"
done

echo ""
echo -e "${BLUE}📋 Step 5: Create Production Docker Compose Files${NC}"
echo "==============================================="

# Create main docker-compose.hub.yml
cat > docker-compose.hub.yml << EOF
version: '3.8'

services:
  # Core Infrastructure
  mysql-db:
    image: mysql:8.0
    container_name: banking-mysql
    environment:
      MYSQL_ROOT_PASSWORD: bankingdemo
      MYSQL_DATABASE: bankingdb
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql-init:/docker-entrypoint-initdb.d
    networks:
      - banking-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  # Banking Services
  api-gateway:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-api-gateway:latest
    container_name: banking-api-gateway
    ports:
      - "8080:8080"
    environment:
      - ACCOUNT_SERVICE_URL=http://account-service:8081
      - TRANSACTION_SERVICE_URL=http://transaction-service:8082
      - AUTH_SERVICE_URL=http://auth-service:8083
      - NOTIFICATION_SERVICE_URL=http://notification-service:8084
      - FRAUD_SERVICE_URL=http://fraud-detection:8085
    depends_on:
      - account-service
      - transaction-service
      - auth-service
    networks:
      - banking-network

  account-service:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-account-service:latest
    container_name: banking-account-service
    ports:
      - "8081:8081"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/accountdb
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=bankingdemo
    depends_on:
      mysql-db:
        condition: service_healthy
    networks:
      - banking-network

  transaction-service:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-transaction-service:latest
    container_name: banking-transaction-service
    ports:
      - "8082:8082"
    environment:
      - ACCOUNT_SERVICE_URL=http://account-service:8081
    depends_on:
      - account-service
    networks:
      - banking-network

  auth-service:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-auth-service:latest
    container_name: banking-auth-service
    ports:
      - "8083:8083"
    networks:
      - banking-network

  notification-service:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-notification-service:latest
    container_name: banking-notification-service
    ports:
      - "8084:8084"
    networks:
      - banking-network

  fraud-detection:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-fraud-detection:latest
    container_name: banking-fraud-detection
    ports:
      - "8085:8085"
    networks:
      - banking-network

  # ML Services
  ddos-ml-detection:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-ml-detection:latest
    container_name: ddos-ml-detection
    ports:
      - "5001:5001"
    networks:
      - banking-network

  auto-baselining:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-auto-baselining:latest
    container_name: auto-baselining-service
    ports:
      - "5002:5002"
    environment:
      - PROMETHEUS_URL=http://prometheus:9090
    depends_on:
      - prometheus
    networks:
      - banking-network

  # Transaction Monitoring
  transaction-monitor:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-transaction-monitor:latest
    container_name: transaction-performance-monitor
    ports:
      - "5003:5003"
    environment:
      - PROMETHEUS_URL=http://prometheus:9090
      - BANKING_API_URL=http://api-gateway:8080
    depends_on:
      - prometheus
      - api-gateway
    networks:
      - banking-network

  performance-aggregator:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-performance-aggregator:latest
    container_name: performance-aggregator-service
    ports:
      - "5004:5004"
    environment:
      - PROMETHEUS_URL=http://prometheus:9090
      - TRANSACTION_MONITOR_URL=http://transaction-monitor:5003
    depends_on:
      - prometheus
      - transaction-monitor
    networks:
      - banking-network

  anomaly-injector:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-anomaly-injector:latest
    container_name: anomaly-injector-service
    ports:
      - "5005:5005"
    depends_on:
      - api-gateway
      - transaction-monitor
    networks:
      - banking-network

  # Windows IIS Monitoring
  mock-windows-exporter:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-mock-windows-exporter:latest
    container_name: mock-windows-exporter
    ports:
      - "9182:9182"
    networks:
      - banking-network

  mock-iis-application:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-mock-iis-application:latest
    container_name: mock-iis-application
    ports:
      - "8090:8090"
    networks:
      - banking-network

  # Monitoring Stack
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - banking-network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=bankingdemo
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    networks:
      - banking-network

  # System Monitoring
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    networks:
      - banking-network

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8086:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - banking-network

  # Load Generator
  load-generator:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-load-generator:latest
    container_name: banking-load-generator
    environment:
      - API_GATEWAY_URL=http://api-gateway:8080
      - ENABLE_LOAD=true
      - LOAD_INTENSITY=low
    depends_on:
      - api-gateway
    networks:
      - banking-network

networks:
  banking-network:
    driver: bridge

volumes:
  mysql-data:
  prometheus-data:
  grafana-data:
EOF

# Create tracing compose file
cat > docker-compose.tracing.hub.yml << EOF
version: '3.8'

services:
  # Jaeger
  jaeger:
    image: jaegertracing/all-in-one:1.45
    container_name: jaeger
    environment:
      - COLLECTOR_OTLP_ENABLED=true
      - SPAN_STORAGE_TYPE=memory
      - QUERY_BASE_PATH=/jaeger
    ports:
      - "16686:16686"
      - "14268:14268"
      - "14250:14250"
      - "4317:4317"
      - "4318:4318"
    networks:
      - banking-network

  # Trace Generator
  trace-generator:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-trace-generator:latest
    container_name: trace-generator
    ports:
      - "9414:9414"
    environment:
      - JAEGER_ENDPOINT=http://jaeger:4318/v1/traces
      - OTEL_SERVICE_NAME=trace-generator
    depends_on:
      - jaeger
    networks:
      - banking-network
EOF

echo -e "✅ ${GREEN}Docker compose files created${NC}"

echo ""
echo -e "${GREEN}🎉 Docker Hub Upload Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "==========="
echo "✅ All images built and pushed to Docker Hub"
echo "✅ Version: $VERSION"
echo "✅ Latest tags also updated"
echo ""
echo -e "${BLUE}🔗 Your Docker Hub Images:${NC}"
echo "=========================="

all_services=("${BANKING_SERVICES[@]}" "${TRANSACTION_SERVICES[@]}" "${WINDOWS_SERVICES[@]}" "${TRACING_SERVICES[@]}")
for service in "${all_services[@]}"; do
    echo "  • $DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION"
done

for service_info in "${SPECIAL_SERVICES[@]}"; do
    service_name=$(echo "$service_info" | cut -d: -f1)
    echo "  • $DOCKER_HUB_USERNAME/$PROJECT_NAME-$service_name:$VERSION"
done

echo ""
echo -e "${BLUE}🚀 Complete Platform Includes:${NC}"
echo "============================="
echo "✅ 6 Banking Microservices"
echo "✅ DDoS Detection with ML"
echo "✅ Auto-Baselining (4 algorithms)"
echo "✅ Transaction Performance Monitoring"
echo "✅ Performance Aggregation & SLO Tracking"
echo "✅ Anomaly Injection System"
echo "✅ Windows IIS Monitoring (Mock)"
echo "✅ Distributed Tracing with Jaeger"
echo "✅ Complete Monitoring Stack"
echo "✅ 6 Grafana Dashboards"
echo ""
echo -e "${GREEN}✨ Your complete AIOps platform is now in the cloud!${NC}"