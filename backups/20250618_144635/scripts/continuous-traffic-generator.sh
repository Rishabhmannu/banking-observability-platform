#!/bin/bash

echo "🚦 Starting Continuous Traffic Generator"
echo "======================================"
echo "Press Ctrl+C to stop"
echo ""

# Function to generate a single transaction
generate_transaction() {
    local types=("deposit" "withdrawal" "transfer" "query")
    local type=${types[$RANDOM % ${#types[@]}]}
    
    # 90% success, 10% failure
    if [ $((RANDOM % 100)) -lt 90 ]; then
        local status="success"
        local error_code=""
    else
        local status="error"
        local errors=("400" "404" "500" "503")
        local error_code=${errors[$RANDOM % ${#errors[@]}]}
    fi
    
    # Variable duration: 80% fast, 15% medium, 5% slow
    local rand=$((RANDOM % 100))
    if [ $rand -lt 80 ]; then
        local duration=$(awk -v min=0.05 -v max=0.3 'BEGIN{print min+rand()*(max-min)}')
    elif [ $rand -lt 95 ]; then
        local duration=$(awk -v min=0.3 -v max=0.8 'BEGIN{print min+rand()*(max-min)}')
    else
        local duration=$(awk -v min=0.8 -v max=2.0 'BEGIN{print min+rand()*(max-min)}')
    fi
    
    # Send the transaction
    curl -s -X POST http://localhost:5003/simulate-transaction \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"$type\",
            \"duration\": $duration,
            \"status\": \"$status\",
            \"error_code\": \"$error_code\"
        }" > /dev/null
}

# Main loop - generate 10 transactions per second
transaction_count=0
start_time=$(date +%s)

while true; do
    # Generate transaction in background to maintain rate
    generate_transaction &
    
    transaction_count=$((transaction_count + 1))
    
    # Show progress every 100 transactions
    if [ $((transaction_count % 100)) -eq 0 ]; then
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        rate=$(awk -v count=$transaction_count -v time=$elapsed 'BEGIN{printf "%.1f", count/time}')
        echo "$(date '+%H:%M:%S') - Generated $transaction_count transactions (Rate: $rate/sec)"
    fi
    
    # Sleep to maintain roughly 10 TPS
    sleep 0.1
done