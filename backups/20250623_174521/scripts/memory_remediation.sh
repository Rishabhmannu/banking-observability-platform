#!/bin/bash
echo "Starting memory leak monitoring and remediation..."
echo "Monitoring started at: $(date)"

while true; do
  # Get memory usage from auth service
  MEMORY_USAGE=$(docker stats banking-auth-service --no-stream --format "{{.MemPerc}}" | sed 's/%//')
  
  if [[ ! -z "$MEMORY_USAGE" ]]; then
    echo "$(date): Current auth service memory usage: $MEMORY_USAGE%"
    
    # If memory exceeds threshold, restart the service
    if (( $(echo "$MEMORY_USAGE > 80" | bc -l) )); then
      echo "$(date): ALERT! Memory threshold exceeded ($MEMORY_USAGE% > 80%)"
      echo "$(date): Initiating automated remediation..."
      
      # Turn off the memory leak simulation first
      ./toggle-issues.sh memory-leak off
      
      # Restart the auth service
      docker compose restart auth-service
      
      echo "$(date): Auth service restarted successfully"
      echo "$(date): Memory leak simulation disabled"
      echo "$(date): Remediation completed"
      break
    fi
  else
    echo "$(date): Warning - Could not get memory usage for auth service"
  fi
  
  sleep 10
done
