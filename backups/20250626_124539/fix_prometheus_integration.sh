#!/bin/bash

echo "🔧 Fixing Prometheus Integration for DDoS Detection"
echo "=================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BANKING_DEMO_PATH="/Users/rishabh/banking-demo"

# Step 1: Go to banking demo directory
cd "$BANKING_DEMO_PATH"

echo "📂 Working in: $(pwd)"

# Step 2: Check current prometheus directory
echo ""
echo "📂 Step 1: Checking Prometheus configuration..."

if [ -d "prometheus" ]; then
    echo -e "${GREEN}✅ Prometheus directory exists${NC}"
    ls -la prometheus/
else
    echo -e "${YELLOW}⚠️  Creating prometheus directory${NC}"
    mkdir -p prometheus
fi

# Step 3: Backup existing config
echo ""
echo "💾 Step 2: Backing up existing configuration..."

if [ -f "prometheus/prometheus.yml" ]; then
    cp prometheus/prometheus.yml prometheus/prometheus.yml.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✅ Existing config backed up${NC}"
fi

# Step 4: Create new Prometheus config that includes ML service
echo ""
echo "📝 Step 3: Creating updated Prometheus configuration..."

cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "ddos_alert_rules.yml"

scrape_configs:
  # Scrape Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Banking API Gateway
  - job_name: 'banking-api-gateway'
    static_configs:
      - targets: ['api-gateway:8080']
    metrics_path: '/metrics'
    scrape_interval: 5s

  # ML DDoS Detection Service (CRITICAL - This was missing!)
  - job_name: 'ddos-ml-detection'
    static_configs:
      - targets: ['host.docker.internal:5001']
    metrics_path: '/metrics'
    scrape_interval: 10s
    scrape_timeout: 5s

  # Node exporter for system metrics
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  # cAdvisor for container metrics  
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF

echo -e "${GREEN}✅ Updated prometheus.yml created${NC}"

# Step 5: Create DDoS alert rules
echo ""
echo "📋 Step 4: Creating DDoS alert rules..."

cat > prometheus/ddos_alert_rules.yml << 'EOF'
groups:
- name: ddos_detection
  rules:
  
  # High confidence DDoS detection
  - alert: DDoSDetectedHighConfidence
    expr: ddos_binary_prediction == 1 and ddos_confidence > 0.8
    for: 30s
    labels:
      severity: critical
      category: security
      attack_type: ddos
      service: banking_system
    annotations:
      summary: "🚨 High confidence DDoS attack detected by ML model"
      description: "ML model detected DDoS attack with confidence {{ $value }}%"
      
  # Medium confidence DDoS detection  
  - alert: DDoSDetectedMediumConfidence
    expr: ddos_binary_prediction == 1 and ddos_confidence > 0.6 and ddos_confidence <= 0.8
    for: 1m
    labels:
      severity: warning
      category: security
      attack_type: ddos
      service: banking_system
    annotations:
      summary: "⚠️ Possible DDoS attack detected by ML model"
      description: "ML model detected potential DDoS with confidence {{ $value }}%"
      
  # ML service health monitoring
  - alert: MLDetectionServiceDown
    expr: up{job="ddos-ml-detection"} == 0
    for: 1m
    labels:
      severity: critical
      category: infrastructure
      service: ml_detection
    annotations:
      summary: "❌ DDoS ML Detection Service is down"
      description: "The ML-based DDoS detection service is not responding"
EOF

echo -e "${GREEN}✅ DDoS alert rules created${NC}"

# Step 6: Restart Prometheus container to pick up new config
echo ""
echo "🔄 Step 5: Restarting Prometheus container..."

# Stop prometheus container
docker compose stop prometheus
sleep 5

# Start prometheus container  
docker compose start prometheus
sleep 10

# Check if it's running
if docker compose ps | grep prometheus | grep -q "Up"; then
    echo -e "${GREEN}✅ Prometheus container restarted${NC}"
else
    echo -e "${RED}❌ Prometheus failed to restart${NC}"
    echo "Checking logs..."
    docker compose logs prometheus
    exit 1
fi

# Step 7: Wait and verify targets
echo ""
echo "🔍 Step 6: Verifying ML service target..."

echo "⏳ Waiting 30 seconds for Prometheus to discover targets..."
sleep 30

# Check if ML service target is being scraped
if curl -s "http://localhost:9090/api/v1/targets" | grep -q "ddos-ml-detection"; then
    echo -e "${GREEN}✅ ML Detection service is now being scraped by Prometheus!${NC}"
else
    echo -e "${YELLOW}⚠️  ML Detection service not yet visible in targets${NC}"
    echo "This might be a Docker networking issue. Let's check the logs..."
    docker compose logs prometheus | tail -20
fi

# Step 8: Test metrics availability
echo ""
echo "📊 Step 7: Testing DDoS metrics availability..."

# Wait a bit more for metrics to be collected
echo "⏳ Waiting 20 seconds for metrics to be collected..."
sleep 20

# Test if ddos metrics are available
if curl -s "http://localhost:9090/api/v1/query?query=ddos_detection_score" | grep -q "ddos_detection_score"; then
    echo -e "${GREEN}✅ DDoS detection metrics are available in Prometheus!${NC}"
else
    echo -e "${YELLOW}⚠️  DDoS metrics not yet available${NC}"
    echo "Let's check if the ML service is reachable from Docker..."
    
    # Test if we can reach ML service from inside prometheus container
    docker compose exec prometheus wget -q -O - http://host.docker.internal:5001/metrics | head -5
fi

# Step 9: Verify rules are loaded
echo ""
echo "📋 Step 8: Checking if alert rules are loaded..."

if curl -s "http://localhost:9090/api/v1/rules" | grep -q "ddos_detection"; then
    echo -e "${GREEN}✅ DDoS detection rules are loaded!${NC}"
else
    echo -e "${YELLOW}⚠️  DDoS detection rules not loaded${NC}"
fi

echo ""
echo "🎯 Next Steps:"
echo "=============="
echo "1. Check Prometheus targets: http://localhost:9090/targets"
echo "2. Check Prometheus alerts: http://localhost:9090/alerts"  
echo "3. Test query: http://localhost:9090/graph?g0.expr=ddos_detection_score"
echo "4. Make sure ML service is running: curl http://localhost:5001/health"

echo ""
echo -e "${GREEN}✨ Prometheus configuration update complete!${NC}"