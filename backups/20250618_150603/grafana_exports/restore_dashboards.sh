#!/bin/bash
echo "🔄 Restoring Grafana dashboards..."
# This script assumes you are running it from within the 'grafana_exports' directory.
for file in *_complete.json; do
    if [ -f "$file" ]; then
        echo -n "Restoring dashboard from '$file'... "
        
        # Extract dashboard JSON and prepare payload for API
        dashboard_data=$(cat "$file")
        import_payload=$(jq -n --argjson dash "$dashboard_data" '{"dashboard": $dash.dashboard, "overwrite": true, "folderId": $dash.meta.folderId}')
        
        # Post the dashboard to Grafana for restoration
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u admin:bankingdemo \
            http://localhost:3000/api/dashboards/db \
            -d "$import_payload")
        
        if echo "$response" | grep -q "success"; then
            echo "✅"
        else
            echo "❌ - Check Grafana logs for details."
            echo "   Response: $response"
        fi
    fi
done
echo "✅ Restore process finished."
