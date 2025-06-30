#!/bin/bash
echo "======================================="
echo "  AIOps Anomaly Testing Master Script"
echo "======================================="
echo ""

# Verify all scripts exist
scripts=("toggle-issues.sh" "auth_traffic.sh" "transaction_traffic.sh" "notification_traffic.sh" "memory_remediation.sh" "cpu_remediation.sh")

for script in "${scripts[@]}"; do
  if [[ ! -f "$script" ]]; then
    echo "ERROR: Missing required script: $script"
    exit 1
  fi
done

echo "All required scripts found. Starting tests..."
echo ""

# Test 1: Memory Leak
echo "========================================="
echo "TEST 1: MEMORY LEAK ANOMALY"
echo "========================================="
echo "1. Starting memory leak simulation..."
./toggle-issues.sh memory-leak on

echo "2. Generating auth service traffic..."
./auth_traffic.sh

echo "3. Please monitor all three tools for memory growth"
echo "4. When ready to test remediation, run: ./memory_remediation.sh"
echo ""
read -p "Press ENTER when memory leak testing is complete..."

# Test 2: CPU Spike  
echo ""
echo "========================================="
echo "TEST 2: CPU SPIKE ANOMALY"
echo "========================================="
echo "1. Resetting previous test..."
./toggle-issues.sh memory-leak off
sleep 60

echo "2. Starting CPU spike simulation..."
./toggle-issues.sh high-load on

echo "3. Generating transaction service traffic..."
./transaction_traffic.sh

echo "4. Please monitor all three tools for CPU spike"
echo "5. When ready to test remediation, run: ./cpu_remediation.sh"
echo ""
read -p "Press ENTER when CPU spike testing is complete..."

# Test 3: Network Latency
echo ""
echo "========================================="
echo "TEST 3: NETWORK LATENCY ANOMALY"
echo "========================================="
echo "1. Resetting previous test..."
./toggle-issues.sh high-load off
sleep 60

echo "2. Starting network latency simulation..."
./toggle-issues.sh latency on

echo "3. Generating notification service traffic..."
./notification_traffic.sh

echo "4. Please monitor all three tools for latency increases"
echo ""
read -p "Press ENTER when latency testing is complete..."

# Clean up
echo ""
echo "========================================="
echo "CLEANING UP"
echo "========================================="
./toggle-issues.sh latency off
./toggle-issues.sh all off

echo ""
echo "All tests completed!"
echo "Run './comparison_tracker.sh' to document your findings."
