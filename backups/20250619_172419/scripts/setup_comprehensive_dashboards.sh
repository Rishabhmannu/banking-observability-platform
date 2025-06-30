#!/bin/bash

echo "📊 Setting Up Comprehensive Grafana Dashboards"
echo "=============================================="
echo "This will create dashboards for:"
echo "1. DDoS ML Detection Monitoring"
echo "2. Auto-Baselining Visualization"
echo "3. Banking System Overview"
echo ""

# Navigate to project directory
cd "/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system" || {
    echo "❌ Could not find project directory"
    exit 1
}

# Create Grafana dashboard directory
mkdir -p grafana/dashboards

echo "🎯 Step 1: Creating DDoS Detection Dashboard"
echo "==========================================="

cat > grafana/dashboards/ddos-detection-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "🚨 DDoS Detection & Security Monitoring",
    "tags": ["ddos", "security", "ml", "detection"],
    "timezone": "browser",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "🚨 DDoS Detection Status",
        "type": "stat",
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "ddos_binary_prediction",
            "refId": "A",
            "legendFormat": "Attack Detected"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "max": 1,
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "red", "value": 1}
              ]
            },
            "mappings": [
              {"type": "value", "value": "0", "text": "🟢 NORMAL"},
              {"type": "value", "value": "1", "text": "🚨 ATTACK"}
            ]
          }
        },
        "options": {
          "colorMode": "background",
          "graphMode": "none",
          "justifyMode": "center",
          "textMode": "auto"
        }
      },
      {
        "id": 2,
        "title": "🎯 Detection Confidence",
        "type": "gauge",
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
        "targets": [
          {
            "expr": "ddos_confidence * 100",
            "refId": "A",
            "legendFormat": "Confidence %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "max": 100,
            "unit": "percent",
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 60},
                {"color": "green", "value": 80}
              ]
            }
          }
        }
      },
      {
        "id": 3,
        "title": "📊 Anomaly Score",
        "type": "stat",
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "ddos_detection_score",
            "refId": "A",
            "legendFormat": "Anomaly Score"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "max": 1,
            "decimals": 3,
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 0.5},
                {"color": "red", "value": 0.8}
              ]
            }
          }
        }
      },
      {
        "id": 4,
        "title": "⚡ Service Performance",
        "type": "stat",
        "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
        "targets": [
          {
            "expr": "rate(ddos_model_predictions_total[5m]) * 60",
            "refId": "A",
            "legendFormat": "Predictions/min"
          },
          {
            "expr": "detection_latency_seconds * 1000",
            "refId": "B",
            "legendFormat": "Latency (ms)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "decimals": 2
          }
        }
      },
      {
        "id": 5,
        "title": "📈 DDoS Detection Timeline",
        "type": "timeseries",
        "gridPos": {"h": 9, "w": 24, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "ddos_detection_score",
            "refId": "A",
            "legendFormat": "Detection Score"
          },
          {
            "expr": "ddos_confidence",
            "refId": "B",
            "legendFormat": "Confidence"
          },
          {
            "expr": "ddos_binary_prediction",
            "refId": "C",
            "legendFormat": "Binary Prediction"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "custom": {
              "drawStyle": "line",
              "lineWidth": 2,
              "fillOpacity": 20
            }
          },
          "overrides": [
            {
              "matcher": {"id": "byName", "options": "Binary Prediction"},
              "properties": [
                {"id": "custom.fillOpacity", "value": 50},
                {"id": "color", "value": {"mode": "fixed", "fixedColor": "red"}},
                {"id": "custom.drawStyle", "value": "bars"}
              ]
            }
          ]
        }
      },
      {
        "id": 6,
        "title": "🏦 Banking System Load",
        "type": "timeseries",
        "gridPos": {"h": 9, "w": 12, "x": 0, "y": 17},
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[1m]))",
            "refId": "A",
            "legendFormat": "Request Rate (req/s)"
          },
          {
            "expr": "sum(rate(http_requests_total{status=~\"5..\"}[1m]))",
            "refId": "B",
            "legendFormat": "Error Rate (errors/s)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "custom": {
              "drawStyle": "line",
              "lineWidth": 1
            }
          },
          "overrides": [
            {
              "matcher": {"id": "byName", "options": "Error Rate (errors/s)"},
              "properties": [
                {"id": "color", "value": {"mode": "fixed", "fixedColor": "red"}}
              ]
            }
          ]
        }
      },
      {
        "id": 7,
        "title": "⏱️ System Response Times",
        "type": "timeseries",
        "gridPos": {"h": 9, "w": 12, "x": 12, "y": 17},
        "targets": [
          {
            "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[1m])) by (le)) * 1000",
            "refId": "A",
            "legendFormat": "50th Percentile (ms)"
          },
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le)) * 1000",
            "refId": "B",
            "legendFormat": "95th Percentile (ms)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "ms",
            "custom": {
              "drawStyle": "line",
              "lineWidth": 1
            }
          }
        }
      }
    ],
    "templating": {
      "list": []
    },
    "annotations": {
      "list": [
        {
          "name": "DDoS Attacks",
          "datasource": "Prometheus",
          "enable": true,
          "expr": "ddos_binary_prediction == 1",
          "iconColor": "red",
          "titleFormat": "DDoS Attack Detected",
          "textFormat": "Score: {{ddos_detection_score}}"
        }
      ]
    }
  }
}
EOF

echo "✅ Created DDoS Detection Dashboard"

echo ""
echo "🎯 Step 2: Creating Auto-Baselining Dashboard"
echo "============================================"

cat > grafana/dashboards/auto-baselining-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "🎯 Auto-Baselining & Threshold Optimization",
    "tags": ["auto-baselining", "thresholds", "ml", "optimization"],
    "timezone": "browser",
    "refresh": "1m",
    "time": {
      "from": "now-2h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "🧠 Algorithm Status",
        "type": "stat",
        "gridPos": {"h": 6, "w": 8, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "active_metrics_being_monitored",
            "refId": "A",
            "legendFormat": "Active Metrics"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 1},
                {"color": "green", "value": 4}
              ]
            }
          }
        }
      },
      {
        "id": 2,
        "title": "📊 Recommendations Generated",
        "type": "stat",
        "gridPos": {"h": 6, "w": 8, "x": 8, "y": 0},
        "targets": [
          {
            "expr": "rate(threshold_recommendations_total[5m]) * 300",
            "refId": "A",
            "legendFormat": "Recommendations/5min"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "decimals": 1,
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 1},
                {"color": "green", "value": 5}
              ]
            }
          }
        }
      },
      {
        "id": 3,
        "title": "⚡ Algorithm Performance",
        "type": "stat",
        "gridPos": {"h": 6, "w": 8, "x": 16, "y": 0},
        "targets": [
          {
            "expr": "avg(algorithm_execution_seconds)",
            "refId": "A",
            "legendFormat": "Avg Execution Time (s)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "decimals": 3,
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 1},
                {"color": "red", "value": 5}
              ]
            }
          }
        }
      },
      {
        "id": 4,
        "title": "📈 Algorithm Execution Times",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 6},
        "targets": [
          {
            "expr": "algorithm_execution_seconds",
            "refId": "A",
            "legendFormat": "{{algorithm}} execution time"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "custom": {
              "drawStyle": "line",
              "lineWidth": 1,
              "fillOpacity": 20
            }
          }
        }
      },
      {
        "id": 5,
        "title": "🎯 Active Metrics Monitoring",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 6},
        "targets": [
          {
            "expr": "active_metrics_being_monitored",
            "refId": "A",
            "legendFormat": "Metrics Being Monitored"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "custom": {
              "drawStyle": "line",
              "lineWidth": 2,
              "fillOpacity": 30
            }
          }
        }
      },
      {
        "id": 6,
        "title": "📊 Banking Metrics vs Thresholds",
        "type": "timeseries",
        "gridPos": {"h": 10, "w": 24, "x": 0, "y": 14},
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[1m]))",
            "refId": "A",
            "legendFormat": "API Request Rate (actual)"
          },
          {
            "expr": "sum(rate(http_requests_total{status=~\"5..\"}[1m]))",
            "refId": "B",
            "legendFormat": "API Error Rate (actual)"
          },
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[1m])) by (le)) * 1000",
            "refId": "C",
            "legendFormat": "Response Time P95 (actual)"
          },
          {
            "expr": "avg(100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[1m])) * 100))",
            "refId": "D",
            "legendFormat": "CPU Usage % (actual)"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "custom": {
              "drawStyle": "line",
              "lineWidth": 1,
              "fillOpacity": 10
            }
          },
          "overrides": [
            {
              "matcher": {"id": "byRegexp", "options": ".*Error.*"},
              "properties": [
                {"id": "color", "value": {"mode": "fixed", "fixedColor": "red"}}
              ]
            }
          ]
        }
      }
    ],
    "templating": {
      "list": []
    }
  }
}
EOF

echo "✅ Created Auto-Baselining Dashboard"

echo ""
echo "🎯 Step 3: Creating Banking System Overview Dashboard"
echo "===================================================="

cat > grafana/dashboards/banking-overview-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "🏦 Banking System Overview",
    "tags": ["banking", "overview", "microservices"],
    "timezone": "browser",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "🏥 Service Health",
        "type": "stat",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "up{job=\"banking-services\"}",
            "refId": "A",
            "legendFormat": "{{instance}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "mappings": [
              {"type": "value", "value": "1", "text": "UP", "color": "green"},
              {"type": "value", "value": "0", "text": "DOWN", "color": "red"}
            ],
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            }
          }
        },
        "options": {
          "colorMode": "background",
          "reduceOptions": {
            "calcs": ["lastNotNull"]
          }
        }
      },
      {
        "id": 2,
        "title": "📊 Request Rates by Service",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "rate(http_requests_total[1m])",
            "refId": "A",
            "legendFormat": "{{instance}} - {{method}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps",
            "custom": {
              "drawStyle": "line",
              "lineWidth": 1
            }
          }
        }
      },
      {
        "id": 3,
        "title": "⚠️ Error Rates by Service",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"4..|5..\"}[1m])",
            "refId": "A",
            "legendFormat": "{{instance}} - {{status}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps",
            "custom": {
              "drawStyle": "line",
              "lineWidth": 1
            },
            "color": {
              "mode": "palette-classic"
            }
          }
        }
      }
    ]
  }
}
EOF

echo "✅ Created Banking Overview Dashboard"

echo ""
echo "🎯 Step 4: Setting up Dashboard Provisioning"
echo "============================================"

# Update Grafana dashboard provisioning config
cat > grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'DDoS Detection Dashboards'
    orgId: 1
    folder: 'Security'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards

  - name: 'Auto-Baselining Dashboards'
    orgId: 1
    folder: 'ML & Analytics'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards

  - name: 'Banking Dashboards'
    orgId: 1
    folder: 'Banking Operations'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

echo "✅ Updated dashboard provisioning"

echo ""
echo "🔄 Step 5: Restarting Grafana to Load Dashboards"
echo "================================================"

# Copy dashboards to the container volume and restart
echo "📁 Setting up dashboard files..."

# Restart Grafana to pick up new dashboards
docker compose restart grafana

echo "⏳ Waiting for Grafana to restart and load dashboards (45 seconds)..."
sleep 45

echo ""
echo "🧪 Testing Dashboard Access"
echo "=========================="

echo -n "Grafana health: "
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo "✅ UP"
else
    echo "❌ Down"
fi

echo -n "Dashboard API access: "
if curl -s -u admin:bankingdemo http://localhost:3000/api/dashboards/home >/dev/null; then
    echo "✅ Accessible"
else
    echo "❌ Authentication issue"
fi

echo ""
echo "🎉 Dashboard Setup Complete!"
echo "============================"

echo ""
echo "📊 Your new Grafana dashboards:"
echo "• 🚨 DDoS Detection & Security Monitoring"
echo "• 🎯 Auto-Baselining & Threshold Optimization" 
echo "• 🏦 Banking System Overview"

echo ""
echo "🔗 Access Instructions:"
echo "======================"
echo "1. Go to: http://localhost:3000"
echo "2. Login: admin / bankingdemo"
echo "3. Navigate to 'Dashboards' → 'Browse'"
echo "4. Your dashboards should be organized in folders:"
echo "   - Security (DDoS Detection)"
echo "   - ML & Analytics (Auto-Baselining)"
echo "   - Banking Operations (System Overview)"

echo ""
echo "🔧 If dashboards don't appear automatically:"
echo "==========================================="
echo "1. Go to Settings (⚙️) → Data Sources"
echo "2. Verify Prometheus is connected: http://prometheus:9090"
echo "3. Go to Dashboards → Browse → Import"
echo "4. Import the JSON files from: grafana/dashboards/"

echo ""
echo "✨ All dashboards are now ready for visualization!"