#!/bin/bash

echo "🚀 Starting DDoS ML Detection Service"
echo "===================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get current directory
DDOS_PROJECT_DIR="$(pwd)"
BANKING_DEMO_PATH="/Users/rishabh/banking-demo"

echo "DDoS Project: $DDOS_PROJECT_DIR"
echo "Banking Demo: $BANKING_DEMO_PATH"
echo "ℹ️  Using port 5001 to avoid macOS AirPlay conflict"

# Step 1: Check if banking services are running
echo ""
echo "🏦 Step 1: Checking Banking Services..."

if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Banking API Gateway is running${NC}"
else
    echo -e "${YELLOW}⚠️  Banking services not running, starting them...${NC}"
    
    if [ -d "$BANKING_DEMO_PATH" ] && [ -f "$BANKING_DEMO_PATH/docker-compose.yml" ]; then
        cd "$BANKING_DEMO_PATH"
        docker compose up -d
        
        echo "⏳ Waiting 60 seconds for services to start..."
        sleep 60
        
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Banking services started successfully${NC}"
        else
            echo -e "${RED}❌ Banking services failed to start${NC}"
            exit 1
        fi
        
        cd "$DDOS_PROJECT_DIR"
    else
        echo -e "${RED}❌ Banking demo not found at $BANKING_DEMO_PATH${NC}"
        exit 1
    fi
fi

# Step 2: Check Prometheus and Grafana
echo ""
echo "📊 Step 2: Checking Prometheus and Grafana..."

prometheus_port=""
if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Prometheus running on port 9090${NC}"
    prometheus_port="9090"
elif curl -s http://localhost:9091/-/healthy > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Prometheus running on port 9091${NC}"
    prometheus_port="9091"
else
    echo -e "${RED}❌ Prometheus not found on ports 9090 or 9091${NC}"
    echo "Make sure your banking-demo services are fully started"
    exit 1
fi

grafana_port=""
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Grafana running on port 3000${NC}"
    grafana_port="3000"
elif curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Grafana running on port 3001${NC}"
    grafana_port="3001"
else
    echo -e "${YELLOW}⚠️  Grafana not responding (this is OK for now)${NC}"
fi

# Step 3: Check if model files exist
echo ""
echo "🤖 Step 3: Checking ML Model Files..."

if [ -f "data/models/isolation_forest_model.pkl" ]; then
    echo -e "${GREEN}✅ ML model found${NC}"
    model_status="available"
else
    echo -e "${YELLOW}⚠️  ML model not found - will use rule-based detection${NC}"
    model_status="demo_mode"
fi

# Step 4: Start ML Detection Service
echo ""
echo "🚀 Step 4: Starting ML Detection Service on port 5001..."

# Kill any existing ML service on port 5001
if lsof -ti:5001 > /dev/null 2>&1; then
    echo "Stopping existing ML service on port 5001..."
    kill -9 $(lsof -ti:5001)
    sleep 2
fi

# Start the service
python3 minimal_ml_service.py &
ML_PID=$!

echo "ML Service PID: $ML_PID"

# Wait and check if service started
echo "⏳ Waiting for ML service to start..."
sleep 10

if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ ML Detection Service is running on port 5001${NC}"
else
    echo -e "${RED}❌ ML Detection Service failed to start${NC}"
    kill $ML_PID 2>/dev/null
    exit 1
fi

# Step 5: Final Status
echo ""
echo "🎯 System Status:"
echo "================"
echo "🏦 Banking API: http://localhost:8080"
echo "📊 Prometheus: http://localhost:$prometheus_port"
if [ ! -z "$grafana_port" ]; then
    echo "📈 Grafana: http://localhost:$grafana_port (admin/admin)"
fi
echo "🤖 ML Service: http://localhost:5001"
echo ""
echo "🔧 Service Details:"
echo "- Model Status: $model_status"
echo "- ML Service PID: $ML_PID"
echo "- Port: 5001 (avoiding AirPlay conflict)"
echo ""

# Save PID for cleanup
echo $ML_PID > /tmp/ml_service.pid

echo -e "${GREEN}🎉 SUCCESS! DDoS Detection System is running${NC}"
echo ""
echo "📊 Test the system:"
echo "curl http://localhost:5001/health"
echo "curl http://localhost:5001/predict"
echo ""
echo "🛑 To stop: kill $ML_PID"

# Keep monitoring in background
(
    while kill -0 $ML_PID 2>/dev/null; do
        sleep 30
        if ! curl -s http://localhost:5001/health > /dev/null 2>&1; then
            echo -e "${RED}⚠️  ML Service stopped responding${NC}"
            break
        fi
    done
) &