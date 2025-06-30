#!/bin/bash
echo "Stopping all stress tests..."

# Kill all background processes
if [ -f /tmp/stress_pids.txt ]; then
    while read pid; do
        kill $pid 2>/dev/null
        echo "Stopped process $pid"
    done < /tmp/stress_pids.txt
    rm -f /tmp/stress_pids.txt
fi

# Also kill any curl processes that might be running
pkill -f "curl.*localhost:8080" 2>/dev/null

echo "All stress tests stopped at: $(date)"
echo "System should return to normal load shortly."
