#!/bin/bash

echo "📈 Auto-Baselining Data Generation Script"
echo "========================================"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🎯 Generating diverse traffic patterns for algorithm training...${NC}"

# Function to generate traffic
generate_traffic_pattern() {
    local pattern_name="$1"
    local duration="$2"
    local base_rate="$3"
    local variation="$4"
    
    echo -e "${YELLOW}📊 Pattern: $pattern_name (${duration}s, base rate: ${base_rate} req/s)${NC}"
    
    for ((i=1; i<=duration; i++)); do
        # Add some randomness to make it more realistic
        current_rate=$((base_rate + (RANDOM % variation) - (variation/2)))
        current_rate=$((current_rate < 1 ? 1 : current_rate))
        
        for ((j=1; j<=current_rate; j++)); do
            # Mix different types of requests
            if (( j % 4 == 0 )); then
                curl -s http://localhost:8080/accounts/accounts > /dev/null &
            elif (( j % 3 == 0 )); then
                curl -s http://localhost:8080/transactions/transactions > /dev/null &
            elif (( j % 2 == 0 )); then
                curl -s http://localhost:8080/auth/login -X POST -H "Content-Type: application/json" -d '{"username":"test","password":"test"}' > /dev/null &
            else
                curl -s http://localhost:8080/health > /dev/null &
            fi
        done
        sleep 1
    done
    
    wait # Wait for all background requests to complete
    echo -e "  ✅ Generated pattern: $pattern_name"
}

# 1. Baseline normal traffic (low, steady)
generate_traffic_pattern "Baseline Normal" 60 3 2

# Wait for metrics to be scraped
echo "⏳ Waiting for Prometheus to scrape metrics..."
sleep 45

# 2. Business hours simulation (medium traffic)
generate_traffic_pattern "Business Hours" 90 7 3

sleep 30

# 3. Lunch rush simulation (higher traffic)
generate_traffic_pattern "Lunch Rush" 45 12 4

sleep 30

# 4. Evening decline (decreasing traffic)
generate_traffic_pattern "Evening Decline" 60 5 2

sleep 30

# 5. Late night low traffic
generate_traffic_pattern "Late Night" 30 2 1

echo ""
echo -e "${GREEN}✅ Data generation complete!${NC}"
echo ""
echo "📊 Traffic Summary:"
echo "- Baseline Normal: 180 requests (low variance)"
echo "- Business Hours: 630 requests (medium variance)"  
echo "- Lunch Rush: 540 requests (high variance)"
echo "- Evening Decline: 300 requests (decreasing)"
echo "- Late Night: 60 requests (minimal)"
echo ""
echo "Total: ~1,710 requests across different patterns"

echo ""
echo -e "${BLUE}⏳ Waiting 2 minutes for data processing...${NC}"
sleep 120

echo ""
echo -e "${BLUE}🧪 Testing threshold calculations with new data...${NC}"

# Test the fixed curl commands
echo "Testing API request rate calculation..."
response=$(curl -s 'http://localhost:5002/calculate-threshold?metric=sum(rate(http_requests_total[1m]))')
if [[ $response == *"threshold"* ]]; then
    echo -e "✅ ${GREEN}API request rate calculation working!${NC}"
    echo "$response" | jq .
else
    echo -e "⚠️  ${YELLOW}Still processing data...${NC}"
fi

echo ""
echo "Checking current recommendations..."
curl -s http://localhost:5002/threshold-recommendations | jq .

echo ""
echo -e "${GREEN}🎯 Next steps:${NC}"
echo "1. Wait 30-60 minutes for algorithms to process the data"
echo "2. Check recommendations: curl -s http://localhost:5002/threshold-recommendations | jq ."
echo "3. Test individual calculations: curl -s 'http://localhost:5002/calculate-threshold?metric=sum(rate(http_requests_total[1m]))' | jq ."
echo "4. Monitor in Prometheus: http://localhost:9090/graph?g0.expr=threshold_recommendations"