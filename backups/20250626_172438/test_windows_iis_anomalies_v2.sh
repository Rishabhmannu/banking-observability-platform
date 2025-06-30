#!/bin/bash

echo "🧪 Windows IIS Anomaly Testing Script"
echo "===================================="
echo "This script will trigger various anomalies in the mock Windows IIS metrics"
echo ""

# Function to trigger anomalies
trigger_anomaly() {
    local anomaly_type=$1
    local duration=$2
    
    echo "🔄 Triggering $anomaly_type for $duration seconds..."
    
    case $anomaly_type in
        "volume_surge")
            docker exec mock-windows-exporter sh -c "echo 'volume_surge' > /tmp/anomaly_trigger"
            ;;
            
        "volume_dip")
            docker exec mock-windows-exporter sh -c "echo 'normal' > /tmp/anomaly_trigger"
            ;;
            
        "response_degradation")
            docker exec mock-windows-exporter sh -c "echo 'true' > /tmp/degradation_active"
            ;;
            
        "high_errors")
            docker exec mock-windows-exporter sh -c "echo 'true' > /tmp/high_errors_active"
            ;;
            
        "technical_exceptions")
            docker exec mock-windows-exporter sh -c "echo 'true' > /tmp/exceptions_burst"
            ;;
            
        "custom_errors")
            docker exec mock-windows-exporter sh -c "echo 'true' > /tmp/custom_errors_burst"
            ;;
            
        "apppool_failure")
            docker exec mock-windows-exporter sh -c "echo 'BankingAppPool' > /tmp/apppool_failure"
            ;;
    esac
    
    sleep $duration
    
    # Stop the anomaly
    echo "⏹️ Stopping $anomaly_type..."
    docker exec mock-windows-exporter sh -c "rm -f /tmp/*_active /tmp/*_burst /tmp/*_trigger /tmp/*_failure 2>/dev/null"
    docker exec mock-windows-exporter sh -c "echo 'normal' > /tmp/anomaly_trigger"
    
    echo "✅ $anomaly_type anomaly completed"
    echo ""
}

# Main menu
while true; do
    echo "🎯 Select an anomaly to trigger:"
    echo "================================"
    echo "1) Volume Surge (3x normal traffic)"
    echo "2) Volume Dip (reduced traffic)"
    echo "3) Response Time Degradation (5x slower)"
    echo "4) High Error Rate (10% errors)"
    echo "5) Technical Exceptions Spike"
    echo "6) Custom Error Code Burst"
    echo "7) Application Pool Failure"
    echo "8) Exit"
    echo ""
    read -p "Enter choice (1-8): " choice
    
    case $choice in
        1)
            echo "📈 Volume Surge Test"
            echo "Watch for: Request Volume jumping to 6K-10K req/m"
            read -p "Press Enter to start..." 
            trigger_anomaly "volume_surge" 60
            ;;
            
        2)
            echo "📉 Volume Dip Test"
            echo "Watch for: Request Volume dropping significantly"
            read -p "Press Enter to start..."
            trigger_anomaly "volume_dip" 60
            ;;
            
        3)
            echo "⏱️ Response Time Degradation Test"
            echo "Watch for: P95 Response Time > 500ms"
            read -p "Press Enter to start..."
            trigger_anomaly "response_degradation" 60
            ;;
            
        4)
            echo "❌ High Error Rate Test"
            echo "Watch for: Success Rate < 95%"
            read -p "Press Enter to start..."
            trigger_anomaly "high_errors" 60
            ;;
            
        5)
            echo "🐛 Technical Exceptions Test"
            echo "Watch for: Technical Exceptions % > 1%"
            read -p "Press Enter to start..."
            trigger_anomaly "technical_exceptions" 30
            ;;
            
        6)
            echo "🏷️ Custom Error Codes Test"
            echo "Watch for: New error codes in Custom Error Codes panel"
            read -p "Press Enter to start..."
            trigger_anomaly "custom_errors" 30
            ;;
            
        7)
            echo "💥 Application Pool Failure Test"
            echo "Watch for: Red 'Stopped' in IIS Infrastructure Health"
            read -p "Press Enter to start..."
            trigger_anomaly "apppool_failure" 45
            ;;
            
        8)
            echo "👋 Exiting..."
            exit 0
            ;;
            
        *)
            echo "❌ Invalid choice. Please try again."
            ;;
    esac
    
    echo ""
    echo "⏸️ Waiting for metrics to normalize..."
    sleep 15
    echo ""
done
