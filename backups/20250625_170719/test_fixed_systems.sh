#!/bin/bash

echo "🚀 Testing Fixed DDoS Detection System"
echo "====================================="

# Make sure we're in the right directory
echo "Current directory: $(pwd)"

# Check if all required files exist
echo "Checking required files..."
files_to_check=(
    "Dockerfile.ml-service"
    "requirements-ml.txt"
    "docker-compose-fixed.yml"
    "grafana/datasources/datasource.yml"
    "grafana/dashboards/dashboard.yml"
    "minimal_ml_service.py"
)

missing_files=()
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ Found: $file"
    else
        echo "  ❌ Missing: $file"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo "❌ Please create the missing files first!"
    exit 1
fi

# Start the system with the fixed compose file
echo "🏗️ Starting system with fixed configuration..."
docker compose -f docker-compose-fixed.yml up -d --build

echo "⏳ Waiting 90 seconds for services to start..."
sleep 90

# Test the services
echo "🧪 Testing services..."

services_to_test=(
    "Banking API:http://localhost:8080/health"
    "ML Detection:http://localhost:5001/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Grafana:http://localhost:3000/api/health"
)

all_healthy=true
for service_info in "${services_to_test[@]}"; do
    service_name=$(echo $service_info | cut -d: -f1)
    service_url=$(echo $service_info | cut -d: -f2-)
    
    if curl -s "$service_url" > /dev/null 2>&1; then
        echo "  ✅ $service_name: HEALTHY"
    else
        echo "  ❌ $service_name: NOT RESPONDING"
        all_healthy=false
    fi
done

# Show container status
echo ""
echo "🐳 Container Status:"
docker compose -f docker-compose-fixed.yml ps

if [ "$all_healthy" = true ]; then
    echo ""
    echo "🎉 SUCCESS! All services are running!"
    echo ""
    echo "🔗 Access URLs:"
    echo "• Banking API: http://localhost:8080/health"
    echo "• ML Detection: http://localhost:5001/health"
    echo "• Prometheus: http://localhost:9090"
    echo "• Grafana: http://localhost:3000 (admin/admin)"
else
    echo ""
    echo "⚠️ Some services are not responding. Check the logs:"
    echo "docker compose -f docker-compose-fixed.yml logs [service-name]"
fi