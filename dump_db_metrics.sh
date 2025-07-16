#!/usr/bin/env bash
set -euo pipefail

OUTFILE="db_metrics.txt"
PROM_API="http://localhost:9090/api/v1"

# remove any old data
rm -f "$OUTFILE"

# helper: write a header then run a command (or pipeline) and append its output
run_section() {
  local title="$1"; shift
  {
    echo "================================================================"
    echo "$title"
    echo "----------------------------------------------------------------"
    # run the rest of the args as a command
    "$@"
    echo
    echo
  } >> "$OUTFILE"
}

# 1) Check if the metric exists
run_section "1) banking_db_connections_active exists?" \
  curl -s "${PROM_API}/query?query=banking_db_connections_active"

# 2) List all banking-* metric names
run_section "2) All metrics containing 'banking'" \
  bash -c "curl -s '${PROM_API}/label/__name__/values' | grep -i banking || echo '<no matches>'"

# 3) All metrics containing “connection”
run_section "3) All metrics containing 'connection'" \
  bash -c "curl -s '${PROM_API}/label/__name__/values' | grep -i connection || echo '<no matches>'"

# 4) PostgreSQL backends count
run_section "4) pg_stat_database_numbackends" \
  curl -s "${PROM_API}/query?query=pg_stat_database_numbackends"

# 5) All metrics for job=banking-db-demo
run_section "5) All series for job=banking-db-demo" \
  curl -s "${PROM_API}/series?match[]={job=\"banking-db-demo\"}"

# 6) The 'up' metric for job=banking-db-demo
run_section "6) up{job=\"banking-db-demo\"}" \
  curl -s "${PROM_API}/query?query=up{job=\"banking-db-demo\"}"

echo "All queries complete. Results are in $OUTFILE"
