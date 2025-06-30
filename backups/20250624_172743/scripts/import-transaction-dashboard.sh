#!/bin/bash

echo "🔧 Manual Transaction Dashboard Import"
echo "====================================="

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
while ! curl -s http://localhost:3000/api/health | grep -q "ok"; do
    echo "Waiting for Grafana..."
    sleep 5
done

echo "✅ Grafana is ready"

# First, we need to ensure the dashboard directory exists
mkdir -p grafana/dashboards

# Create the properly formatted dashboard JSON for API import
echo ""
echo "📊 Preparing Transaction Performance Dashboard..."

# Create a temporary file with the proper API format
cat > /tmp/transaction-dashboard-import.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "uid": null,
    "title": "💰 Transaction Performance Monitoring",
    "tags": ["transactions", "performance", "banking", "slo"],
    "timezone": "browser",
    "schemaVersion": 16,
    "version": 0,
    "refresh": "10s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "gridPos": {"h": 6, "w": 6, "x": 0, "y": 0},
        "type": "stat",
        "title": "📊 Request Count",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "sum(rate(transaction_requests_total[5m])) * 60",
            "refId": "A",
            "legendFormat": "Requests/min"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "decimals": 0,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "red", "value": null},
                {"color": "yellow", "value": 50},
                {"color": "green", "value": 100}
              ]
            },
            "unit": "reqpm",
            "mappings": []
          },
          "overrides": []
        },
        "options": {
          "colorMode": "background",
          "graphMode": "area",
          "justifyMode": "center",
          "orientation": "auto",
          "reduceOptions": {
            "values": false,
            "fields": "",
            "calcs": ["lastNotNull"]
          },
          "textMode": "auto"
        },
        "pluginVersion": "7.0.0"
      },
      {
        "id": 2,
        "gridPos": {"h": 6, "w": 6, "x": 6, "y": 0},
        "type": "stat",
        "title": "❌ Request Failures",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "(sum(rate(transaction_failures_total[5m])) / sum(rate(transaction_requests_total[5m]))) * 100",
            "refId": "A",
            "legendFormat": "Failure Rate %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "decimals": 2,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 1},
                {"color": "red", "value": 5}
              ]
            },
            "unit": "percent",
            "max": 100,
            "mappings": []
          },
          "overrides": []
        },
        "options": {
          "colorMode": "background",
          "graphMode": "area",
          "justifyMode": "center",
          "orientation": "auto",
          "reduceOptions": {
            "values": false,
            "fields": "",
            "calcs": ["lastNotNull"]
          },
          "textMode": "auto"
        },
        "pluginVersion": "7.0.0"
      },
      {
        "id": 3,
        "gridPos": {"h": 6, "w": 6, "x": 12, "y": 0},
        "type": "stat",
        "title": "⏱️ Avg Response Time",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "avg(transaction_avg_response_time) * 1000",
            "refId": "A",
            "legendFormat": "Avg Response Time"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "decimals": 0,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 500},
                {"color": "red", "value": 1000}
              ]
            },
            "unit": "ms",
            "mappings": []
          },
          "overrides": []
        },
        "options": {
          "colorMode": "background",
          "graphMode": "area",
          "justifyMode": "center",
          "orientation": "auto",
          "reduceOptions": {
            "values": false,
            "fields": "",
            "calcs": ["lastNotNull"]
          },
          "textMode": "auto"
        },
        "pluginVersion": "7.0.0"
      },
      {
        "id": 4,
        "gridPos": {"h": 6, "w": 6, "x": 18, "y": 0},
        "type": "stat",
        "title": "🐌 Slow Requests %",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "slow_transaction_percentage{threshold=\"0.5s\"}",
            "refId": "A",
            "legendFormat": "Slow (>500ms)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "decimals": 1,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 5},
                {"color": "red", "value": 10}
              ]
            },
            "unit": "percent",
            "max": 100,
            "mappings": []
          },
          "overrides": []
        },
        "options": {
          "colorMode": "background",
          "graphMode": "area",
          "justifyMode": "center",
          "orientation": "auto",
          "reduceOptions": {
            "values": false,
            "fields": "",
            "calcs": ["lastNotNull"]
          },
          "textMode": "auto"
        },
        "pluginVersion": "7.0.0"
      },
      {
        "id": 5,
        "gridPos": {"h": 10, "w": 12, "x": 0, "y": 6},
        "type": "graph",
        "title": "📈 Request Count by Transaction Type",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "sum by(type) (rate(transaction_requests_total[1m])) * 60",
            "refId": "A",
            "legendFormat": "{{type}}"
          }
        ],
        "xaxis": {
          "buckets": null,
          "mode": "time",
          "name": null,
          "show": true,
          "values": []
        },
        "yaxes": [
          {
            "format": "reqpm",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": true
          },
          {
            "format": "short",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": false
          }
        ],
        "yaxis": {
          "align": false,
          "alignLevel": null
        },
        "lines": true,
        "fill": 2,
        "linewidth": 2,
        "stack": true,
        "nullPointMode": "null",
        "percentage": false,
        "pointradius": 2,
        "points": false,
        "renderer": "flot",
        "seriesOverrides": [],
        "spaceLength": 10,
        "steppedLine": false,
        "thresholds": [],
        "timeFrom": null,
        "timeRegions": [],
        "timeShift": null,
        "tooltip": {
          "shared": true,
          "sort": 0,
          "value_type": "individual"
        },
        "aliasColors": {},
        "bars": false,
        "dashLength": 10,
        "dashes": false,
        "fillGradient": 0,
        "hiddenSeries": false,
        "legend": {
          "avg": false,
          "current": false,
          "max": false,
          "min": false,
          "show": true,
          "total": false,
          "values": false
        }
      },
      {
        "id": 6,
        "gridPos": {"h": 10, "w": 12, "x": 12, "y": 6},
        "type": "graph",
        "title": "📉 Failure Rate Over Time",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "(sum(rate(transaction_failures_total[1m])) / sum(rate(transaction_requests_total[1m]))) * 100",
            "refId": "A",
            "legendFormat": "Overall Failure Rate"
          }
        ],
        "xaxis": {
          "buckets": null,
          "mode": "time",
          "name": null,
          "show": true,
          "values": []
        },
        "yaxes": [
          {
            "format": "percent",
            "label": null,
            "logBase": 1,
            "max": 100,
            "min": 0,
            "show": true
          },
          {
            "format": "short",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": false
          }
        ],
        "yaxis": {
          "align": false,
          "alignLevel": null
        },
        "lines": true,
        "fill": 1,
        "linewidth": 3,
        "nullPointMode": "null",
        "percentage": false,
        "pointradius": 2,
        "points": false,
        "renderer": "flot",
        "seriesOverrides": [
          {
            "alias": "Overall Failure Rate",
            "color": "#FF0000"
          }
        ],
        "spaceLength": 10,
        "stack": false,
        "steppedLine": false,
        "thresholds": [],
        "timeFrom": null,
        "timeRegions": [],
        "timeShift": null,
        "tooltip": {
          "shared": true,
          "sort": 0,
          "value_type": "individual"
        },
        "aliasColors": {},
        "bars": false,
        "dashLength": 10,
        "dashes": false,
        "fillGradient": 0,
        "hiddenSeries": false,
        "legend": {
          "avg": false,
          "current": false,
          "max": false,
          "min": false,
          "show": true,
          "total": false,
          "values": false
        }
      },
      {
        "id": 7,
        "gridPos": {"h": 10, "w": 12, "x": 0, "y": 16},
        "type": "graph",
        "title": "⏱️ Response Time Percentiles",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "histogram_quantile(0.50, sum(rate(transaction_duration_seconds_bucket[1m])) by (le)) * 1000",
            "refId": "A",
            "legendFormat": "p50"
          },
          {
            "expr": "histogram_quantile(0.95, sum(rate(transaction_duration_seconds_bucket[1m])) by (le)) * 1000",
            "refId": "B",
            "legendFormat": "p95"
          },
          {
            "expr": "histogram_quantile(0.99, sum(rate(transaction_duration_seconds_bucket[1m])) by (le)) * 1000",
            "refId": "C",
            "legendFormat": "p99"
          }
        ],
        "xaxis": {
          "buckets": null,
          "mode": "time",
          "name": null,
          "show": true,
          "values": []
        },
        "yaxes": [
          {
            "format": "ms",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": true
          },
          {
            "format": "short",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": false
          }
        ],
        "yaxis": {
          "align": false,
          "alignLevel": null
        },
        "lines": true,
        "fill": 1,
        "linewidth": 2,
        "nullPointMode": "null",
        "percentage": false,
        "pointradius": 2,
        "points": false,
        "renderer": "flot",
        "seriesOverrides": [],
        "spaceLength": 10,
        "stack": false,
        "steppedLine": false,
        "thresholds": [],
        "timeFrom": null,
        "timeRegions": [],
        "timeShift": null,
        "tooltip": {
          "shared": true,
          "sort": 0,
          "value_type": "individual"
        },
        "aliasColors": {},
        "bars": false,
        "dashLength": 10,
        "dashes": false,
        "fillGradient": 0,
        "hiddenSeries": false,
        "legend": {
          "avg": false,
          "current": false,
          "max": false,
          "min": false,
          "show": true,
          "total": false,
          "values": false
        }
      },
      {
        "id": 8,
        "gridPos": {"h": 10, "w": 12, "x": 12, "y": 16},
        "type": "graph",
        "title": "🐌 Slow Request Trend",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "slow_transaction_percentage",
            "refId": "A",
            "legendFormat": "{{threshold}}"
          }
        ],
        "xaxis": {
          "buckets": null,
          "mode": "time",
          "name": null,
          "show": true,
          "values": []
        },
        "yaxes": [
          {
            "format": "percent",
            "label": null,
            "logBase": 1,
            "max": 100,
            "min": 0,
            "show": true
          },
          {
            "format": "short",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": false
          }
        ],
        "yaxis": {
          "align": false,
          "alignLevel": null
        },
        "lines": true,
        "fill": 2,
        "linewidth": 2,
        "nullPointMode": "null",
        "percentage": false,
        "pointradius": 2,
        "points": false,
        "renderer": "flot",
        "seriesOverrides": [],
        "spaceLength": 10,
        "stack": false,
        "steppedLine": false,
        "thresholds": [],
        "timeFrom": null,
        "timeRegions": [],
        "timeShift": null,
        "tooltip": {
          "shared": true,
          "sort": 0,
          "value_type": "individual"
        },
        "aliasColors": {},
        "bars": false,
        "dashLength": 10,
        "dashes": false,
        "fillGradient": 0,
        "hiddenSeries": false,
        "legend": {
          "avg": false,
          "current": false,
          "max": false,
          "min": false,
          "show": true,
          "total": false,
          "values": false
        }
      },
      {
        "id": 9,
        "gridPos": {"h": 8, "w": 8, "x": 0, "y": 26},
        "type": "piechart",
        "title": "🍕 Transaction Type Distribution",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "sum by(type) (increase(transaction_requests_total[1h]))",
            "refId": "A",
            "legendFormat": "{{type}}"
          }
        ],
        "pieType": "donut",
        "options": {
          "pieType": "donut",
          "displayLabels": ["name", "percent"],
          "legendDisplayMode": "list",
          "legendPlacement": "right",
          "legendShowPercentage": true,
          "legendValues": [],
          "reduceOptions": {
            "values": false,
            "fields": "",
            "calcs": ["lastNotNull"]
          },
          "tooltipDisplayMode": "single"
        },
        "pluginVersion": "7.0.0"
      },
      {
        "id": 10,
        "gridPos": {"h": 8, "w": 8, "x": 8, "y": 26},
        "type": "bargauge",
        "title": "📊 Error Code Distribution",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "sum by(error_code) (increase(transaction_failures_total[1h]))",
            "refId": "A",
            "legendFormat": "{{error_code}}"
          }
        ],
        "options": {
          "displayMode": "gradient",
          "orientation": "horizontal",
          "showUnfilled": true,
          "reduceOptions": {
            "values": false,
            "fields": "",
            "calcs": ["lastNotNull"]
          }
        },
        "pluginVersion": "7.0.0",
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": null, "color": "green"},
                {"value": 10, "color": "yellow"},
                {"value": 50, "color": "red"}
              ]
            },
            "mappings": [],
            "unit": "short"
          },
          "overrides": []
        }
      },
      {
        "id": 11,
        "gridPos": {"h": 8, "w": 8, "x": 16, "y": 26},
        "type": "gauge",
        "title": "🎯 SLO Compliance",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "avg(slo_compliance_percentage)",
            "refId": "A",
            "legendFormat": "Overall SLO"
          }
        ],
        "options": {
          "showThresholdLabels": false,
          "showThresholdMarkers": true,
          "reduceOptions": {
            "values": false,
            "fields": "",
            "calcs": ["lastNotNull"]
          }
        },
        "pluginVersion": "7.0.0",
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "max": 100,
            "unit": "percent",
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": null, "color": "red"},
                {"value": 95, "color": "yellow"},
                {"value": 99, "color": "green"}
              ]
            },
            "mappings": []
          },
          "overrides": []
        }
      },
      {
        "id": 12,
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 34},
        "type": "graph",
        "title": "🎭 Anomaly Detection",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "transaction_anomaly_score",
            "refId": "A",
            "legendFormat": "Anomaly Score"
          },
          {
            "expr": "active_anomalies",
            "refId": "B",
            "legendFormat": "Active Injections ({{type}})"
          }
        ],
        "xaxis": {
          "buckets": null,
          "mode": "time",
          "name": null,
          "show": true,
          "values": []
        },
        "yaxes": [
          {
            "format": "short",
            "label": null,
            "logBase": 1,
            "max": 1,
            "min": 0,
            "show": true
          },
          {
            "format": "short",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": false
          }
        ],
        "yaxis": {
          "align": false,
          "alignLevel": null
        },
        "lines": true,
        "fill": 2,
        "linewidth": 2,
        "nullPointMode": "null",
        "percentage": false,
        "pointradius": 2,
        "points": false,
        "renderer": "flot",
        "seriesOverrides": [
          {
            "alias": "/Active.*/",
            "bars": true,
            "lines": false,
            "fill": 5,
            "color": "#800080"
          }
        ],
        "spaceLength": 10,
        "stack": false,
        "steppedLine": false,
        "thresholds": [],
        "timeFrom": null,
        "timeRegions": [],
        "timeShift": null,
        "tooltip": {
          "shared": true,
          "sort": 0,
          "value_type": "individual"
        },
        "aliasColors": {},
        "bars": false,
        "dashLength": 10,
        "dashes": false,
        "fillGradient": 0,
        "hiddenSeries": false,
        "legend": {
          "avg": false,
          "current": false,
          "max": false,
          "min": false,
          "show": true,
          "total": false,
          "values": false
        }
      },
      {
        "id": 13,
        "gridPos": {"h": 6, "w": 12, "x": 0, "y": 42},
        "type": "stat",
        "title": "💼 Business vs Off-Hours Performance",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "business_hour_transaction_rate",
            "refId": "A",
            "legendFormat": "Business Hours"
          },
          {
            "expr": "off_hour_transaction_rate",
            "refId": "B",
            "legendFormat": "Off Hours"
          }
        ],
        "options": {
          "colorMode": "value",
          "graphMode": "none",
          "justifyMode": "center",
          "orientation": "auto",
          "reduceOptions": {
            "values": false,
            "fields": "",
            "calcs": ["lastNotNull"]
          },
          "textMode": "auto"
        },
        "pluginVersion": "7.0.0",
        "fieldConfig": {
          "defaults": {
            "unit": "reqpm",
            "decimals": 0,
            "mappings": []
          },
          "overrides": []
        }
      },
      {
        "id": 14,
        "gridPos": {"h": 6, "w": 12, "x": 12, "y": 42},
        "type": "graph",
        "title": "📈 Performance Score",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "transaction_performance_score",
            "refId": "A",
            "legendFormat": "{{category}}"
          }
        ],
        "xaxis": {
          "buckets": null,
          "mode": "time",
          "name": null,
          "show": true,
          "values": []
        },
        "yaxes": [
          {
            "format": "percent",
            "label": null,
            "logBase": 1,
            "max": 100,
            "min": 0,
            "show": true
          },
          {
            "format": "short",
            "label": null,
            "logBase": 1,
            "max": null,
            "min": null,
            "show": false
          }
        ],
        "yaxis": {
          "align": false,
          "alignLevel": null
        },
        "lines": true,
        "fill": 1,
        "linewidth": 2,
        "nullPointMode": "null",
        "percentage": false,
        "pointradius": 2,
        "points": false,
        "renderer": "flot",
        "seriesOverrides": [],
        "spaceLength": 10,
        "stack": false,
        "steppedLine": false,
        "thresholds": [],
        "timeFrom": null,
        "timeRegions": [],
        "timeShift": null,
        "tooltip": {
          "shared": true,
          "sort": 0,
          "value_type": "individual"
        },
        "aliasColors": {},
        "bars": false,
        "dashLength": 10,
        "dashes": false,
        "fillGradient": 0,
        "hiddenSeries": false,
        "legend": {
          "avg": false,
          "current": false,
          "max": false,
          "min": false,
          "show": true,
          "total": false,
          "values": false
        }
      }
    ],
    "annotations": {
      "list": [
        {
          "builtIn": 1,
          "datasource": "-- Grafana --",
          "enable": true,
          "hide": true,
          "iconColor": "rgba(0, 211, 255, 1)",
          "name": "Annotations & Alerts",
          "type": "dashboard"
        }
      ]
    },
    "editable": true,
    "gnetId": null,
    "graphTooltip": 0,
    "iteration": 1234567890,
    "links": [],
    "style": "dark",
    "templating": {
      "list": []
    },
    "timepicker": {
      "refresh_intervals": ["5s", "10s", "30s", "1m", "5m", "15m", "30m", "1h", "2h", "1d"],
      "time_options": ["5m", "15m", "1h", "6h", "12h", "24h", "2d", "7d", "30d"]
    }
  },
  "overwrite": true,
  "folderId": 0
}
EOF

echo ""
echo "📊 Importing Transaction Performance Dashboard..."

# Import the dashboard
response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u admin:bankingdemo \
  http://localhost:3000/api/dashboards/db \
  -d @/tmp/transaction-dashboard-import.json)

if echo "$response" | grep -q "success"; then
    echo "✅ Transaction Performance Dashboard imported successfully"
    dashboard_url=$(echo "$response" | jq -r '.url // "N/A"')
    dashboard_uid=$(echo "$response" | jq -r '.uid // "N/A"')
    echo "   📍 URL: http://localhost:3000$dashboard_url"
    echo "   🔑 UID: $dashboard_uid"
    
    # Save the dashboard URL for reference
    echo "http://localhost:3000$dashboard_url" > transaction-dashboard-url.txt
else
    echo "❌ Failed to import Transaction Performance Dashboard"
    echo "   Error: $response"
    echo ""
    echo "🔍 Debugging info:"
    echo "   - Check if Grafana is running: curl http://localhost:3000/api/health"
    echo "   - Check credentials (should be admin/bankingdemo)"
    echo "   - Raw response: $response"
fi

# Clean up
rm -f /tmp/transaction-dashboard-import.json

echo ""
echo "📋 Dashboard Import Summary:"
echo "==========================="
if [ ! -z "$dashboard_url" ] && [ "$dashboard_url" != "N/A" ]; then
    echo "✅ Transaction Performance: http://localhost:3000$dashboard_url"
    echo ""
    echo "🎯 Next Steps:"
    echo "============="
    echo "1. Click the dashboard URL above"
    echo "2. The dashboard should show all metrics"
    echo "3. If some panels show 'No Data':"
    echo "   - Wait 1-2 minutes for metrics to accumulate"
    echo "   - Run: ./simulate-realistic-traffic.sh"
    echo "   - Check time range (top right) is set to 'Last 1 hour'"
    echo "4. To test anomaly detection:"
    echo "   - Run: ./test-anomaly-injection.sh"
else
    echo "❌ Import failed - check error messages above"
fi

echo ""
echo "✨ Import script complete!"