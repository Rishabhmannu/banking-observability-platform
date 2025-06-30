#!/bin/bash
# Fix script for Redis Cache and Container Optimization setup

echo "🔧 Fixing Optimization Services Setup"
echo "===================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Check cAdvisor connectivity
echo -e "\n${YELLOW}Step 1: Checking cAdvisor connectivity${NC}"
python3 check-cadvisor-connectivity.py

# Step 2: Determine correct cAdvisor URL
echo -e "\n${YELLOW}Step 2: Determining cAdvisor configuration${NC}"

# Try to access cAdvisor from within Docker network
if docker run --rm --network ddos-detection-system_banking-network alpine wget -q -O- http://cadvisor:8080/api/v1.0/machine > /dev/null 2>&1; then
    echo -e "${GREEN}✅ cAdvisor accessible via container name${NC}"
    export CADVISOR_URL="http://cadvisor:8080"
elif curl -s http://localhost:8080/api/v1.0/machine > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  cAdvisor only accessible via localhost${NC}"
    echo "Using host.docker.internal for Docker containers"
    export CADVISOR_URL="http://host.docker.internal:8080"
else
    echo -e "${RED}❌ Cannot access cAdvisor${NC}"
    echo "Please ensure cAdvisor is running on port 8080"
    exit 1
fi

echo -e "Using CADVISOR_URL: ${GREEN}$CADVISOR_URL${NC}"

# Step 3: Update docker-compose file to remove version warning
echo -e "\n${YELLOW}Step 3: Updating docker-compose.optimization.yml${NC}"

# Create a backup
cp docker-compose.optimization.yml docker-compose.optimization.yml.backup
echo "✅ Created backup: docker-compose.optimization.yml.backup"

# Remove version line if it exists (to eliminate warning)
if grep -q "^version:" docker-compose.optimization.yml; then
    sed -i.tmp '/^version:/d' docker-compose.optimization.yml
    echo "✅ Removed version attribute"
fi

# Step 4: Stop any existing services
echo -e "\n${YELLOW}Step 4: Stopping any existing optimization services${NC}"
docker-compose -f docker-compose.optimization.yml down 2>/dev/null
echo "✅ Cleaned up existing services"

# Step 5: Build services
echo -e "\n${YELLOW}Step 5: Building optimization services${NC}"
docker-compose -f docker-compose.optimization.yml build
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All services built successfully${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Step 6: Start services with correct environment
echo -e "\n${YELLOW}Step 6: Starting services${NC}"
CADVISOR_URL=$CADVISOR_URL docker-compose -f docker-compose.optimization.yml up -d

# Step 7: Wait for services to be ready
echo -e "\n${YELLOW}Step 7: Waiting for services to start${NC}"
sleep 10

# Step 8: Check service health
echo -e "\n${YELLOW}Step 8: Checking service health${NC}"

services=("5012:Redis Cache Analyzer" "5013:Cache Load Generator" "5010:Container Resource Monitor" "5011:Resource Anomaly Generator")

all_healthy=true
for service in "${services[@]}"; do
    IFS=':' read -r port name <<< "$service"
    if curl -s http://localhost:$port/health > /dev/null 2>&1; then
        echo -e "✅ ${name} is ${GREEN}healthy${NC}"
    else
        echo -e "❌ ${name} is ${RED}not responding${NC}"
        all_healthy=false
    fi
done

# Step 9: Show results
echo -e "\n${YELLOW}========== Summary ==========${NC}"
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}✅ All services are running successfully!${NC}"
    echo -e "\n${YELLOW}Service URLs:${NC}"
    echo "• Redis Cache Analyzer: http://localhost:5012"
    echo "• Cache Load Generator: http://localhost:5013"  
    echo "• Container Monitor: http://localhost:5010"
    echo "• Resource Anomaly Gen: http://localhost:5011"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Run: python test-redis-cache.py"
    echo "2. Run: python test-container-resources.py"
else
    echo -e "${RED}❌ Some services failed to start${NC}"
    echo -e "\n${YELLOW}Troubleshooting:${NC}"
    echo "1. Check logs: docker-compose -f docker-compose.optimization.yml logs"
    echo "2. Check individual service: docker logs banking-cache-analyzer"
    echo "3. Ensure all directories exist with correct permissions"
fi

# Save configuration for future use
echo -e "\n${YELLOW}Saving configuration...${NC}"
echo "export CADVISOR_URL='$CADVISOR_URL'" > .optimization.env
echo "✅ Configuration saved to .optimization.env"
echo "   Source it in future sessions: source .optimization.env"