#!/bin/bash
echo "Stopping memory stress test..."

# Remove memory-hungry containers
docker stop memory-hog-1 memory-hog-2 2>/dev/null
docker rm memory-hog-1 memory-hog-2 2>/dev/null

# Kill auth traffic processes
pkill -f "curl.*auth/login" 2>/dev/null

echo "Memory stress test stopped at: $(date)"
echo "Memory usage should return to normal shortly."
