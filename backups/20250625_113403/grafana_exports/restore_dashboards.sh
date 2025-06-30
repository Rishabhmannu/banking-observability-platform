#!/bin/bash
echo "🔄 Restoring Grafana dashboards..."
for file in *_complete.json; do
    if [ -f "$file" ]; then
        uid=$(basename "$file" _complete.json)
        echo -n "Restoring dashboard $uid... "
        
        dashboard_data=$(cat "$file" | jq '.dashboard')
        import_payload=$(jq -n --argjson dash "$dashboard_data" '{"dashboard": $dash, "overwrite": true, "inputs": [], "folderId": 0}')
        
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -u admin:bankingdemo \
            -d "$import_payload" \
            http://localhost:3000/api/dashboards/import)
        
        if echo "$response" | grep -q "success"; then
            echo "✅"
        else
            echo "❌"
            echo "Error: $response"
        fi
    fi
done
echo "✅ Dashboard restoration complete!"
