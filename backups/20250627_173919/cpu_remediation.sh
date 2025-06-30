#!/bin/bash
echo "Starting CPU monitoring and remediation..."
echo "CPU monitoring started at: $(date)"

while true; do
  # Get CPU usage from transaction service
  CPU_USAGE=$(docker stats banking-transaction-service --no-stream --format "{{.CPUPerc}}" | sed 's/%//')
  
  if [[ ! -z "$CPU_USAGE" ]]; then
    echo "$(date): Current transaction service CPU usage: $CPU_USAGE%"
    
    # If CPU exceeds threshold, take remediation action
    if (( $(echo "$CPU_USAGE > 70" | bc -l) )); then
      echo "$(date): ALERT! CPU threshold exceeded ($CPU_USAGE% > 70%)"
      echo "$(date): Initiating automated remediation..."
      
      # Turn off high CPU load simulation
      ./toggle-issues.sh high-load off
      
      echo "$(date): CPU load simulation disabled"
      echo "$(date): Remediation completed at $(date)"
      break
    fi
  else
    echo "$(date): Warning - Could not get CPU usage for transaction service"
  fi
  
  sleep 10
done
