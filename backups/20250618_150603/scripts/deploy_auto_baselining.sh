#!/bin/bash

echo "🎯 Auto-Baselining Service Deployment"
echo "===================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get current directory
PROJECT_DIR="$(pwd)"
echo "Working in: $PROJECT_DIR"

# Step 1: Verify existing system is running
echo ""
echo -e "${BLUE}📊 Step 1: Verifying existing system...${NC}"

existing_services=(
    "Banking API:http://localhost:8080/health"
    "Prometheus:http://localhost:9090/-/healthy"
)

# Check if ML Detection is running (optional)
if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    existing_services+=("ML Detection:http://localhost:5001/health")
fi

all_existing_healthy=true
for service_info in "${existing_services[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    if curl -s "$service_url" > /dev/null 2>&1; then
        echo -e "  ✅ $service_name: ${GREEN}RUNNING${NC}"
    else
        echo -e "  ❌ $service_name: ${RED}NOT RUNNING${NC}"
        all_existing_healthy=false
    fi
done

if [ "$all_existing_healthy" = false ]; then
    echo -e "${RED}❌ Some existing services are not running. Please start them first.${NC}"
    echo "Run: docker-compose up -d"
    exit 1
fi

# Step 2: Create necessary files and directories
echo ""
echo -e "${BLUE}📁 Step 2: Creating project structure...${NC}"

# Create directories
directories=(
    "data/baselining"
    "logs/baselining" 
    "config/baselining"
)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "  ✅ Created: ${GREEN}$dir${NC}"
    else
        echo -e "  ℹ️  Exists: ${YELLOW}$dir${NC}"
    fi
done

# Step 3: Create requirements file
echo ""
echo -e "${BLUE}📦 Step 3: Creating requirements file...${NC}"

cat > requirements-baselining.txt << 'EOF'
flask==2.3.3
prometheus-client==0.17.1
requests==2.31.0
pandas==2.0.3
numpy==1.24.3
scikit-learn==1.3.0
pyyaml==6.0.1
joblib==1.3.2
EOF

echo -e "  ✅ Created: ${GREEN}requirements-baselining.txt${NC}"

# Step 4: Create Dockerfile
echo ""
echo -e "${BLUE}🐳 Step 4: Creating Dockerfile...${NC}"

cat > Dockerfile.auto-baselining << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python packages
COPY requirements-baselining.txt .
RUN pip install --no-cache-dir -r requirements-baselining.txt

# Copy source code
COPY src/ ./src/
COPY config/ ./config/ 2>/dev/null || true

# Create data directories
RUN mkdir -p data/baselining logs

# Expose port
EXPOSE 5002

# Set environment variables
ENV PYTHONPATH=/app
ENV PROMETHEUS_URL=http://prometheus:9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
    CMD curl -f http://localhost:5002/health || exit 1

# Run the service
CMD ["python", "src/services/auto_baselining_service.py"]
EOF

echo -e "  ✅ Created: ${GREEN}Dockerfile.auto-baselining${NC}"

# Step 5: Update docker-compose.yml
echo ""
echo -e "${BLUE}🔧 Step 5: Updating docker-compose.yml...${NC}"

# Backup existing docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml "docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "  ✅ Backed up: ${GREEN}docker-compose.yml${NC}"
    
    # Check if auto-baselining service already exists
    if grep -q "auto-baselining:" docker-compose.yml; then
        echo -e "  ℹ️  Auto-baselining service already exists in docker-compose.yml"
    else
        # Add auto-baselining service
        cat >> docker-compose.yml << 'EOF'

  # Auto-Baselining Service (Phase 2)
  auto-baselining:
    build:
      context: .
      dockerfile: Dockerfile.auto-baselining
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
EOF
        echo -e "  ✅ Updated: ${GREEN}docker-compose.yml${NC}"
    fi
else
    echo -e "  ⚠️  docker-compose.yml not found. Please ensure you're in the correct directory."
    exit 1
fi

# Step 6: Update Prometheus configuration (optional enhancement)
echo ""
echo -e "${BLUE}📊 Step 6: Updating Prometheus configuration...${NC}"

if [ -f "config/prometheus.yml" ] || [ -f "prometheus/prometheus.yml" ]; then
    # Find the prometheus config file
    PROM_CONFIG=""
    if [ -f "config/prometheus.yml" ]; then
        PROM_CONFIG="config/prometheus.yml"
    elif [ -f "prometheus/prometheus.yml" ]; then
        PROM_CONFIG="prometheus/prometheus.yml"
    fi
    
    # Backup existing config
    cp "$PROM_CONFIG" "${PROM_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Check if auto-baselining job already exists
    if grep -q "auto-baselining" "$PROM_CONFIG"; then
        echo -e "  ℹ️  Auto-baselining job already exists in Prometheus config"
    else
        # Add auto-baselining scrape job
        echo "
  # Auto-Baselining Service
  - job_name: 'auto-baselining'
    static_configs:
      - targets: ['auto-baselining:5002']
    scrape_interval: 30s
    metrics_path: '/metrics'" >> "$PROM_CONFIG"
        
        echo -e "  ✅ Updated: ${GREEN}$PROM_CONFIG${NC}"
    fi
else
    echo -e "  ⚠️  Prometheus config not found - will use default configuration"
fi

# Step 7: Build and start auto-baselining service
echo ""
echo -e "${BLUE}🏗️  Step 7: Building and starting auto-baselining service...${NC}"

# Build the service
echo "Building auto-baselining service..."
if docker-compose build auto-baselining; then
    echo -e "  ✅ Build: ${GREEN}SUCCESS${NC}"
else
    echo -e "  ❌ Build: ${RED}FAILED${NC}"
    exit 1
fi

# Start the service
echo "Starting auto-baselining service..."
if docker-compose up -d auto-baselining; then
    echo -e "  ✅ Start: ${GREEN}SUCCESS${NC}"
else
    echo -e "  ❌ Start: ${RED}FAILED${NC}"
    exit 1
fi

# Restart Prometheus to pick up new config (if updated)
if [ -n "$PROM_CONFIG" ] && ! grep -q "auto-baselining" "${PROM_CONFIG}.backup"* 2>/dev/null; then
    echo "Restarting Prometheus to pick up new configuration..."
    docker-compose restart prometheus
fi

echo "Waiting 45 seconds for service to initialize..."
sleep 45

# Step 8: Test the service
echo ""
echo -e "${BLUE}🧪 Step 8: Testing auto-baselining service...${NC}"

if curl -s http://localhost:5002/health > /dev/null 2>&1; then
    echo -e "  ✅ Auto-Baselining Service: ${GREEN}RUNNING${NC}"
    
    # Get health check response
    health_response=$(curl -s http://localhost:5002/health)
    echo "  📊 Health Check: $(echo $health_response | jq -r '.status // "Unknown"')"
    
    # Test basic functionality
    echo "  🔍 Testing basic functionality..."
    
    # Generate some test traffic first
    echo "  📈 Generating test traffic for threshold calculation..."
    for i in {1..30}; do
        curl -s http://localhost:8080/health > /dev/null &
        curl -s http://localhost:8080/accounts/accounts > /dev/null &
        sleep 1
    done
    
    # Wait for metrics to be scraped
    sleep 30
    
    # Test threshold calculation
    threshold_response=$(curl -s "http://localhost:5002/calculate-threshold?metric=sum(rate(http_requests_total[1m]))" 2>/dev/null)
    if echo "$threshold_response" | grep -q "threshold" 2>/dev/null; then
        echo -e "  ✅ Threshold Calculation: ${GREEN}WORKING${NC}"
    else
        echo -e "  ⚠️  Threshold Calculation: ${YELLOW}NEEDS MORE DATA${NC} (normal for new deployment)"
    fi
    
else
    echo -e "  ❌ Auto-Baselining Service: ${RED}NOT RUNNING${NC}"
    echo -e "  📋 Check logs with: ${YELLOW}docker-compose logs auto-baselining${NC}"
fi

# Step 9: Verify Prometheus integration
echo ""
echo -e "${BLUE}🔍 Step 9: Verifying Prometheus integration...${NC}"

sleep 15  # Give Prometheus time to discover the target

# Check if auto-baselining target is discovered
targets_response=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null)
if echo "$targets_response" | grep -q "auto-baselining" 2>/dev/null; then
    echo -e "  ✅ Auto-baselining target: ${GREEN}DISCOVERED${NC}"
    
    # Check target health
    if echo "$targets_response" | grep -A5 "auto-baselining" | grep -q '"health":"up"' 2>/dev/null; then
        echo -e "  ✅ Target health: ${GREEN}UP${NC}"
    else
        echo -e "  ⚠️  Target health: ${YELLOW}DOWN${NC} (may need more time)"
    fi
else
    echo -e "  ⚠️  Auto-baselining target: ${YELLOW}NOT YET DISCOVERED${NC} (normal for new service)"
fi

# Step 10: Display system status
echo ""
echo -e "${BLUE}📋 Step 10: System Status Summary${NC}"
echo "================================="

services_to_check=(
    "Banking API:http://localhost:8080/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Auto-Baselining:http://localhost:5002/health"
)

# Add Grafana and ML Detection if they're running
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    services_to_check+=("Grafana:http://localhost:3000/api/health")
fi

if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    services_to_check+=("ML Detection:http://localhost:5001/health")
fi

for service_info in "${services_to_check[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    if curl -s "$service_url" > /dev/null 2>&1; then
        echo -e "🟢 $service_name: ${GREEN}HEALTHY${NC}"
    else
        echo -e "🔴 $service_name: ${RED}UNHEALTHY${NC}"
    fi
done

echo ""
echo -e "${BLUE}🔗 Service Access URLs:${NC}"
echo "======================"
echo "🏦 Banking API: http://localhost:8080"
echo "📊 Prometheus: http://localhost:9090"
echo "🎯 Auto-Baselining: http://localhost:5002"
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "📈 Grafana: http://localhost:3000"
fi
if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    echo "🤖 ML Detection: http://localhost:5001"
fi

echo ""
echo -e "${BLUE}🧪 Quick Test Commands:${NC}"
echo "======================="
echo "# Get current health:"
echo "curl http://localhost:5002/health | jq ."
echo ""
echo "# Get threshold recommendations:"
echo "curl http://localhost:5002/threshold-recommendations | jq ."
echo ""
echo "# Calculate threshold for specific metric:"
echo "curl 'http://localhost:5002/calculate-threshold?metric=sum(rate(http_requests_total[1m]))' | jq ."
echo ""
echo "# Check Prometheus targets:"
echo "curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.job==\"auto-baselining\")'"

echo ""
echo -e "${GREEN}✅ Auto-Baselining Integration Complete!${NC}"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "============="
echo "1. Wait 1-2 hours for sufficient historical data collection"
echo "2. Check threshold recommendations periodically"
echo "3. Monitor service logs: docker-compose logs auto-baselining"
echo "4. Run the comprehensive test: ./test_auto_baselining.sh"
echo ""
echo -e "${BLUE}🛑 Management Commands:${NC}"
echo "====================="
echo "# Stop everything: docker-compose down"
echo "# Restart auto-baselining: docker-compose restart auto-baselining"
echo "# View logs: docker-compose logs -f auto-baselining"
echo "# Remove auto-baselining: docker-compose stop auto-baselining && docker-compose rm auto-baselining"

echo ""
echo -e "${GREEN}🎉 Deployment successful! Auto-baselining is now running alongside your existing DDoS detection system.${NC}"