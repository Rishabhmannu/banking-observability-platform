#!/bin/bash

echo "🚀 Generating cache traffic..."

# Base URL
BASE_URL="http://localhost:8080"

# Function to make requests
make_requests() {
    echo "Making requests to generate cache activity..."
    
    # Account requests (these should be cached)
    for i in {1..5}; do
        echo "Fetching account $i..."
        curl -s "$BASE_URL/accounts/$i" > /dev/null
        sleep 0.5
    done
    
    # Repeat to generate cache hits
    echo "Repeating requests to generate cache hits..."
    for i in {1..5}; do
        curl -s "$BASE_URL/accounts/$i" > /dev/null
        sleep 0.2
    done
    
    # Transaction requests
    echo "Fetching transactions..."
    curl -s "$BASE_URL/transactions" > /dev/null
    curl -s "$BASE_URL/transactions/1" > /dev/null
    curl -s "$BASE_URL/transactions/2" > /dev/null
    
    # Create a transaction (should invalidate cache)
    echo "Creating transaction (cache invalidation)..."
    curl -X POST "$BASE_URL/transactions" \
        -H "Content-Type: application/json" \
        -d '{"accountId": 1, "amount": 100, "type": "DEPOSIT"}' \
        -s > /dev/null
    
    # Fetch accounts again (should be cache miss after invalidation)
    echo "Fetching accounts after transaction..."
    curl -s "$BASE_URL/accounts/1" > /dev/null
}

# Run continuously
while true; do
    make_requests
    echo "---"
    echo "Cache stats:"
    curl -s http://localhost:5020/cache/stats | jq .
    echo "Waiting 10 seconds..."
    sleep 10
done