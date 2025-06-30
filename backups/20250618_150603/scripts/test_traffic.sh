#!/bin/bash
echo "Generating traffic to test monitoring..."
for i in {1..30}; do
  echo "Request batch $i"
  curl -s http://localhost:8080/health > /dev/null
  curl -s http://localhost:8080/accounts/accounts > /dev/null
  curl -s http://localhost:8080/accounts/accounts/1 > /dev/null
  sleep 1
done
echo "Test traffic complete."
