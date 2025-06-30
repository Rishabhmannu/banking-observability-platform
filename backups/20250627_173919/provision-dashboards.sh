#!/bin/bash

echo "📊 Dashboard Provisioning Script"
echo "================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create grafana provisioning directories if they don't exist
echo -e "${BLUE}Creating Grafana provisioning directories...${NC}"
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/provisioning/datasources
mkdir -p grafana-dashboards

# Create datasource provisioning file
echo -e "${BLUE}Creating datasource provisioning...${NC}"
cat > grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Create dashboard provisioning file
echo -e "${BLUE}Creating dashboard provisioning...${NC}"
cat > grafana/provisioning/dashboards/all.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Check if RabbitMQ Monitor dashboard exists in grafana-dashboards
if [ ! -f "grafana-dashboards/rabbitmq-monitor-dashboard.json" ]; then
    echo -e "${YELLOW}RabbitMQ Monitor dashboard not found in grafana-dashboards directory${NC}"
    echo "Copying from your imported dashboard..."
    
    # Try to export from running Grafana
    if curl -s http://localhost:3000/api/health | grep -q "ok"; then
        dashboard_data=$(curl -s -u admin:bankingdemo "http://localhost:3000/api/dashboards/uid/rabbitmq-monitor-v1" 2>/dev/null)
        
        if [ ! -z "$dashboard_data" ] && echo "$dashboard_data" | jq -e '.dashboard' >/dev/null 2>&1; then
            echo "$dashboard_data" | jq '.dashboard' > "grafana-dashboards/rabbitmq-monitor-dashboard.json"
            echo -e "${GREEN}✅ Dashboard exported successfully${NC}"
        fi
    fi
fi

# Update docker-compose.yml to include volume mounts for Grafana provisioning
echo -e "${BLUE}Checking Grafana volume configuration...${NC}"

# Check if provisioning volumes are already in docker-compose.yml
if ! grep -q "grafana/provisioning" docker-compose.yml; then
    echo -e "${YELLOW}⚠️  Grafana provisioning volumes not found in docker-compose.yml${NC}"
    echo "Please add these volumes to the grafana service in docker-compose.yml:"
    echo ""
    echo "  grafana:"
    echo "    ..."
    echo "    volumes:"
    echo "      - grafana_data:/var/lib/grafana"
    echo "      - ./grafana/provisioning:/etc/grafana/provisioning"
    echo "      - ./grafana-dashboards:/etc/grafana/provisioning/dashboards"
else
    echo -e "${GREEN}✅ Grafana provisioning volumes already configured${NC}"
fi

echo ""
echo -e "${GREEN}✅ Provisioning setup complete!${NC}"
echo ""
echo "To make dashboards persistent across restarts:"
echo "1. Ensure the volume mounts are added to docker-compose.yml"
echo "2. Place dashboard JSON files in ./grafana-dashboards/"
echo "3. Restart Grafana: docker-compose restart grafana"
echo ""
echo "Your dashboards will now be automatically loaded on startup!"