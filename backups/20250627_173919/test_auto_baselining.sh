#!/bin/bash

echo "🧪 Comprehensive Auto-Baselining System Test"
echo "==========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    
    echo -e "${BLUE}🔍 Testing: $test_name${NC}"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    result=$(eval "$test_command" 2>/dev/null)
    
    if [[ $result =~ $expected_pattern ]]; then
        echo -e "  ✅ ${GREEN}PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ❌ ${RED}FAIL${NC}: $test_name"
        echo -e "     Expected pattern: $expected_pattern"
        echo -e "     Got: $result"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to generate test traffic
generate_test_traffic() {
    local duration=$1
    local rate=$2
    
    echo -e "${YELLOW}📊 Generating test traffic for ${duration}s at ${rate} req/s...${NC}"
    
    for ((i=1; i<=duration; i++)); do
        for ((j=1; j<=rate; j++)); do
            curl -s http://localhost:8080/health > /dev/null &
            curl -s http://localhost:8080/accounts/accounts > /dev/null &
        done
        sleep 1
    done
    
    wait # Wait for all background requests to complete
    echo -e "  ✅ Generated $((duration * rate * 2)) requests"
}

# Test 1: Service Health Checks
echo -e "${BLUE}📋 Phase 1: Service Health Checks${NC}"
echo "================================="

run_test "Banking API Health" \
    "curl -s http://localhost:8080/health" \
    "UP"

run_test "Prometheus Health" \
    "curl -s http://localhost:9090/-/healthy" \
    "Prometheus Server is Healthy"

run_test "Auto-Baselining Service Health" \
    "curl -s http://localhost:5002/health" \
    "healthy"

# Check if ML Detection Service is running (optional)
if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    echo -e "${BLUE}🤖 ML Detection Service detected - testing integration...${NC}"
    
    run_test "ML Detection Service Health" \
        "curl -s http://localhost:5001/health" \
        "healthy"
    
    echo -e "  ℹ️  Both ML Detection and Auto-Baselining are running independently ✅"
fi

# Test 2: Basic Functionality
echo ""
echo -e "${BLUE}🔧 Phase 2: Basic Functionality Tests${NC}"
echo "===================================="

run_test "Auto-Baselining Service Response" \
    "curl -s http://localhost:5002/health | jq -r '.service'" \
    "auto-baselining"

run_test "Algorithms Loading" \
    "curl -s http://localhost:5002/health | jq -r '.algorithms | length'" \
    "[0-9]+"

run_test "Metrics Endpoint" \
    "curl -s http://localhost:5002/metrics" \
    "baselining_calculations_total"

# Test 3: Generate Historical Data for Testing
echo ""
echo -e "${BLUE}📈 Phase 3: Generating Test Data${NC}"
echo "==============================="

echo "Generating diverse traffic patterns for algorithm testing..."

# Generate baseline traffic
generate_test_traffic 20 2  # 20 seconds at 2 req/s

echo "Waiting for metrics to be scraped..."
sleep 30

# Generate elevated traffic
generate_test_traffic 15 4  # 15 seconds at 4 req/s

echo "Waiting for metric processing..."
sleep 30

# Generate burst traffic
generate_test_traffic 10 8  # 10 seconds at 8 req/s

echo "Final processing wait..."
sleep 45

# Test 4: Threshold Calculation Tests
echo ""
echo -e "${BLUE}🎯 Phase 4: Threshold Calculation Tests${NC}"
echo "======================================"

# Test individual algorithms
algorithms=("rolling_statistics" "quantile_based" "isolation_forest" "local_outlier_factor")

echo "Testing threshold calculation for API request rate..."
calc_response=$(curl -s "http://localhost:5002/calculate-threshold?metric=sum(rate(http_requests_total[1m]))")

if [[ $calc_response == *"threshold"* ]]; then
    echo -e "  ✅ ${GREEN}Basic threshold calculation working${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Test individual algorithms
    for algo in "${algorithms[@]}"; do
        threshold=$(echo "$calc_response" | jq -r ".results.$algo.threshold" 2>/dev/null)
        confidence=$(echo "$calc_response" | jq -r ".results.$algo.confidence" 2>/dev/null)
        
        if [[ "$threshold" != "null" && "$threshold" != "0" ]]; then
            echo -e "    ✅ $algo: threshold=$threshold, confidence=$confidence"
        else
            echo -e "    ⚠️  $algo: insufficient data or calculation failed"
        fi
    done
else
    echo -e "  ❌ ${RED}Basic threshold calculation failed${NC}"
    echo -e "     Response: $calc_response"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test 5: Recommendations Endpoint
echo ""
echo -e "${BLUE}📊 Phase 5: Recommendations Testing${NC}"
echo "=================================="

run_test "Recommendations Endpoint Available" \
    "curl -s http://localhost:5002/threshold-recommendations | jq -r 'has(\"recommendations\")'" \
    "true"

recommendations_response=$(curl -s http://localhost:5002/threshold-recommendations)
recommendations_count=$(echo "$recommendations_response" | jq -r '.recommendations | keys | length' 2>/dev/null || echo "0")

echo -e "  📈 Total metric recommendations: $recommendations_count"

if [[ "$recommendations_count" -gt "0" ]]; then
    echo -e "  ✅ ${GREEN}Recommendations being generated${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Show sample recommendation
    sample_metric=$(echo "$recommendations_response" | jq -r '.recommendations | keys[0]' 2>/dev/null)
    if [[ "$sample_metric" != "null" && "$sample_metric" != "" ]]; then
        echo -e "  📋 Sample recommendation for '$sample_metric':"
        echo "$recommendations_response" | jq ".recommendations[\"$sample_metric\"]" 2>/dev/null | head -10
    fi
else
    echo -e "  ⚠️  ${YELLOW}No recommendations yet${NC} (normal for new deployment)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test 6: Prometheus Integration
echo ""
echo -e "${BLUE}📊 Phase 6: Prometheus Integration Tests${NC}"
echo "======================================="

# Check if auto-baselining target is discovered
targets_response=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null)
if echo "$targets_response" | grep -q "auto-baselining"; then
    echo -e "  ✅ ${GREEN}Auto-baselining target discovered in Prometheus${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Check target health
    if echo "$targets_response" | grep -A5 "auto-baselining" | grep -q '"health":"up"'; then
        echo -e "  ✅ ${GREEN}Target health: UP${NC}"
    else
        echo -e "  ⚠️  ${YELLOW}Target health: DOWN${NC} (may need more time)"
    fi
else
    echo -e "  ⚠️  ${YELLOW}Auto-baselining target not yet discovered${NC} (normal for new service)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test if metrics are being collected
sleep 10
metrics_response=$(curl -s "http://localhost:9090/api/v1/query?query=threshold_recommendations" 2>/dev/null)
if echo "$metrics_response" | grep -q "threshold_recommendations"; then
    echo -e "  ✅ ${GREEN}Threshold metrics available in Prometheus${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Count available threshold metrics
    metric_count=$(echo "$metrics_response" | jq -r '.data.result | length' 2>/dev/null || echo "0")
    echo -e "  📊 Available threshold metrics: $metric_count"
else
    echo -e "  ⚠️  ${YELLOW}Threshold metrics not yet available${NC} (normal for new service)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test 7: Algorithm Performance
echo ""
echo -e "${BLUE}🧠 Phase 7: Algorithm Performance Tests${NC}"
echo "======================================"

echo "Testing different metrics with all algorithms..."

test_metrics=(
    "sum(rate(http_requests_total[1m]))"
    "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le))"
)

working_algorithms=0
total_algorithm_tests=0

for metric in "${test_metrics[@]}"; do
    echo -e "  🔍 Testing with metric: $(echo $metric | cut -c1-50)..."
    
    response=$(curl -s "http://localhost:5002/calculate-threshold?metric=$metric" 2>/dev/null)
    
    for algorithm in "${algorithms[@]}"; do
        total_algorithm_tests=$((total_algorithm_tests + 1))
        threshold=$(echo "$response" | jq -r ".results.$algorithm.threshold" 2>/dev/null)
        
        if [[ "$threshold" != "null" && "$threshold" != "" && "$threshold" != "0" ]]; then
            working_algorithms=$((working_algorithms + 1))
            confidence=$(echo "$response" | jq -r ".results.$algorithm.confidence" 2>/dev/null)
            echo -e "    ✅ $algorithm: threshold=$threshold, confidence=$confidence"
        else
            echo -e "    ⚠️  $algorithm: no valid result"
        fi
    done
done

algorithm_success_rate=$((working_algorithms * 100 / total_algorithm_tests))
echo -e "  📊 Algorithm success rate: $algorithm_success_rate% ($working_algorithms/$total_algorithm_tests)"

if [[ $algorithm_success_rate -gt 25 ]]; then
    echo -e "  ✅ ${GREEN}Algorithm performance acceptable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ⚠️  ${YELLOW}Algorithm performance low${NC} (needs more historical data)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test 8: Service Stability
echo ""
echo -e "${BLUE}⚡ Phase 8: Service Stability Test${NC}"
echo "================================="

echo "Testing service stability under load..."

# Generate sustained traffic
generate_test_traffic 30 6  # 30 seconds at 6 req/s

# Check if services remain healthy
echo "Checking service health after load test..."

services=("8080/health" "9090/-/healthy" "5002/health")
service_names=("Banking" "Prometheus" "Auto-Baselining")

all_healthy_after_load=true
for i in "${!services[@]}"; do
    if curl -s "http://localhost:${services[$i]}" > /dev/null 2>&1; then
        echo -e "  ✅ ${service_names[$i]}: Healthy after load test"
    else
        echo -e "  ❌ ${service_names[$i]}: Unhealthy after load test"
        all_healthy_after_load=false
    fi
done

if $all_healthy_after_load; then
    echo -e "  ✅ ${GREEN}Load test passed - all services stable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ❌ ${RED}Load test failed - some services unstable${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test 9: Response Time Performance
echo ""
echo -e "${BLUE}🚀 Phase 9: Performance Tests${NC}"
echo "============================="

echo "Measuring response times..."

# Test health endpoint response time
start_time=$(date +%s%N)
curl -s http://localhost:5002/health > /dev/null
end_time=$(date +%s%N)
health_response_time=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds

echo -e "  📊 Health endpoint: ${health_response_time}ms"

# Test threshold calculation response time
start_time=$(date +%s%N)
curl -s "http://localhost:5002/calculate-threshold?metric=sum(rate(http_requests_total[1m]))" > /dev/null
end_time=$(date +%s%N)
calc_response_time=$(( (end_time - start_time) / 1000000 ))

echo -e "  📊 Threshold calculation: ${calc_response_time}ms"

if [[ $health_response_time -lt 2000 && $calc_response_time -lt 15000 ]]; then
    echo -e "  ✅ ${GREEN}Response times acceptable${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ⚠️  ${YELLOW}Response times slower than expected${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Final Results Summary
echo ""
echo -e "${BLUE}📋 Test Results Summary${NC}"
echo "======================="
echo -e "Total Tests: $TESTS_TOTAL"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

pass_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
echo -e "Pass Rate: $pass_rate%"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n🎉 ${GREEN}ALL TESTS PASSED!${NC}"
    echo -e "Auto-baselining system is working perfectly alongside your existing system."
elif [[ $pass_rate -ge 70 ]]; then
    echo -e "\n✅ ${GREEN}SYSTEM WORKING WELL${NC}"
    echo -e "Most tests passed. Minor issues are normal for a new deployment."
elif [[ $pass_rate -ge 50 ]]; then
    echo -e "\n⚠️  ${YELLOW}SYSTEM PARTIALLY WORKING${NC}"
    echo -e "Some functionality working. May need more time for data collection."
else
    echo -e "\n❌ ${RED}SYSTEM NEEDS ATTENTION${NC}"
    echo -e "Multiple issues detected. Check logs and configuration."
fi

echo ""
echo -e "${BLUE}📊 Current System Status:${NC}"
echo "========================="
echo "🏦 Banking Services: $(curl -s http://localhost:8080/health > /dev/null 2>&1 && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Down${NC}")"
echo "📊 Prometheus: $(curl -s http://localhost:9090/-/healthy > /dev/null 2>&1 && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Down${NC}")"
echo "🎯 Auto-Baselining: $(curl -s http://localhost:5002/health > /dev/null 2>&1 && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Down${NC}")"

# Check if ML Detection is running
if curl -s http://localhost:5001/health > /dev/null 2>&1; then
    echo "🤖 ML Detection: ${GREEN}Running${NC} (Both services coexisting ✅)"
fi

echo ""
echo -e "${BLUE}🔍 Troubleshooting Commands:${NC}"
echo "============================="
echo "# Check auto-baselining logs:"
echo "docker-compose logs auto-baselining"
echo ""
echo "# View current recommendations:"
echo "curl http://localhost:5002/threshold-recommendations | jq ."
echo ""
echo "# Test threshold calculation:"
echo "curl 'http://localhost:5002/calculate-threshold?metric=sum(rate(http_requests_total[1m]))' | jq ."
echo ""
echo "# Check Prometheus targets:"
echo "curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.job==\"auto-baselining\")'"
echo ""
echo "# Restart if needed:"
echo "docker-compose restart auto-baselining"

echo ""
echo -e "${GREEN}✅ Comprehensive testing complete!${NC}"

# If mostly working, show next steps
if [[ $pass_rate -ge 60 ]]; then
    echo ""
    echo -e "${BLUE}🎯 Recommended Next Steps:${NC}"
    echo "=========================="
    echo "1. Let the system collect data for 2-4 hours"
    echo "2. Monitor threshold recommendations: watch -n 60 'curl -s http://localhost:5002/threshold-recommendations | jq .'"
    echo "3. View metrics in Prometheus: http://localhost:9090/graph?g0.expr=threshold_recommendations"
    echo "4. Check algorithm performance periodically"
    echo "5. Both DDoS Detection and Auto-Baselining are now running independently! 🎉"
fi