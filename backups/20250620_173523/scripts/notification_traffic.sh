#!/bin/bash
echo "Generating notification service traffic to trigger latency..."
echo "Started at: $(date)"

for i in {1..20}; do
  # Generate various notification requests
  curl -s http://localhost:8080/notifications/history/1 > /dev/null
  curl -s http://localhost:8080/notifications/history/2 > /dev/null
  curl -s http://localhost:8080/notifications/history/3 > /dev/null
  
  # Send notification requests
  curl -s -X POST -H "Content-Type: application/json" \
  -d '{"userId":1,"message":"Test notification"}' \
  http://localhost:8080/notifications/send > /dev/null
  
  echo "Completed notification batch $i/20"
  sleep 2
done
echo "Notification traffic generation complete at: $(date)"
