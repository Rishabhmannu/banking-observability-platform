#!/bin/bash
echo "Generating transaction service traffic to trigger CPU spike..."
echo "Started at: $(date)"

for i in {1..30}; do
  # Create various types of transactions
  curl -s -X POST -H "Content-Type: application/json" \
  -d '{"accountId":1,"amount":100,"type":"DEPOSIT"}' \
  http://localhost:8080/transactions/transactions > /dev/null
  
  curl -s -X POST -H "Content-Type: application/json" \
  -d '{"accountId":2,"amount":50,"type":"WITHDRAWAL"}' \
  http://localhost:8080/transactions/transactions > /dev/null
  
  curl -s -X POST -H "Content-Type: application/json" \
  -d '{"accountId":1,"amount":25,"type":"PAYMENT"}' \
  http://localhost:8080/transactions/transactions > /dev/null
  
  echo "Completed transaction batch $i/30"
  sleep 1
done
echo "Transaction traffic generation complete at: $(date)"
