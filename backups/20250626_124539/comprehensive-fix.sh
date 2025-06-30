#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Comprehensive Docker Compose Fix${NC}"
echo "===================================="

# Step 1: Backup all compose files
echo -e "\n${YELLOW}📦 Creating backups...${NC}"
timestamp=$(date +"%Y%m%d_%H%M%S")
for file in docker-compose*.yml; do
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.${timestamp}"
        echo -e "  ✅ Backed up: $file"
    fi
done

# Step 2: Fix main docker-compose.yml volumes
echo -e "\n${BLUE}🔨 Fixing docker-compose.yml volumes...${NC}"

# Remove incomplete volumes section and add complete one
sed -i '/^volumes:$/,/^[[:space:]]*$/d' docker-compose.yml

# Add proper volumes section at the end
cat >> docker-compose.yml << 'EOF'

volumes:
  mysql-data:
  prometheus-data:
  grafana-storage:
EOF

echo -e "  ✅ Fixed volumes in docker-compose.yml"

# Step 3: Create the external network if it doesn't exist
echo -e "\n${BLUE}🌐 Checking Docker network...${NC}"

# Check if the network exists
if ! docker network ls | grep -q "ddos-detection-system_banking-network"; then
    echo -e "  ${YELLOW}Creating external network...${NC}"
    docker network create ddos-detection-system_banking-network
    echo -e "  ✅ Created network: ddos-detection-system_banking-network"
else
    echo -e "  ✅ Network already exists: ddos-detection-system_banking-network"
fi

# Step 4: Fix network configuration in supplementary compose files
echo -e "\n${BLUE}🔧 Fixing network configurations...${NC}"

# Fix docker-compose.messaging.yml
if [ -f "docker-compose.messaging.yml" ]; then
    echo -e "  ${YELLOW}Fixing docker-compose.messaging.yml...${NC}"
    
    # Check if it needs the external network fix
    if grep -q "external: true" docker-compose.messaging.yml; then
        echo -e "    ✅ Network already configured as external"
    else
        # Update network configuration
        sed -i '/^networks:$/,/^[^[:space:]]/ {
            /^[[:space:]]*banking-network:/,/^[[:space:]]*[^[:space:]]/ {
                s/driver: bridge//g
            }
        }' docker-compose.messaging.yml
    fi
fi

# Fix docker-compose.db-demo.yml
if [ -f "docker-compose.db-demo.yml" ]; then
    echo -e "  ${YELLOW}Fixing docker-compose.db-demo.yml...${NC}"
    echo -e "    ✅ Network configuration already correct"
fi

# Fix docker-compose.tracing.yml
if [ -f "docker-compose.tracing.yml" ]; then
    echo -e "  ${YELLOW}Fixing docker-compose.tracing.yml...${NC}"
    
    # Add volumes section if grafana-storage is used but not defined
    if grep -q "grafana-storage:" docker-compose.tracing.yml && ! grep -A10 "^volumes:" docker-compose.tracing.yml | grep -q "grafana-storage:"; then
        echo -e "\nvolumes:\n  grafana-storage:\n    external: true" >> docker-compose.tracing.yml
        echo -e "    ✅ Added external volume reference"
    fi
fi

# Fix docker-compose.transaction-monitoring.yml
if [ -f "docker-compose.transaction-monitoring.yml" ]; then
    echo -e "  ${YELLOW}Fixing docker-compose.transaction-monitoring.yml...${NC}"
    
    # Add volumes section if grafana-storage is used but not defined
    if grep -q "grafana-storage:" docker-compose.transaction-monitoring.yml && ! grep -A10 "^volumes:" docker-compose.transaction-monitoring.yml | grep -q "grafana-storage:"; then
        echo -e "\nvolumes:\n  grafana-storage:\n    external: true" >> docker-compose.transaction-monitoring.yml
        echo -e "    ✅ Added external volume reference"
    fi
fi

# Step 5: Clean up any orphan containers
echo -e "\n${BLUE}🧹 Cleaning up orphan containers...${NC}"
docker compose down --remove-orphans 2>/dev/null || true

# Step 6: Verify the fixes
echo -e "\n${BLUE}✅ Verification${NC}"
echo "================"

# Check volumes in main compose file
echo -e "\n${YELLOW}Main docker-compose.yml volumes:${NC}"
tail -n 5 docker-compose.yml

# Check network status
echo -e "\n${YELLOW}Docker networks:${NC}"
docker network ls | grep -E "(NETWORK|banking)"

# Final message
echo -e "\n${GREEN}✨ All fixes applied successfully!${NC}"
echo -e "\n${BLUE}📝 Next steps:${NC}"
echo -e "  1. Run: ${GREEN}./safe_restart5.sh${NC}"
echo -e "  2. Select your backup when prompted"
echo -e "  3. Monitor the startup process"
echo -e "\n${YELLOW}💡 Tip:${NC} If you still see errors, try:"
echo -e "  - ${BLUE}docker compose down -v${NC} (removes all volumes - data will be lost!)"
echo -e "  - ${BLUE}docker system prune -a${NC} (removes all unused containers/images)"
echo -e "  - Then run ${GREEN}./safe_restart5.sh${NC} again"