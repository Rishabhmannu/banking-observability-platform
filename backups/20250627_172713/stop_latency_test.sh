#!/bin/bash
echo "Stopping latency stress test..."

if [ -f /tmp/latency_pids.txt ]; then
    while read pid; do
        kill $pid 2>/dev/null
    done < /tmp/latency_pids.txt
    rm -f /tmp/latency_pids.txt
fi

pkill -f "curl.*notifications" 2>/dev/null

echo "Latency stress test stopped at: $(date)"
echo "Response times should return to normal shortly."
