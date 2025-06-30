#!/bin/bash

echo "🔧 Updating Prometheus Configuration for DDoS Detection"
echo "====================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BANKING_DEMO_PATH="/Users/rishabh/banking-demo"
DDOS_PROJECT_DIR="$(pwd)"

echo "Banking Demo Path: $BANKING_DEMO_PATH"
echo "DDoS Project Path: $DDOS_PROJECT_DIR"

# Step 1: Check if banking demo has prometheus directory
echo ""
echo "📂 Step 1: Locating Prometheus configuration..."

if [ -d "$BANKING_DEMO_PATH/prometheus" ]; then
    PROMETHEUS_CONFIG_DIR="$BANKING_DEMO_PATH/prometheus"
    echo -e "${GREEN}✅ Found Prometheus config directory: $PROMETHEUS_CONFIG_DIR${NC}"
else
    echo -e "${RED}❌ Prometheus config directory not found${NC}"
    echo "Creating prometheus directory in banking-demo..."
    mkdir -p "$BANKING_DEMO_PATH/prometheus"
    PROMETHEUS_CONFIG_DIR="$BANKING_DEMO_PATH/prometheus"
fi

# Step 2: Backup existing configuration
echo ""
echo "💾 Step 2: Backing up existing configuration..."

if [ -f "$PROMETHEUS_CONFIG_DIR/prometheus.yml" ]; then
    cp "$PROMETHEUS_CONFIG_DIR/prometheus.yml" "$PROMETHEUS_CONFIG_DIR/prometheus.yml.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✅ Existing config backed up${NC}"
else
    echo -e "${YELLOW}⚠️  No existing prometheus.yml found${NC}"
fi

# Step 3: Copy new configuration files
echo ""
echo "📝 Step 3: Installing new configuration..."

# Copy prometheus.yml
cp "$DDOS_PROJECT_DIR/prometheus.yml" "$PROMETHEUS_CONFIG_DIR/prometheus.yml"
echo -e "${GREEN}✅ Updated prometheus.yml${NC}"

# Copy alert rules
cp "$DDOS_PROJECT_DIR/ddos_alert_rules.yml" "$PROMETHEUS_CONFIG_DIR/ddos_alert_rules.yml"
echo -e "${GREEN}✅ Added DDoS alert rules${NC}"

# Step 4: Update docker-compose to mount the config properly
echo ""
echo "🐳 Step 4: Checking Docker Compose configuration..."

cd "$BANKING_DEMO_PATH"

# Check if prometheus service exists in docker-compose
if docker compose config | grep -q "prometheus:"; then
    echo -e "${GREEN}✅ Prometheus service found in docker-compose${NC}"
    
    # Restart prometheus container to pick up new config
    echo "🔄 Restarting Prometheus container..."
    docker compose restart prometheus
    
    # Wait for it to start
    sleep 10
    
    # Check if it's healthy
    if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Prometheus restarted successfully${NC}"
    else
        echo -e "${RED}❌ Prometheus failed to restart${NC}"
        echo "Check docker logs: docker compose logs prometheus"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Prometheus not found in docker-compose${NC}"
    echo "You may need to restart the entire banking-demo stack"
fi

# Step 5: Verify configuration
echo ""
echo "🔍 Step 5: Verifying configuration..."

# Check if ML service target is being scraped
sleep 5
if curl -s "http://localhost:9090/api/v1/targets" | grep -q "ddos-ml-detection"; then
    echo -e "${GREEN}✅ ML Detection service is now being scraped by Prometheus${NC}"
else
    echo -e "${YELLOW}⚠️  ML Detection service not yet visible in targets (may take a few minutes)${NC}"
fi

# Check if rules are loaded
if curl -s "http://localhost:9090/api/v1/rules" | grep -q "ddos_detection"; then
    echo -e "${GREEN}✅ DDoS detection rules are loaded${NC}"
else
    echo -e "${YELLOW}⚠️  DDoS detection rules not yet loaded${NC}"
fi

# Step 6: Test metrics availability
echo ""
echo "📊 Step 6: Testing DDoS metrics availability..."

# Wait a bit for metrics to be collected
echo "⏳ Waiting 30 seconds for metrics to be collected..."
sleep 30

# Test if ddos metrics are available
if curl -s "http://localhost:9090/api/v1/query?query=ddos_detection_score" | grep -q "ddos_detection_score"; then
    echo -e "${GREEN}✅ DDoS detection metrics are available in Prometheus!${NC}"
else
    echo -e "${YELLOW}⚠️  DDoS metrics not yet available (ML service might need to be running)${NC}"
fi

echo ""
echo "🎯 Next Steps:"
echo "=============="
echo "1. Open Prometheus: http://localhost:9090"
echo "2. Go to Status -> Targets to see if 'ddos-ml-detection' appears"
echo "3. Go to Alerts to see the DDoS detection rules"
echo "4. Try queries like: ddos_detection_score, ddos_binary_prediction"
echo "5. Make sure your ML service is running: ./start_ml_service.sh"

echo ""
echo -e "${GREEN}✨ Prometheus configuration updated!${NC}"

cd "$DDOS_PROJECT_DIR"