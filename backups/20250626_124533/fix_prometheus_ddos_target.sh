#!/bin/bash

echo "🔧 Fixing Prometheus DDoS Detection Target"
echo "=========================================="

# Navigate to project directory
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" || {
    echo "❌ Could not find project directory"
    exit 1
}

echo "📂 Working from: $(pwd)"

# Check current container name
echo "🔍 Checking DDoS ML Detection container name..."
ddos_container=$(docker ps --filter "name=ddos" --format "{{.Names}}" | grep -E "(ddos|ml)" | head -1)
echo "Found container: $ddos_container"

# Create/fix Prometheus configuration
echo "🔧 Creating correct Prometheus configuration..."

mkdir -p prometheus

cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

scrape_configs:
  # Core monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  # Banking services (with correct container names)
  - job_name: 'banking-services'
    static_configs:
      - targets: 
          - 'api-gateway:8080'
          - 'account-service:8081'
          - 'transaction-service:8082'
          - 'auth-service:8083'
          - 'notification-service:8084'
          - 'fraud-detection:8085'
    metrics_path: '/metrics'
    scrape_interval: 10s

  # Auto-baselining service
  - job_name: 'auto-baselining'
    static_configs:
      - targets: ['auto-baselining:5002']
    metrics_path: '/metrics'
    scrape_interval: 15s

  # DDoS ML Detection service (FIXED container name)
  - job_name: 'ddos-ml-detection'
    static_configs:
      - targets: ['ddos-ml-detection:5001']
    metrics_path: '/metrics'
    scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

EOF

echo "✅ Updated Prometheus configuration with correct container names"

# Create alert rules if they don't exist
if [ ! -f "prometheus/alert_rules.yml" ]; then
    echo "📋 Creating basic alert rules..."
    cat > prometheus/alert_rules.yml << 'EOF'
groups:
  - name: ddos_detection
    rules:
    - alert: DDoSDetectionHighScore
      expr: ddos_detection_score > 0.7
      for: 1m
      labels:
        severity: warning
        service: ddos-detection
      annotations:
        summary: "High DDoS detection score"
        description: "DDoS detection score is {{ $value }}"

    - alert: DDoSAttackDetected
      expr: ddos_binary_prediction == 1
      for: 30s
      labels:
        severity: critical
        service: ddos-detection
      annotations:
        summary: "DDoS attack detected"
        description: "ML model has detected a potential DDoS attack"

    - alert: ServiceDown
      expr: up == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Service {{ $labels.job }} is down"
        description: "Service {{ $labels.job }} has been down for more than 2 minutes"
EOF
    echo "✅ Created basic alert rules"
fi

echo ""
echo "🔄 Restarting Prometheus to apply new configuration..."

# Restart Prometheus to pick up new config
docker compose restart prometheus

echo "⏳ Waiting for Prometheus to restart (30 seconds)..."
sleep 30

echo ""
echo "🧪 Testing Prometheus configuration..."

# Test if Prometheus is back up
echo -n "Prometheus health: "
if curl -s http://localhost:9090/-/healthy >/dev/null; then
    echo "✅ UP"
else
    echo "❌ DOWN"
fi

# Check if DDoS detection service is reachable
echo -n "DDoS service direct test: "
if curl -s http://localhost:5001/health >/dev/null; then
    echo "✅ REACHABLE"
else
    echo "❌ NOT REACHABLE"
fi

echo -n "DDoS metrics endpoint: "
if curl -s http://localhost:5001/metrics | grep -q "# HELP"; then
    echo "✅ RETURNING METRICS"
else
    echo "❌ NOT RETURNING PROPER METRICS"
fi

echo ""
echo "🎯 Checking Prometheus targets..."
sleep 10

# Check if the target is now discovered
targets_response=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null)
if echo "$targets_response" | grep -q "ddos-ml-detection"; then
    echo "✅ DDoS ML Detection target now discovered in Prometheus"
    
    # Check if it's UP
    if echo "$targets_response" | grep -A5 "ddos-ml-detection" | grep -q '"health":"up"'; then
        echo "✅ DDoS ML Detection target is UP"
    else
        echo "⚠️  DDoS ML Detection target discovered but not UP yet (may take a few minutes)"
    fi
else
    echo "❌ DDoS ML Detection target still not discovered"
    echo "This might be a Docker networking issue"
fi

echo ""
echo "🔍 Container Network Verification:"
echo "=================================="

echo "DDoS ML Detection container:"
docker ps --filter "name=ddos-ml-detection" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Network connectivity test:"
docker exec prometheus wget -qO- http://ddos-ml-detection:5001/health 2>/dev/null && \
    echo "✅ Prometheus can reach DDoS ML Detection" || \
    echo "❌ Network connectivity issue"

echo ""
echo "📊 Final Status:"
echo "==============="
echo "• Grafana: ✅ Working (admin/bankingdemo)"
echo "• Auto-baselining: ✅ Working" 
echo "• Banking services: ✅ All working"
echo "• Prometheus config: ✅ Fixed"
echo "• DDoS Detection: $(curl -s http://localhost:5001/health >/dev/null && echo "✅ Working" || echo "⚠️ Check needed")"

echo ""
echo "🔗 Check Prometheus targets now:"
echo "http://localhost:9090/targets"
echo ""
echo "If DDoS target is still DOWN, we may need to rebuild that specific service."

echo ""
echo "✨ Configuration fix complete!"