#!/bin/bash

echo "🛑 Stopping DDoS ML Detection Service"
echo "====================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Stop ML service by PID if available
if [ -f "/tmp/ml_service.pid" ]; then
    ML_PID=$(cat /tmp/ml_service.pid)
    if kill -0 $ML_PID 2>/dev/null; then
        echo -e "${YELLOW}Stopping ML Service (PID: $ML_PID)${NC}"
        kill -15 $ML_PID
        sleep 3
        
        if kill -0 $ML_PID 2>/dev/null; then
            kill -9 $ML_PID
        fi
        echo -e "${GREEN}✅ ML Service stopped${NC}"
    else
        echo -e "${YELLOW}ℹ️  ML Service was not running${NC}"
    fi
    rm /tmp/ml_service.pid
else
    echo "📁 No PID file found, stopping by port..."
fi

# Stop by port as backup (port 5001)
if lsof -ti:5001 > /dev/null 2>&1; then
    ML_PID=$(lsof -ti:5001)
    echo -e "${YELLOW}Stopping service on port 5001 (PID: $ML_PID)${NC}"
    kill -9 $ML_PID
    sleep 2
    echo -e "${GREEN}✅ Service on port 5001 stopped${NC}"
fi

# Also check old port 5000 in case something is still there
if lsof -ti:5000 > /dev/null 2>&1; then
    ML_PID=$(lsof -ti:5000)
    echo -e "${YELLOW}Found service on old port 5000 (PID: $ML_PID), stopping it too...${NC}"
    kill -9 $ML_PID
    sleep 2
fi

# Check if port 5001 is clear
if lsof -ti:5001 > /dev/null 2>&1; then
    echo -e "${RED}⚠️  Port 5001 still in use${NC}"
else
    echo -e "${GREEN}✅ Port 5001 is clear${NC}"
fi

echo ""
echo "ℹ️  Note: Banking services (docker-compose) are still running"
echo "   To stop banking services: cd /Users/rishabh/banking-demo && docker compose down"
echo ""
echo -e "${GREEN}✨ ML Service cleanup complete!${NC}"