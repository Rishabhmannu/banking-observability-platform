#!/bin/bash

echo "🛑 Stopping DDoS Detection System..."
echo "==================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to kill process on port
kill_port() {
    local port=$1
    local service_name=$2
    local pid=$(lsof -ti:$port)
    
    if [ ! -z "$pid" ]; then
        echo -e "${YELLOW}Stopping $service_name (PID: $pid, Port: $port)${NC}"
        kill -9 $pid
        sleep 2
        echo -e "${GREEN}✅ $service_name stopped${NC}"
    else
        echo -e "${YELLOW}ℹ️  $service_name not running on port $port${NC}"
    fi
}

# Function to kill process by PID
kill_pid() {
    local pid=$1
    local service_name=$2
    
    if [ ! -z "$pid" ] && kill -0 $pid 2>/dev/null; then
        echo -e "${YELLOW}Stopping $service_name (PID: $pid)${NC}"
        kill -15 $pid  # Try graceful shutdown first
        sleep 3
        
        if kill -0 $pid 2>/dev/null; then
            kill -9 $pid  # Force kill if still running
            sleep 1
        fi
        echo -e "${GREEN}✅ $service_name stopped${NC}"
    else
        echo -e "${YELLOW}ℹ️  $service_name not running (PID: $pid)${NC}"
    fi
}

# Read saved PIDs if available
if [ -f "/tmp/ddos_system_pids.txt" ]; then
    echo "📁 Reading saved process IDs..."
    source /tmp/ddos_system_pids.txt
    
    # Stop services using saved PIDs
    kill_pid "$PROMETHEUS_PID" "Prometheus"
    kill_pid "$GRAFANA_PID" "Grafana"
    kill_pid "$ML_SERVICE_PID" "ML Detection Service"
    
    # Remove the PID file
    rm -f /tmp/ddos_system_pids.txt
    echo -e "${GREEN}✅ PID file cleaned up${NC}"
else
    echo "📁 No PID file found, stopping by port..."
fi

# Stop services by port (backup method)
echo ""
echo "🔍 Checking and stopping services by port..."
kill_port 9090 "Prometheus (check if from banking-demo)"
kill_port 9091 "Prometheus (standalone)"
kill_port 3000 "Grafana (check if from banking-demo)" 
kill_port 3001 "Grafana (standalone)"
kill_port 5000 "ML Detection Service"

echo ""
echo -e "${YELLOW}⚠️  Note: If Prometheus/Grafana were started by banking-demo,${NC}"
echo -e "${YELLOW}    they might restart automatically. Stop banking-demo to fully stop them.${NC}"

# Stop banking microservices
echo ""
echo "🏦 Stopping Banking Microservices..."

# Check if BANKING_DEMO_PATH is set
if [ -z "$BANKING_DEMO_PATH" ]; then
    echo "Please enter the full path to your banking-demo folder (or press Enter to skip):"
    read -p "Path: " BANKING_DEMO_PATH
fi

if [ ! -z "$BANKING_DEMO_PATH" ] && [ -d "$BANKING_DEMO_PATH" ]; then
    cd "$BANKING_DEMO_PATH"
    if [ -f "docker-compose.yml" ]; then
        docker compose down
        echo -e "${GREEN}✅ Banking microservices stopped${NC}"
    else
        echo -e "${YELLOW}ℹ️  No docker-compose.yml found in $BANKING_DEMO_PATH${NC}"
    fi
else
    echo -e "${YELLOW}ℹ️  Skipping banking microservices cleanup${NC}"
fi

# Clean up temporary files
echo ""
echo "🧹 Cleaning up temporary files..."
rm -rf /tmp/prometheus-data
rm -rf /tmp/grafana-data
rm -f /tmp/grafana.pid
rm -f /tmp/ddos_system_pids.txt

echo ""
echo -e "${GREEN}🎉 All services stopped and cleaned up!${NC}"

# Check if any processes are still running on our ports
echo ""
echo "🔍 Final port check..."
ports=(8080 9090 9091 3000 3001 5000)
any_running=false

for port in "${ports[@]}"; do
    pid=$(lsof -ti:$port 2>/dev/null)
    if [ ! -z "$pid" ]; then
        echo -e "${RED}⚠️  Port $port still in use by PID $pid${NC}"
        any_running=true
    fi
done

if [ "$any_running" = false ]; then
    echo -e "${GREEN}✅ All ports are clear${NC}"
fi

echo ""
echo "✨ System cleanup complete!"