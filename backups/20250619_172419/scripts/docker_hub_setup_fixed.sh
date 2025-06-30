#!/bin/bash

echo "🐳 Docker Hub Project Upload Script - Including Transaction Monitoring"
echo "===================================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_NAME="ddos-detection-banking"
VERSION="v2.0"  # Updated version for transaction monitoring

echo ""
echo -e "${BLUE}📋 Step 1: Docker Hub Setup${NC}"
echo "==========================="

echo "Before we start, you need:"
echo "1. Docker Hub account (free at hub.docker.com)"
echo "2. Your Docker Hub username"
echo ""

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

# Banking services (each has its own directory with Dockerfile)
BANKING_SERVICES=(
    "api-gateway"
    "account-service"
    "transaction-service"
    "auth-service"
    "notification-service"
    "fraud-detection"
    "load-generator"
)

# Transaction monitoring services (new!)
TRANSACTION_SERVICES=(
    "transaction-monitor"
    "performance-aggregator"
    "anomaly-injector"
)

# Special services (custom Dockerfiles in root)
SPECIAL_SERVICES=(
    "auto-baselining:Dockerfile.auto-baselining"
    "ml-detection:Dockerfile.ml-service"
)

echo ""
echo "🔨 Building banking services..."

# Build banking services
for service in "${BANKING_SERVICES[@]}"; do
    if [ -d "$service" ] && [ -f "$service/Dockerfile" ]; then
        echo ""
        echo -e "${YELLOW}📦 Building $service...${NC}"
        
        # Build the image
        if docker build -t "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" "$service"; then
            echo -e "  ✅ ${GREEN}$service built successfully${NC}"
            
            # Also tag as 'latest'
            docker tag "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:latest"
            echo -e "  ✅ ${GREEN}$service tagged as latest${NC}"
        else
            echo -e "  ❌ ${RED}$service build failed${NC}"
        fi
    else
        echo -e "  ⚠️  ${YELLOW}Skipping $service (no Dockerfile found)${NC}"
    fi
done

echo ""
echo "🔨 Building transaction monitoring services..."

# Build transaction monitoring services
for service in "${TRANSACTION_SERVICES[@]}"; do
    if [ -d "$service" ] && [ -f "$service/Dockerfile" ]; then
        echo ""
        echo -e "${YELLOW}📦 Building $service...${NC}"
        
        # Build the image
        if docker build -t "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" "$service"; then
            echo -e "  ✅ ${GREEN}$service built successfully${NC}"
            
            # Also tag as 'latest'
            docker tag "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:latest"
            echo -e "  ✅ ${GREEN}$service tagged as latest${NC}"
        else
            echo -e "  ❌ ${RED}$service build failed${NC}"
        fi
    else
        echo -e "  ⚠️  ${YELLOW}Skipping $service (no Dockerfile found)${NC}"
    fi
done

echo ""
echo "🔨 Building special services..."

# Build special services (auto-baselining, ml-detection)
for service_info in "${SPECIAL_SERVICES[@]}"; do
    service_name=$(echo "$service_info" | cut -d: -f1)
    dockerfile=$(echo "$service_info" | cut -d: -f2)
    
    if [ -f "$dockerfile" ]; then
        echo ""
        echo -e "${YELLOW}📦 Building $service_name...${NC}"
        
        # Build the image
        if docker build -f "$dockerfile" -t "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service_name:$VERSION" .; then
            echo -e "  ✅ ${GREEN}$service_name built successfully${NC}"
            
            # Also tag as 'latest'
            docker tag "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service_name:$VERSION" "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service_name:latest"
            echo -e "  ✅ ${GREEN}$service_name tagged as latest${NC}"
        else
            echo -e "  ❌ ${RED}$service_name build failed${NC}"
        fi
    else
        echo -e "  ⚠️  ${YELLOW}Skipping $service_name ($dockerfile not found)${NC}"
    fi
done

echo ""
echo -e "${BLUE}📤 Step 4: Push Images to Docker Hub${NC}"
echo "===================================="

echo "🚀 Pushing banking services to Docker Hub..."

# Push banking services
for service in "${BANKING_SERVICES[@]}"; do
    if docker images --format "table {{.Repository}}" | grep -q "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service"; then
        echo ""
        echo -e "${YELLOW}📤 Pushing $service...${NC}"
        
        # Push versioned image
        if docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION"; then
            echo -e "  ✅ ${GREEN}$service:$VERSION pushed successfully${NC}"
        else
            echo -e "  ❌ ${RED}$service:$VERSION push failed${NC}"
        fi
        
        # Push latest image
        if docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:latest"; then
            echo -e "  ✅ ${GREEN}$service:latest pushed successfully${NC}"
        else
            echo -e "  ❌ ${RED}$service:latest push failed${NC}"
        fi
    else
        echo -e "  ⚠️  ${YELLOW}Skipping $service (image not found)${NC}"
    fi
done

# Push transaction monitoring services
echo ""
echo "🚀 Pushing transaction monitoring services..."

for service in "${TRANSACTION_SERVICES[@]}"; do
    if docker images --format "table {{.Repository}}" | grep -q "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service"; then
        echo ""
        echo -e "${YELLOW}📤 Pushing $service...${NC}"
        
        # Push versioned and latest
        docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION"
        docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:latest"
        echo -e "  ✅ ${GREEN}$service pushed successfully${NC}"
    else
        echo -e "  ⚠️  ${YELLOW}Skipping $service (image not found)${NC}"
    fi
done

# Push special services
for service_info in "${SPECIAL_SERVICES[@]}"; do
    service_name=$(echo "$service_info" | cut -d: -f1)
    
    if docker images --format "table {{.Repository}}" | grep -q "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service_name"; then
        echo ""
        echo -e "${YELLOW}📤 Pushing $service_name...${NC}"
        
        # Push versioned and latest
        docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service_name:$VERSION"
        docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service_name:latest"
        echo -e "  ✅ ${GREEN}$service_name pushed successfully${NC}"
    else
        echo -e "  ⚠️  ${YELLOW}Skipping $service_name (image not found)${NC}"
    fi
done

echo ""
echo -e "${BLUE}📋 Step 5: Create Production Docker Compose${NC}"
echo "============================================"

# Create production docker-compose file
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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5002/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # Transaction Monitoring Services (NEW!)
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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5003/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5004/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

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
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5005/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

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
      - GF_INSTALL_PLUGINS=
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
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
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

echo -e "✅ ${GREEN}docker-compose.hub.yml created${NC}"

echo ""
echo -e "${BLUE}🎯 Step 6: Create Quick Deployment Script${NC}"
echo "========================================"

# Create quick deployment script
cat > quick_deploy_from_hub.sh << 'EOF'
#!/bin/bash

echo "🚀 Quick Deploy from Docker Hub - Complete System with Transaction Monitoring"
echo "=========================================================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📥 Pulling latest images from Docker Hub...${NC}"
docker-compose -f docker-compose.hub.yml pull

echo ""
echo -e "${BLUE}🚀 Starting all services...${NC}"
docker-compose -f docker-compose.hub.yml up -d

echo ""
echo -e "${BLUE}⏳ Waiting for services to initialize (2 minutes)...${NC}"
sleep 120

echo ""
echo -e "${BLUE}🧪 Testing services...${NC}"

services=(
    "Banking API:http://localhost:8080/health"
    "DDoS Detection:http://localhost:5001/health"
    "Auto-Baselining:http://localhost:5002/health"
    "Transaction Monitor:http://localhost:5003/health"
    "Performance Aggregator:http://localhost:5004/health"
    "Anomaly Injector:http://localhost:5005/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
)

for service_info in "${services[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    echo -n "  Testing $service_name: "
    if curl -s "$service_url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ UP${NC}"
    else
        echo -e "❌ DOWN"
    fi
done

echo ""
echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo ""
echo "🌐 Access URLs:"
echo "• Banking API: http://localhost:8080"
echo "• DDoS Detection: http://localhost:5001"
echo "• Auto-Baselining: http://localhost:5002"
echo "• Transaction Monitor: http://localhost:5003"
echo "• Performance Aggregator: http://localhost:5004"
echo "• Anomaly Injector: http://localhost:5005"
echo "• Prometheus: http://localhost:9090"
echo "• Grafana: http://localhost:3000 (admin/bankingdemo)"
echo ""
echo "📊 Dashboards:"
echo "• Banking Overview"
echo "• DDoS Detection"
echo "• Auto-Baselining"
echo "• Transaction Performance"

EOF

chmod +x quick_deploy_from_hub.sh

echo -e "✅ ${GREEN}quick_deploy_from_hub.sh created${NC}"

echo ""
echo -e "${GREEN}🎉 Docker Hub Upload Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "==========="
echo "✅ All images built and pushed to Docker Hub"
echo "✅ Production docker-compose.hub.yml created"
echo "✅ Quick deployment script created"
echo ""
echo -e "${BLUE}🔗 Your Docker Hub Repositories:${NC}"
echo "================================="

# List all services
echo "Banking Services:"
for service in "${BANKING_SERVICES[@]}"; do
    echo "  • $DOCKER_HUB_USERNAME/$PROJECT_NAME-$service"
done

echo ""
echo "Transaction Monitoring Services:"
for service in "${TRANSACTION_SERVICES[@]}"; do
    echo "  • $DOCKER_HUB_USERNAME/$PROJECT_NAME-$service"
done

echo ""
echo "ML Services:"
for service_info in "${SPECIAL_SERVICES[@]}"; do
    service_name=$(echo "$service_info" | cut -d: -f1)
    echo "  • $DOCKER_HUB_USERNAME/$PROJECT_NAME-$service_name"
done

echo ""
echo -e "${BLUE}🚀 Complete System Includes:${NC}"
echo "============================"
echo "✅ 6 Banking Microservices"
echo "✅ DDoS Detection with ML"
echo "✅ Auto-Baselining (4 algorithms)"
echo "✅ Transaction Performance Monitoring"
echo "✅ Performance Aggregation & SLO Tracking"
echo "✅ Anomaly Injection System"
echo "✅ Complete Monitoring Stack"
echo "✅ 4 Grafana Dashboards"

echo ""
echo -e "${GREEN}✅ Your complete internship project is now safe in the cloud!${NC}"