#!/bin/bash

# Script to fix remaining issues in the Transaction Tracing dashboard

echo "🔧 Fixing Transaction Tracing Dashboard Issues..."

# Get dashboard UID
DASHBOARD_UID="dd1ef5d2-15b8-4c9c-b18c-d35d7ba21926"
GRAFANA_USER="admin"
GRAFANA_PASS="bankingdemo"
GRAFANA_URL="http://localhost:3000"

# First, let's export the current dashboard
echo "📥 Exporting current dashboard..."
CURRENT_DASHBOARD=$(curl -s -u $GRAFANA_USER:$GRAFANA_PASS "$GRAFANA_URL/api/dashboards/uid/$DASHBOARD_UID")

# Extract just the dashboard part
DASHBOARD_JSON=$(echo "$CURRENT_DASHBOARD" | jq '.dashboard')

# Fix 1: Update Trace Generation Errors panel to use correct metric name
echo "🔧 Fixing Trace Generation Errors panel..."
DASHBOARD_JSON=$(echo "$DASHBOARD_JSON" | jq '
  (.panels[] | select(.title == "❌ Trace Generation Errors").targets[0].expr) |= 
  "sum(rate(trace_generation_errors[5m])) * 300"
')

# Fix 2: Fix Service Dependencies panel
echo "🔧 Fixing Service Dependencies panel..."
DASHBOARD_JSON=$(echo "$DASHBOARD_JSON" | jq '
  .panels[] |= (
    if .title == "🔗 Service Dependencies" then
      .type = "nodeGraph" |
      .datasource = "Jaeger" |
      .targets = [{
        "datasource": "Jaeger",
        "queryType": "upload",
        "refId": "A",
        "service": "$service",
        "spanKinds": ["SPAN_KIND_SERVER"]
      }] |
      .options = {
        "nodes": {
          "mainStatUnit": "ops"
        }
      }
    else . end
  )
')

# Fix 3: Add proper error handling for Jaeger queries
echo "🔧 Adding error handling to Jaeger panels..."
DASHBOARD_JSON=$(echo "$DASHBOARD_JSON" | jq '
  .panels[] |= (
    if .datasource == "Jaeger" then
      .options.showErrorState = true
    else . end
  )
')

# Update the dashboard
echo "📤 Updating dashboard..."
UPDATE_PAYLOAD=$(jq -n \
  --argjson dashboard "$DASHBOARD_JSON" \
  '{
    "dashboard": $dashboard,
    "overwrite": true,
    "message": "Fixed Trace Generation Errors metric and Service Dependencies panel"
  }')

RESPONSE=$(curl -s -X POST \
  -u $GRAFANA_USER:$GRAFANA_PASS \
  -H "Content-Type: application/json" \
  -d "$UPDATE_PAYLOAD" \
  "$GRAFANA_URL/api/dashboards/db")

if echo "$RESPONSE" | jq -e '.status == "success"' > /dev/null 2>&1; then
  echo "✅ Dashboard updated successfully!"
else
  echo "❌ Failed to update dashboard:"
  echo "$RESPONSE" | jq .
fi

# Check if trace generation errors are happening
echo ""
echo "📊 Checking current metrics..."
echo "Trace Generation Errors:"
curl -s "http://localhost:9090/api/v1/query?query=trace_generation_errors" | jq '.data.result[0].value[1]' 2>/dev/null || echo "0 (no errors)"

echo ""
echo "Traces Generated Total:"
curl -s "http://localhost:9090/api/v1/query?query=sum(rate(traces_generated_total[1m]))*60" | jq '.data.result[0].value[1]' 2>/dev/null || echo "No data"

# Restart Grafana to ensure plugins are loaded properly
echo ""
echo "🔄 Restarting Grafana to reload plugins..."
docker-compose restart grafana

echo ""
echo "✅ Fixes applied! Please wait 30 seconds for Grafana to restart, then refresh your dashboard."
echo "📝 Note: The Service Dependencies panel may take a few minutes to show data as Jaeger builds the dependency map."