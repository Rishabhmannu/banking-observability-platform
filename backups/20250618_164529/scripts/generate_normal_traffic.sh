#!/bin/bash
echo "Generating normal traffic pattern..."
for i in {1..100}; do
  curl -s http://localhost:8080/accounts/accounts > /dev/null
  curl -s http://localhost:8080/health > /dev/null
  sleep 0.5
done
echo "Normal traffic generation complete."
