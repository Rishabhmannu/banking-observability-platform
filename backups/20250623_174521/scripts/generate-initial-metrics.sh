#!/bin/bash

echo "📊 Generating Initial Metrics"
echo "============================"

echo "Sending various transaction types..."

# Generate 100 quick transactions
for i in {1..100}; do
    # Random transaction type
    types=("deposit" "withdrawal" "transfer" "query")
    type=${types[$RANDOM % ${#types[@]}]}
    
    # Mix of fast and slow transactions
    if [ $((RANDOM % 10)) -lt 8 ]; then
        duration="0.$(($RANDOM % 3 + 1))"  # 0.1 to 0.3 seconds
        status="success"
    elif [ $((RANDOM % 10)) -lt 9 ]; then
        duration="0.$(($RANDOM % 5 + 5))"  # 0.5 to 0.9 seconds (slow)
        status="success"
    else
        duration="0.2"
        status="error"
    fi
    
    curl -s -X POST http://localhost:5003/simulate-transaction \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"$type\",
            \"duration\": $duration,
            \"status\": \"$status\",
            \"error_code\": \"500\"
        }" > /dev/null
    
    # Show progress
    if [ $((i % 10)) -eq 0 ]; then
        echo "  Sent $i transactions..."
    fi
done

echo "✅ Sent 100 test transactions"

echo ""
echo "Triggering aggregator calculations..."
curl -s -X POST http://localhost:5004/trigger-calculation \
    -H "Content-Type: application/json" \
    -d '{"type": "all"}' > /dev/null

echo "✅ Triggered performance calculations"

echo ""
echo "🔍 Current metrics status:"
echo "========================"

# Check some key metrics
metrics=(
    "transaction_requests_total"
    "transaction_performance_score" 
    "slow_transaction_percentage{threshold=\"0.5s\"}"
)

for metric in "${metrics[@]}"; do
    value=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result[0].value[1] // "No data"' 2>/dev/null)
    echo "$metric: $value"
done

echo ""
echo "📊 Check your Grafana dashboard now!"
echo "   URL: http://localhost:3000"
echo "   Dashboard: Transaction Performance Monitoring"