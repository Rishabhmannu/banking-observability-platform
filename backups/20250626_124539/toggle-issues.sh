#!/bin/bash

function print_usage {
    echo "Usage: ./toggle-issues.sh [scenario] [on|off]"
    echo "Available scenarios:"
    echo "  slow-query    - Simulate slow database queries in Account Service"
    echo "  high-load     - Simulate high CPU load in Transaction Service"
    echo "  memory-leak   - Simulate memory leak in Auth Service"
    echo "  latency       - Simulate network latency in Notification Service"
    echo "  alert-storm   - Simulate alert storm in Fraud Detection Service"
    echo "  all           - Toggle all scenarios"
    echo "Examples:"
    echo "  ./toggle-issues.sh memory-leak on"
    echo "  ./toggle-issues.sh alert-storm off"
    echo "  ./toggle-issues.sh all on"
}

if [ $# -ne 2 ]; then
    print_usage
    exit 1
fi

SCENARIO=$1
ACTION=$2

if [ "$ACTION" != "on" ] && [ "$ACTION" != "off" ]; then
    echo "Error: Second parameter must be 'on' or 'off'"
    print_usage
    exit 1
fi

# Convert action to boolean
if [ "$ACTION" == "on" ]; then
    VALUE="true"
else
    VALUE="false"
fi

# Apply changes based on scenario
case "$SCENARIO" in
    slow-query)
        echo "Setting SIMULATE_SLOW_QUERY to $VALUE in Account Service"
        docker compose exec account-service /bin/sh -c "echo export SIMULATE_SLOW_QUERY=$VALUE > /tmp/env_var && source /tmp/env_var"
        ;;
    high-load)
        echo "Setting SIMULATE_HIGH_LOAD to $VALUE in Transaction Service"
        docker compose exec transaction-service /bin/sh -c "echo export SIMULATE_HIGH_LOAD=$VALUE > /tmp/env_var && source /tmp/env_var"
        ;;
    memory-leak)
        echo "Setting SIMULATE_MEMORY_LEAK to $VALUE in Auth Service"
        docker compose exec auth-service /bin/sh -c "echo export SIMULATE_MEMORY_LEAK=$VALUE > /tmp/env_var && source /tmp/env_var"
        ;;
    latency)
        echo "Setting SIMULATE_LATENCY to $VALUE in Notification Service"
        docker compose exec notification-service /bin/sh -c "echo export SIMULATE_LATENCY=$VALUE > /tmp/env_var && source /tmp/env_var"
        ;;
    alert-storm)
        echo "Setting SIMULATE_ALERT_STORM to $VALUE in Fraud Detection Service"
        docker compose exec fraud-detection /bin/sh -c "echo export SIMULATE_ALERT_STORM=$VALUE > /tmp/env_var && source /tmp/env_var"
        ;;
    all)
        echo "Setting all simulation scenarios to $VALUE"
        docker compose exec account-service /bin/sh -c "echo export SIMULATE_SLOW_QUERY=$VALUE > /tmp/env_var && source /tmp/env_var"
        docker compose exec transaction-service /bin/sh -c "echo export SIMULATE_HIGH_LOAD=$VALUE > /tmp/env_var && source /tmp/env_var"
        docker compose exec auth-service /bin/sh -c "echo export SIMULATE_MEMORY_LEAK=$VALUE > /tmp/env_var && source /tmp/env_var"
        docker compose exec notification-service /bin/sh -c "echo export SIMULATE_LATENCY=$VALUE > /tmp/env_var && source /tmp/env_var"
        docker compose exec fraud-detection /bin/sh -c "echo export SIMULATE_ALERT_STORM=$VALUE > /tmp/env_var && source /tmp/env_var"
        ;;
    *)
        echo "Error: Unknown scenario '$SCENARIO'"
        print_usage
        exit 1
        ;;
esac

echo "Done! Changes will take effect within a few seconds."
echo "Note: For some scenarios, you may need to restart the services to see the effect immediately."