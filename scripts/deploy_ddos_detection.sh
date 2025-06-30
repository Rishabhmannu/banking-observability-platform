#!/bin/bash
# scripts/deploy_ddos_detection.sh

echo "Deploying DDoS Detection System..."

# Create necessary directories
mkdir - p data/models
mkdir - p logs
mkdir - p config

# Start Prometheus with custom config
echo "Starting Prometheus..."
prometheus - -config.file = config/prometheus.yml - -storage.tsdb.path = /tmp/prometheus &
PROMETHEUS_PID = $!

# Start Grafana
echo "Starting Grafana..."
grafana-server - -homepath / usr/local/share/grafana - -config config/grafana.ini &
GRAFANA_PID = $!

# Wait for services to start
sleep 10

# Train models if they don't exist
if [! -f "data/models/isolation_forest.pkl"]
then
echo "Training DDoS detection models..."
python scripts/train_models.py
fi

# Start ML Detection Service
echo "Starting ML Detection Service..."
python src/services/ml_detection_service.py &
ML_SERVICE_PID = $!

# Start your banking services (from your existing setup)
echo "Starting banking microservices..."
cd ~/banking-demo
docker compose up - d

echo "All services started!"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000"
echo "ML Detection Service: http://localhost:9090"
echo "Banking API: http://localhost:8080"

# Save PIDs for cleanup
echo $PROMETHEUS_PID > /tmp/prometheus.pid
echo $GRAFANA_PID > /tmp/grafana.pid
echo $ML_SERVICE_PID > /tmp/ml_service.pid

echo "Deployment complete!"
