#!/bin/bash

echo "🔧 Fixing Docker Compose YAML Issue"
echo "==================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# First, let's check the current docker-compose.yml structure
echo "📋 Checking current docker-compose.yml structure..."

if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ docker-compose.yml not found!${NC}"
    exit 1
fi

# Create a clean auto-baselining service definition
echo "🛠️  Creating corrected auto-baselining service definition..."

# Remove any existing auto-baselining service from docker-compose.yml
sed -i.tmp '/# Auto-Baselining Service/,$d' docker-compose.yml

# Add the correctly formatted auto-baselining service
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

echo -e "✅ Fixed docker-compose.yml"

# Validate the docker-compose.yml
echo "🔍 Validating docker-compose.yml..."
if docker-compose config > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}Docker Compose validation: PASS${NC}"
else
    echo -e "❌ ${RED}Docker Compose validation: FAIL${NC}"
    echo "Let's check what's wrong..."
    docker-compose config
    
    echo ""
    echo "🔧 Creating a minimal working docker-compose addition..."
    
    # Remove the problematic section and add a simpler version
    sed -i.tmp2 '/# Auto-Baselining Service/,$d' docker-compose.yml
    
    # Add minimal working version
    cat >> docker-compose.yml << 'EOF'

  auto-baselining:
    build: 
      context: .
      dockerfile: Dockerfile.auto-baselining
    container_name: auto-baselining-service
    ports:
      - "5002:5002"
    environment:
      PROMETHEUS_URL: http://prometheus:9090
      LOG_LEVEL: INFO
    depends_on:
      - prometheus
    networks:
      - banking-network
    volumes:
      - ./data/baselining:/app/data/baselining
      - ./logs/baselining:/app/logs
    restart: unless-stopped
EOF
    
    echo "🔍 Re-validating docker-compose.yml..."
    if docker-compose config > /dev/null 2>&1; then
        echo -e "✅ ${GREEN}Docker Compose validation: PASS${NC}"
    else
        echo -e "❌ ${RED}Still failing. Let's try manual fix...${NC}"
        
        # Show the end of the file to see what's wrong
        echo "📋 Last 20 lines of docker-compose.yml:"
        tail -20 docker-compose.yml
        
        echo ""
        echo "💡 Manual fix required. Please check the YAML indentation."
        exit 1
    fi
fi

# Now try to build and start the service
echo ""
echo "🏗️  Building auto-baselining service..."

if docker-compose build auto-baselining; then
    echo -e "✅ ${GREEN}Build: SUCCESS${NC}"
    
    echo "🚀 Starting auto-baselining service..."
    if docker-compose up -d auto-baselining; then
        echo -e "✅ ${GREEN}Start: SUCCESS${NC}"
        
        echo "⏳ Waiting for service to initialize..."
        sleep 30
        
        # Test the service
        if curl -s http://localhost:5002/health > /dev/null 2>&1; then
            echo -e "✅ ${GREEN}Auto-Baselining Service: RUNNING${NC}"
            
            # Get service status
            health_response=$(curl -s http://localhost:5002/health)
            echo "📊 Service Status: $(echo $health_response | jq -r '.status // "Unknown"')"
            echo "🧠 Algorithms: $(echo $health_response | jq -r '.algorithms | length // 0')"
            
        else
            echo -e "❌ ${RED}Service not responding${NC}"
            echo "📋 Check logs with: docker-compose logs auto-baselining"
        fi
        
    else
        echo -e "❌ ${RED}Start: FAILED${NC}"
        echo "📋 Check logs with: docker-compose logs auto-baselining"
    fi
    
else
    echo -e "❌ ${RED}Build: FAILED${NC}"
    echo "📋 Build logs:"
    docker-compose build auto-baselining
fi

echo ""
echo -e "${GREEN}🎯 Fix completed!${NC}"
echo ""
echo "🔗 Quick verification:"
echo "curl http://localhost:5002/health"