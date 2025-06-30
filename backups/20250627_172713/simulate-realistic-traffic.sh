#!/bin/bash

echo "🏦 Simulating Realistic Banking Traffic"
echo "====================================="

# Function to generate transactions
generate_transactions() {
    local duration=$1
    local rate=$2
    
    echo "Generating $rate transactions per second for $duration seconds..."
    
    end_time=$(($(date +%s) + duration))
    transaction_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        # Random transaction type
        types=("deposit" "withdrawal" "transfer" "query")
        type=${types[$RANDOM % ${#types[@]}]}
        
        # Random duration (normal operations)
        if [ $((RANDOM % 100)) -lt 95 ]; then
            # 95% normal response time
            duration=$(awk -v min=0.05 -v max=0.3 'BEGIN{print min+rand()*(max-min)}')
        else
            # 5% slow requests
            duration=$(awk -v min=0.5 -v max=2.0 'BEGIN{print min+rand()*(max-min)}')
        fi
        
        # Random success (98% success rate)
        if [ $((RANDOM % 100)) -lt 98 ]; then
            status="success"
            error_code=""
        else
            status="error"
            errors=("400" "404" "500" "503")
            error_code=${errors[$RANDOM % ${#errors[@]}]}
        fi
        
        # Send transaction
        curl -s -X POST http://localhost:5003/simulate-transaction \
            -H "Content-Type: application/json" \
            -d "{
                \"type\": \"$type\",
                \"duration\": $duration,
                \"status\": \"$status\",
                \"error_code\": \"$error_code\"
            }" > /dev/null &
        
        # Rate limiting
        sleep $(awk -v rate=$rate 'BEGIN{print 1/rate}')
        
        transaction_count=$((transaction_count + 1))
        
        # Progress indicator
        if [ $((transaction_count % 100)) -eq 0 ]; then
            echo "  Generated $transaction_count transactions..."
        fi
    done
    
    echo "✅ Generated $transaction_count transactions"
}

# Main simulation scenarios
echo "1️⃣ Normal Business Hours Traffic"
echo "------------------------------"
generate_transactions 120 10  # 2 minutes at 10 TPS

echo ""
echo "2️⃣ Peak Load Simulation"
echo "---------------------"
generate_transactions 60 25  # 1 minute at 25 TPS

echo ""
echo "3️⃣ Off-Hours Traffic"
echo "------------------"
generate_transactions 60 2  # 1 minute at 2 TPS

echo ""
echo "✨ Traffic simulation complete!"
echo "📊 View results in Grafana Transaction Performance Dashboard"