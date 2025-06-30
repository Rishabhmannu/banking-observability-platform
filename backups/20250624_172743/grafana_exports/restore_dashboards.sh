#!/bin/bash
echo "🔄 Restoring Grafana dashboards..."
for file in *_complete.json; do
    if [ -f "$file" ]; then
        echo -n "Restoring dashboard from '$file'... "
        dashboard_data=$(cat "$file")
        import_payload=$(jq -n --argjson dash "$dashboard_data" '{"dashboard": $dash.dashboard, "overwrite": true, "folderId": $dash.meta.folderId}')
        
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u admin:bankingdemo \
            http://localhost:3000/api/dashboards/db \
            -d "$import_payload")
        
        if echo "$response" | grep -q "success"; then
            echo "✅"
        else
            echo "❌ - Check Grafana logs for details."
        fi
    fi
done
echo "✅ Restore process finished."
