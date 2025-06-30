#!/bin/bash
echo "Generating significant traffic pattern for New Relic detection..."
for i in {1..200}; do
  # Health checks
  curl -s http://localhost:8080/health > /dev/null
  
  # Account service calls
  curl -s http://localhost:8080/accounts/accounts > /dev/null
  curl -s http://localhost:8080/accounts/accounts/1 > /dev/null
  
  # Auth service calls
  curl -s -X POST -H "Content-Type: application/json"     -d '{"username":"john.doe","password":"password123"}'     http://localhost:8080/auth/login > /dev/null
    
  # Transaction service calls
  curl -s -X POST -H "Content-Type: application/json"     -d '{"accountId":1,"amount":100,"type":"DEPOSIT"}'     http://localhost:8080/transactions/transactions > /dev/null
    
  echo -n "."
  sleep 0.2
done
echo "Traffic generation complete."
