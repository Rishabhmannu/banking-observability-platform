#!/bin/bash
echo "🔄 Restoring Grafana Dashboards from backup..."
echo "=========================================="
for dashboard_file in *_complete.json; do
    if [ -f "$dashboard_file" ]; then
        title=$(jq -r '.dashboard.title // "Unknown Dashboard"' "$dashboard_file")
        echo -n "   📥 Importing '$title'... "
        
        # The payload for the Grafana API requires the dashboard to be nested
        import_payload=$(jq -n --argjson dash_data "$(cat "$dashboard_file")" \
          '{"dashboard": $dash_data.dashboard, "overwrite": true, "folderId": $dash_data.meta.folderId}')
        
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u admin:bankingdemo \
            http://localhost:3000/api/dashboards/db \
            -d "$import_payload")
        
        if echo "$response" | grep -q "success"; then
            echo -e "\033[0;32m✅ SUCCESS\033[0m"
        else
            echo -e "\033[0;31m❌ FAILED\033[0m"
            echo "      Error: $(echo "$response" | jq -r .message)"
        fi
    fi
done
chmod -x "$0"
