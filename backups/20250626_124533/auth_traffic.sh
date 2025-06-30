#!/bin/bash
echo "Generating auth service traffic to accelerate memory leak..."
echo "Started at: $(date)"

for i in {1..50}; do
  curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"john.doe","password":"password123"}' \
  http://localhost:8080/auth/login > /dev/null
  
  curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"jane.smith","password":"password456"}' \
  http://localhost:8080/auth/login > /dev/null
  
  curl -s -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' \
  http://localhost:8080/auth/login > /dev/null
  
  echo "Completed batch $i/50"
  sleep 1
done
echo "Auth traffic generation complete at: $(date)"
