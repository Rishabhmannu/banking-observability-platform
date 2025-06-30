#!/bin/bash

echo "🧪 Windows IIS Anomaly Testing Script"
echo "===================================="
echo "This script will trigger various anomalies in the mock Windows IIS metrics"
echo ""

# Function to trigger anomalies via API calls to the mock-windows-exporter
trigger_anomaly() {
    local anomaly_type=$1
    local duration=$2
    
    echo "🔄 Triggering $anomaly_type for $duration seconds..."
    
    # We'll create a temporary Python script to send commands to our exporter
    cat > /tmp/trigger_iis_anomaly.py << EOF
import requests
import time
import threading
import random

def trigger_${anomaly_type}():
    print(f"Activating {anomaly_type} anomaly...")
    
    if "${anomaly_type}" == "volume_surge":
        # Generate 10x normal traffic
        for i in range(${duration}):
            for j in range(1000):
                try:
                    requests.get("http://localhost:8090/api/test", timeout=0.1)
                except:
                    pass
            time.sleep(1)
            
    elif "${anomaly_type}" == "volume_dip":
        # Just wait - no traffic generation
        print("Simulating volume dip (reducing traffic)...")
        time.sleep(${duration})
        
    elif "${anomaly_type}" == "response_degradation":
        # Make slow requests
        for i in range(${duration}):
            try:
                requests.get("http://localhost:8090/api/slow", timeout=5)
            except:
                pass
            time.sleep(0.5)
            
    elif "${anomaly_type}" == "high_errors":
        # Generate requests that will fail
        for i in range(${duration}):
            for j in range(100):
                try:
                    requests.get("http://localhost:8090/api/error", timeout=0.5)
                    requests.get("http://localhost:8090/nonexistent", timeout=0.5)
                except:
                    pass
            time.sleep(1)
            
    elif "${anomaly_type}" == "technical_exceptions":
        # Trigger .NET exceptions
        for i in range(${duration}):
            for j in range(50):
                try:
                    requests.post("http://localhost:8090/api/exception", 
                                json={"type": "NullReference"}, timeout=0.5)
                except:
                    pass
            time.sleep(1)

trigger_${anomaly_type}()
EOF

    python3 /tmp/trigger_iis_anomaly.py &
    ANOMALY_PID=$!
    
    # Also need to signal the mock-windows-exporter about the anomaly
    docker exec mock-windows-exporter sh -c "echo '${anomaly_type}' > /tmp/anomaly_trigger"
    
    sleep $duration
    
    # Stop the anomaly
    kill $ANOMALY_PID 2>/dev/null
    docker exec mock-windows-exporter sh -c "echo 'normal' > /tmp/anomaly_trigger"
    
    rm -f /tmp/trigger_iis_anomaly.py
    echo "✅ $anomaly_type anomaly completed"
    echo ""
}

# Main menu
while true; do
    echo "🎯 Select an anomaly to trigger:"
    echo "================================"
    echo "1) Volume Surge (3x-5x normal traffic)"
    echo "2) Volume Dip (10% of normal traffic)"
    echo "3) Response Time Degradation (5x slower)"
    echo "4) High Error Rate (10% errors)"
    echo "5) Technical Exceptions Spike"
    echo "6) Custom Error Code Burst"
    echo "7) Application Pool Failure"
    echo "8) Run All Tests Sequentially"
    echo "9) Exit"
    echo ""
    read -p "Enter choice (1-9): " choice
    
    case $choice in
        1)
            echo "📈 Volume Surge Test"
            echo "Watch for:"
            echo "- Request Volume jumping to 6K-10K req/m"
            echo "- Volume Surge Indicator turning red (>100%)"
            echo "- Volume Status timeline showing red 'Volume Surge'"
            read -p "Press Enter to start..." 
            trigger_anomaly "volume_surge" 60
            ;;
            
        2)
            echo "📉 Volume Dip Test"
            echo "Watch for:"
            echo "- Request Volume dropping below 500 req/m"
            echo "- Volume Surge Indicator turning blue (< -50%)"
            echo "- Volume Status timeline showing blue 'Volume Dip'"
            read -p "Press Enter to start..."
            trigger_anomaly "volume_dip" 60
            ;;
            
        3)
            echo "⏱️ Response Time Degradation Test"
            echo "Watch for:"
            echo "- Response Time (P95) jumping above 500ms"
            echo "- Response Time graph showing spikes"
            echo "- Possible annotation 'Response Time Degradation'"
            read -p "Press Enter to start..."
            
            # Need to update the mock exporter to simulate slow responses
            docker exec mock-windows-exporter python3 -c "
import time
with open('/tmp/degradation_active', 'w') as f:
    f.write('true')
time.sleep(60)
with open('/tmp/degradation_active', 'w') as f:
    f.write('false')
" &
            
            echo "✅ Response degradation triggered for 60 seconds"
            sleep 65
            ;;
            
        4)
            echo "❌ High Error Rate Test"
            echo "Watch for:"
            echo "- Success Rate dropping below 95%"
            echo "- HTTP Response Codes pie chart showing more 4xx/5xx"
            echo "- Failed Transactions/min increasing"
            read -p "Press Enter to start..."
            trigger_anomaly "high_errors" 45
            ;;
            
        5)
            echo "🐛 Technical Exceptions Test"
            echo "Watch for:"
            echo "- Technical Exceptions % increasing above 1%"
            echo "- .NET exception types in metrics"
            read -p "Press Enter to start..."
            
            docker exec mock-windows-exporter python3 -c "
import time
with open('/tmp/exceptions_burst', 'w') as f:
    f.write('true')
time.sleep(30)
with open('/tmp/exceptions_burst', 'w') as f:
    f.write('false')
" &
            
            echo "✅ Exception burst triggered for 30 seconds"
            sleep 35
            ;;
            
        6)
            echo "🏷️ Custom Error Codes Test"
            echo "Watch for:"
            echo "- Custom Error Codes bars increasing"
            echo "- New error codes appearing"
            read -p "Press Enter to start..."
            
            docker exec mock-windows-exporter python3 -c "
import time
with open('/tmp/custom_errors_burst', 'w') as f:
    f.write('true')
time.sleep(30)
with open('/tmp/custom_errors_burst', 'w') as f:
    f.write('false')
" &
            
            echo "✅ Custom error burst triggered for 30 seconds"
            sleep 35
            ;;
            
        7)
            echo "💥 Application Pool Failure Test"
            echo "Watch for:"
            echo "- IIS Infrastructure Health showing red 'Stopped'"
            echo "- Worker Process Metrics dropping"
            read -p "Press Enter to start..."
            
            docker exec mock-windows-exporter python3 -c "
import time
with open('/tmp/apppool_failure', 'w') as f:
    f.write('BankingAppPool')
time.sleep(45)
with open('/tmp/apppool_failure', 'w') as f:
    f.write('none')
" &
            
            echo "✅ App pool failure triggered for 45 seconds"
            sleep 50
            ;;
            
        8)
            echo "🔄 Running All Tests Sequentially"
            echo "This will take about 5 minutes..."
            read -p "Press Enter to start..."
            
            for test in "volume_surge" "volume_dip" "response_degradation" "high_errors"; do
                echo ""
                echo "▶️ Running $test test..."
                trigger_anomaly "$test" 30
                echo "⏸️ Waiting 15 seconds before next test..."
                sleep 15
            done
            
            echo "✅ All tests completed!"
            ;;
            
        9)
            echo "👋 Exiting..."
            exit 0
            ;;
            
        *)
            echo "❌ Invalid choice. Please try again."
            ;;
    esac
    
    echo ""
    echo "⏸️ Waiting for metrics to normalize..."
    sleep 10
    echo ""
done