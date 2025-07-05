#!/usr/bin/env bash
OUTPUT_FILE="kubernetes-metrics-output.txt"

# Run everything in a single block and redirect stdout once
{
  echo "===== container_cpu_usage_percent ====="
  curl --max-time 10 -s 'http://localhost:9090/api/v1/query?query=container_cpu_usage_percent' | jq .

  echo -e "\n===== container_memory_usage_bytes ====="
  curl --max-time 10 -s 'http://localhost:9090/api/v1/query?query=container_memory_usage_bytes' | jq .

  echo -e "\n===== container_cpu_usage_cores ====="
  curl --max-time 10 -s 'http://localhost:9090/api/v1/query?query=container_cpu_usage_cores' | jq .

  echo -e "\n===== container_cpu_usage_percent (metrics only) ====="
  curl --max-time 10 -s 'http://localhost:9090/api/v1/query?query=container_cpu_usage_percent' | jq '.data.result[0].metric'
} > "$OUTPUT_FILE"
