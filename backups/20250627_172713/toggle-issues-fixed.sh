#!/bin/bash

function print_usage {
    echo "Usage: ./toggle-issues-fixed.sh [scenario] [on|off]"
    echo "Available scenarios:"
    echo "  memory-leak - Simulate memory leak in Auth Service"
    echo "  high-load - Simulate high CPU load in Transaction Service"  
    echo "  latency - Simulate network latency in Notification Service"
    echo "  all - Toggle all scenarios"
}

if [ $# -ne 2 ]; then
    print_usage
    exit 1
fi

SCENARIO=$1
ACTION=$2

if [ "$ACTION" != "on" ] && [ "$ACTION" != "off" ]; then
    echo "Error: Second parameter must be 'on' or 'off'"
    exit 1
fi

# Convert action to boolean
if [ "$ACTION" == "on" ]; then
    VALUE="true"
else
    VALUE="false"
fi

case "$SCENARIO" in
    memory-leak)
        echo "Setting SIMULATE_MEMORY_LEAK to $VALUE in Auth Service"
        # Restart container with new environment variable
        docker compose stop auth-service
        if [ "$ACTION" == "on" ]; then
            docker compose up -d auth-service -e SIMULATE_MEMORY_LEAK=true
        else
            docker compose up -d auth-service -e SIMULATE_MEMORY_LEAK=false
        fi
        ;;
    high-load)
        echo "Setting SIMULATE_HIGH_LOAD to $VALUE in Transaction Service"
        docker compose stop transaction-service
        if [ "$ACTION" == "on" ]; then
            docker compose up -d transaction-service -e SIMULATE_HIGH_LOAD=true
        else
            docker compose up -d transaction-service -e SIMULATE_HIGH_LOAD=false
        fi
        ;;
    latency)
        echo "Setting SIMULATE_LATENCY to $VALUE in Notification Service"
        docker compose stop notification-service
        if [ "$ACTION" == "on" ]; then
            docker compose up -d notification-service -e SIMULATE_LATENCY=true
        else
            docker compose up -d notification-service -e SIMULATE_LATENCY=false
        fi
        ;;
    *)
        echo "Error: Unknown scenario '$SCENARIO'"
        print_usage
        exit 1
        ;;
esac

echo "Service restarted with $SCENARIO simulation $ACTION"
sleep 10
echo "Ready for testing!"
