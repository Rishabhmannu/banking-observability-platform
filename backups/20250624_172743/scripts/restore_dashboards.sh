#!/bin/bash

echo "📊 Grafana Dashboard Restoration Script"
echo "======================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="bankingdemo"
PROJECT_DIR="/Users/rishabh/Downloads/Internship Related/DDoS_Detection/ddos-detection-system"

cd "$PROJECT_DIR" || {
    echo -e "${RED}❌ Could not find project directory${NC}"
    exit 1
}

echo "📂 Working from: $(pwd)"
echo "📅 Restoration started at: $(date)"

echo ""
echo -e "${BLUE}🔍 Step 1: Verify Grafana is Running${NC}"
echo "===================================="

# Wait for Grafana to be ready
echo "Checking Grafana availability..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -s "$GRAFANA_URL/api/health" >/dev/null 2>&1; then
        echo -e "✅ ${GREEN}Grafana is running${NC}"
        break
    else
        echo "⏳ Waiting for Grafana... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    fi
done

if [ $attempt -gt $max_attempts ]; then
    echo -e "${RED}❌ Grafana is not responding after 2.5 minutes${NC}"
    echo "Please ensure Grafana is running: docker compose ps"
    exit 1
fi

echo ""
echo -e "${BLUE}📁 Step 2: Find Latest Backup${NC}"
echo "============================="

# Find the most recent backup
if [ ! -d "backups" ]; then
    echo -e "${RED}❌ No backups directory found${NC}"
    exit 1
fi

latest_backup=$(ls -t backups/ | head -1)
if [ -z "$latest_backup" ]; then
    echo -e "${RED}❌ No backups found${NC}"
    exit 1
fi

echo "📁 Using backup: $latest_backup"
backup_path="backups/$latest_backup"

echo ""
echo -e "${BLUE}🔧 Step 3: Create Dashboard Files${NC}"
echo "=================================="

# Create grafana directories
mkdir -p grafana/dashboards
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/provisioning/datasources

echo "📂 Created Grafana directory structure"

# Create the dashboard files
echo ""
echo "📄 Creating dashboard files..."

# 1. Auto-Baselining Dashboard
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
            "expr": "baselining_calculations_total",
            "refId": "A",
            "legendFormat": "Total Calculations"
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
                {"color": "green", "value": 10}
              ]
            }
          }
        }
      },
      {
        "id": 2,
        "title": "📊 Threshold Recommendations",
        "type": "stat",
        "gridPos": {"h": 6, "w": 8, "x": 8, "y": 0},
        "targets": [
          {
            "expr": "threshold_recommendations",
            "refId": "A",
            "legendFormat": "{{metric}} - {{algorithm}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "decimals": 2,
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
        "title": "⚡ Algorithm Confidence",
        "type": "stat",
        "gridPos": {"h": 6, "w": 8, "x": 16, "y": 0},
        "targets": [
          {
            "expr": "threshold_confidence",
            "refId": "A",
            "legendFormat": "{{metric}} - {{algorithm}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percentunit",
            "decimals": 2,
            "min": 0,
            "max": 1,
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 0.5},
                {"color": "green", "value": 0.8}
              ]
            }
          }
        }
      },
      {
        "id": 4,
        "title": "📈 Threshold Recommendations Over Time",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 6},
        "targets": [
          {
            "expr": "threshold_recommendations",
            "refId": "A",
            "legendFormat": "{{metric}} - {{algorithm}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
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

echo "  ✅ Auto-Baselining dashboard created"

# 2. Banking Overview Dashboard
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

echo "  ✅ Banking Overview dashboard created"

# 3. DDoS Detection Dashboard
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
        "title": "📊 System Load Monitoring",
        "type": "timeseries",
        "gridPos": {"h": 9, "w": 24, "x": 0, "y": 8},
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
          "titleFormat": "DDoS Attack Detected"
        }
      ]
    }
  }
}
EOF

echo "  ✅ DDoS Detection dashboard created"

echo ""
echo -e "${BLUE}⚙️ Step 4: Create Provisioning Configuration${NC}"
echo "=============================================="

# Create datasource configuration
cat > grafana/provisioning/datasources/datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

echo "  ✅ Datasource configuration created"

# Create dashboard provisioning configuration
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

echo "  ✅ Dashboard provisioning configuration created"

echo ""
echo -e "${BLUE}📤 Step 5: Import Dashboards via API${NC}"
echo "====================================="

# Function to import dashboard
import_dashboard() {
    local dashboard_file="$1"
    local dashboard_name="$2"
    
    echo "📊 Importing $dashboard_name..."
    
    # Prepare the dashboard JSON for import
    dashboard_json=$(cat "$dashboard_file")
    
    # Create the import payload
    import_payload=$(cat << EOF
{
  "dashboard": $dashboard_json,
  "overwrite": true,
  "inputs": [],
  "folderId": 0
}
EOF
)
    
    # Import the dashboard
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -d "$import_payload" \
        "$GRAFANA_URL/api/dashboards/db")
    
    if echo "$response" | grep -q '"status":"success"'; then
        echo -e "  ✅ ${GREEN}$dashboard_name imported successfully${NC}"
        
        # Extract dashboard URL
        dashboard_url=$(echo "$response" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        if [ ! -z "$dashboard_url" ]; then
            echo "     🔗 Access at: $GRAFANA_URL$dashboard_url"
        fi
    else
        echo -e "  ⚠️  ${YELLOW}$dashboard_name import may have issues${NC}"
        echo "     Response: $response"
    fi
}

# Import all dashboards
import_dashboard "grafana/dashboards/auto-baselining-dashboard.json" "Auto-Baselining Dashboard"
import_dashboard "grafana/dashboards/banking-overview-dashboard.json" "Banking Overview Dashboard"
import_dashboard "grafana/dashboards/ddos-detection-dashboard.json" "DDoS Detection Dashboard"

echo ""
echo -e "${BLUE}🔄 Step 6: Restart Grafana to Apply Provisioning${NC}"
echo "==============================================="

echo "Restarting Grafana container..."
docker compose restart grafana

echo "⏳ Waiting for Grafana to restart..."
sleep 30

# Verify Grafana is back up
attempt=1
max_attempts=12
while [ $attempt -le $max_attempts ]; do
    if curl -s "$GRAFANA_URL/api/health" >/dev/null 2>&1; then
        echo -e "✅ ${GREEN}Grafana is back online${NC}"
        break
    else
        echo "⏳ Waiting for Grafana... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    fi
done

echo ""
echo -e "${BLUE}🔍 Step 7: Verify Dashboard Import${NC}"
echo "================================="

echo "📋 Getting list of imported dashboards..."
dashboards_response=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/search?type=dash-db")

if echo "$dashboards_response" | grep -q "Auto-Baselining"; then
    echo -e "  ✅ ${GREEN}Auto-Baselining dashboard found${NC}"
else
    echo -e "  ⚠️  ${YELLOW}Auto-Baselining dashboard not found${NC}"
fi

if echo "$dashboards_response" | grep -q "Banking System"; then
    echo -e "  ✅ ${GREEN}Banking System dashboard found${NC}"
else
    echo -e "  ⚠️  ${YELLOW}Banking System dashboard not found${NC}"
fi

if echo "$dashboards_response" | grep -q "DDoS Detection"; then
    echo -e "  ✅ ${GREEN}DDoS Detection dashboard found${NC}"
else
    echo -e "  ⚠️  ${YELLOW}DDoS Detection dashboard not found${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Dashboard Restoration Complete!${NC}"
echo ""
echo -e "${BLUE}🌐 Access Your Dashboards:${NC}"
echo "=========================="
echo "🏠 Grafana Home: $GRAFANA_URL"
echo "👤 Login: $GRAFANA_USER / $GRAFANA_PASS"
echo ""
echo "📊 Direct Dashboard Links:"
echo "• 🎯 Auto-Baselining: $GRAFANA_URL/dashboards"
echo "• 🏦 Banking Overview: $GRAFANA_URL/dashboards"  
echo "• 🚨 DDoS Detection: $GRAFANA_URL/dashboards"
echo ""
echo -e "${BLUE}🔧 Troubleshooting:${NC}"
echo "==================="
echo "# If dashboards don't appear, check Grafana logs:"
echo "docker compose logs grafana"
echo ""
echo "# Restart Grafana if needed:"
echo "docker compose restart grafana"
echo ""
echo "# Manual import via UI:"
echo "Go to $GRAFANA_URL/dashboard/import"

echo ""
echo -e "${GREEN}✅ All dashboards should now be available in Grafana!${NC}"