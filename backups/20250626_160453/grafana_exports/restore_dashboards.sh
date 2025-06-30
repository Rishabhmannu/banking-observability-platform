#!/bin/bash
echo "🔄 Restoring Grafana Dashboards"
echo "=============================="

for dashboard in *_complete.json; do
    if [ -f "$dashboard" ]; then
        title=$(jq -r '.title // "Unknown"' "$dashboard")
        echo -n "📊 Importing $title... "
        
        # Prepare import payload
        dashboard_data=$(cat "$dashboard")
        import_payload=$(jq -n --argjson dash "$dashboard_data" '{"dashboard": $dash, "overwrite": true, "inputs": [], "folderId": 0}')
        
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u admin:bankingdemo \
            http://localhost:3000/api/dashboards/db \
            -d "$import_payload")
        
        if echo "$response" | grep -q "success"; then
            echo "✅"
        else
            echo "❌"
        fi
    fi
done
