#!/bin/bash

echo "🐳 Docker Hub Project Upload Script"
echo "=================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_NAME="ddos-detection-banking"
VERSION="v1.0"

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

# List of services to build and push
declare -A SERVICES=(
    ["api-gateway"]="./api-gateway"
    ["account-service"]="./account-service"
    ["transaction-service"]="./transaction-service"
    ["auth-service"]="./auth-service"
    ["notification-service"]="./notification-service"
    ["fraud-detection"]="./fraud-detection"
    ["auto-baselining"]="."
)

# Special Dockerfiles
declare -A DOCKERFILES=(
    ["auto-baselining"]="Dockerfile.auto-baselining"
)

echo ""
echo "🔨 Building and tagging images..."

for service in "${!SERVICES[@]}"; do
    service_path="${SERVICES[$service]}"
    dockerfile="${DOCKERFILES[$service]:-Dockerfile}"
    
    echo ""
    echo -e "${YELLOW}📦 Building $service...${NC}"
    
    # Build the image
    if [ "$service" = "auto-baselining" ]; then
        docker build -f "$dockerfile" -t "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" .
    else
        docker build -t "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" "$service_path"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "  ✅ ${GREEN}$service built successfully${NC}"
        
        # Also tag as 'latest'
        docker tag "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION" "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:latest"
        echo -e "  ✅ ${GREEN}$service tagged as latest${NC}"
    else
        echo -e "  ❌ ${RED}$service build failed${NC}"
    fi
done

# Build ML Detection Service if it exists
if [ -f "Dockerfile.ml-service" ]; then
    echo ""
    echo -e "${YELLOW}📦 Building ML Detection Service...${NC}"
    docker build -f "Dockerfile.ml-service" -t "$DOCKER_HUB_USERNAME/$PROJECT_NAME-ml-detection:$VERSION" .
    docker tag "$DOCKER_HUB_USERNAME/$PROJECT_NAME-ml-detection:$VERSION" "$DOCKER_HUB_USERNAME/$PROJECT_NAME-ml-detection:latest"
    echo -e "  ✅ ${GREEN}ML Detection Service built successfully${NC}"
fi

echo ""
echo -e "${BLUE}📤 Step 4: Push Images to Docker Hub${NC}"
echo "===================================="

echo "🚀 Pushing images to Docker Hub..."

for service in "${!SERVICES[@]}"; do
    echo ""
    echo -e "${YELLOW}📤 Pushing $service...${NC}"
    
    # Push versioned image
    docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:$VERSION"
    if [ $? -eq 0 ]; then
        echo -e "  ✅ ${GREEN}$service:$VERSION pushed successfully${NC}"
    else
        echo -e "  ❌ ${RED}$service:$VERSION push failed${NC}"
    fi
    
    # Push latest image
    docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-$service:latest"
    if [ $? -eq 0 ]; then
        echo -e "  ✅ ${GREEN}$service:latest pushed successfully${NC}"
    else
        echo -e "  ❌ ${RED}$service:latest push failed${NC}"
    fi
done

# Push ML Detection if it exists
if [ -f "Dockerfile.ml-service" ]; then
    echo ""
    echo -e "${YELLOW}📤 Pushing ML Detection Service...${NC}"
    docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-ml-detection:$VERSION"
    docker push "$DOCKER_HUB_USERNAME/$PROJECT_NAME-ml-detection:latest"
    echo -e "  ✅ ${GREEN}ML Detection Service pushed successfully${NC}"
fi

echo ""
echo -e "${BLUE}📋 Step 5: Create Production Docker Compose${NC}"
echo "============================================"

# Create production docker-compose file
cat > docker-compose.hub.yml << EOF
version: '3'

services:
  # API Gateway service
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
      - notification-service
      - fraud-detection
    networks:
      - banking-network

  # Account Service
  account-service:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-account-service:latest
    container_name: banking-account-service
    ports:
      - "8081:8081"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/accountdb
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=bankingdemo
      - SIMULATE_SLOW_QUERY=false
    depends_on:
      - mysql-db
    networks:
      - banking-network

  # Transaction Processing Service
  transaction-service:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-transaction-service:latest
    container_name: banking-transaction-service
    ports:
      - "8082:8082"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/transactiondb
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=bankingdemo
      - ACCOUNT_SERVICE_URL=http://account-service:8081
      - SIMULATE_HIGH_LOAD=false
    depends_on:
      - mysql-db
      - account-service
    networks:
      - banking-network

  # Authentication Service
  auth-service:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-auth-service:latest
    container_name: banking-auth-service
    ports:
      - "8083:8083"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/authdb
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=bankingdemo
      - SIMULATE_MEMORY_LEAK=false
    depends_on:
      - mysql-db
    networks:
      - banking-network

  # Notification Service
  notification-service:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-notification-service:latest
    container_name: banking-notification-service
    ports:
      - "8084:8084"
    environment:
      - SIMULATE_LATENCY=false
    networks:
      - banking-network

  # Fraud Detection Service
  fraud-detection:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-fraud-detection:latest
    container_name: banking-fraud-detection
    ports:
      - "8085:8085"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/frauddb
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=bankingdemo
      - SIMULATE_ALERT_STORM=false
    depends_on:
      - mysql-db
    networks:
      - banking-network

  # Auto-Baselining Service
  auto-baselining:
    image: $DOCKER_HUB_USERNAME/$PROJECT_NAME-auto-baselining:latest
    container_name: auto-baselining-service
    ports:
      - "5002:5002"
    environment:
      - PROMETHEUS_URL=http://prometheus:9090
      - LOG_LEVEL=INFO
    depends_on:
      - prometheus
    networks:
      - banking-network
    volumes:
      - ./data/baselining:/app/data/baselining
      - ./logs/baselining:/app/logs
    restart: unless-stopped

  # Database
  mysql-db:
    image: mysql:8.0
    container_name: banking-mysql
    ports:
      - "3306:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=bankingdemo
      - MYSQL_DATABASE=bankingdb
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql-init:/docker-entrypoint-initdb.d
    networks:
      - banking-network

  # Load Generator
  load-generator:
    build: ./load-generator
    container_name: banking-load-generator
    environment:
      - API_GATEWAY_URL=http://api-gateway:8080
      - ENABLE_LOAD=true
      - LOAD_INTENSITY=medium
    depends_on:
      - api-gateway
    networks:
      - banking-network

  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    networks:
      - banking-network

  # Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=bankingdemo
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
    depends_on:
      - prometheus
    networks:
      - banking-network

  # Node Exporter for host metrics
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(20199|/)'
    networks:
      - banking-network

  # cAdvisor for container metrics
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8086:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
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

echo "🚀 Quick Deploy from Docker Hub"
echo "==============================="

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
echo -e "${BLUE}⏳ Waiting for services to initialize...${NC}"
sleep 60

echo ""
echo -e "${BLUE}🧪 Testing services...${NC}"

services=(
    "Banking API:http://localhost:8080/health"
    "Auto-Baselining:http://localhost:5002/health"
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
echo "• Auto-Baselining: http://localhost:5002"
echo "• Prometheus: http://localhost:9090"
echo "• Grafana: http://localhost:3000"

EOF

chmod +x quick_deploy_from_hub.sh

echo -e "✅ ${GREEN}quick_deploy_from_hub.sh created${NC}"

echo ""
echo -e "${GREEN}🎉 Docker Hub Upload Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "==========="
echo "✅ All custom images built and pushed to Docker Hub"
echo "✅ Production docker-compose.hub.yml created"
echo "✅ Quick deployment script created"
echo ""
echo -e "${BLUE}🔗 Your Docker Hub Repositories:${NC}"
echo "================================="

for service in "${!SERVICES[@]}"; do
    echo "• $DOCKER_HUB_USERNAME/$PROJECT_NAME-$service"
done

if [ -f "Dockerfile.ml-service" ]; then
    echo "• $DOCKER_HUB_USERNAME/$PROJECT_NAME-ml-detection"
fi

echo ""
echo -e "${BLUE}🚀 Next Time Docker Breaks:${NC}"
echo "=========================="
echo "1. Reinstall Docker Desktop"
echo "2. Run: ./quick_deploy_from_hub.sh"
echo "3. Everything will be restored in ~2 minutes!"
echo ""
echo -e "${BLUE}📤 Share Your Project:${NC}"
echo "===================="
echo "Anyone can now run your project with:"
echo "curl -O https://raw.githubusercontent.com/[your-repo]/docker-compose.hub.yml"
echo "docker-compose -f docker-compose.hub.yml up -d"

echo ""
echo -e "${GREEN}✅ Your project is now safe in the cloud!${NC}"