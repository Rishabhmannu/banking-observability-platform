#!/bin/bash

echo "🔧 Creating all required configuration files..."

# Create Dockerfile.ml-service
cat > Dockerfile.ml-service << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements-ml.txt .
RUN pip install --no-cache-dir -r requirements-ml.txt

# Copy the ML service code
COPY minimal_ml_service.py .
COPY data/ ./data/

# Create necessary directories
RUN mkdir -p data/models

# Expose port
EXPOSE 5001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5001/health || exit 1

# Run the service
CMD ["python", "minimal_ml_service.py"]
EOF

echo "✅ Created Dockerfile.ml-service"

# Create requirements-ml.txt
cat > requirements-ml.txt << 'EOF'
flask==2.3.3
requests==2.31.0
pandas==2.0.3
numpy==1.24.3
scikit-learn==1.3.0
prometheus-client==0.17.1
joblib==1.3.2
gunicorn==21.2.0
EOF

echo "✅ Created requirements-ml.txt"

# Create grafana directories and files
mkdir -p grafana/datasources
mkdir -p grafana/dashboards

cat > grafana/datasources/datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

echo "✅ Created grafana/datasources/datasource.yml"

cat > grafana/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

echo "✅ Created grafana/dashboards/dashboard.yml"

# Create docker-compose-fixed.yml
cat > docker-compose-fixed.yml << 'EOF'
services:
  # Database
  mysql-db:
    image: mysql:8.0
    container_name: banking-mysql
    ports:
      - "3306:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=bankingdemo
      - MYSQL_DATABASE=bankingdb
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql-init:/docker-entrypoint-initdb.d
    networks:
      - banking-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Account Service
  account-service:
    build: ./account-service
    container_name: banking-account-service
    ports:
      - "8081:8081"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/accountdb
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=bankingdemo
      - SIMULATE_SLOW_QUERY=false
    depends_on:
      mysql-db:
        condition: service_healthy
    networks:
      - banking-network

  # Transaction Service
  transaction-service:
    build: ./transaction-service
    container_name: banking-transaction-service
    ports:
      - "8082:8082"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/transactiondb
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=bankingdemo
      - ACCOUNT_SERVICE_URL=http://account-service:8081
      - SIMULATE_HIGH_LOAD=false
    depends_on:
      - mysql-db
      - account-service
    networks:
      - banking-network

  # Auth Service
  auth-service:
    build: ./auth-service
    container_name: banking-auth-service
    ports:
      - "8083:8083"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/authdb
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=bankingdemo
      - SIMULATE_MEMORY_LEAK=false
    depends_on:
      - mysql-db
    networks:
      - banking-network

  # Notification Service
  notification-service:
    build: ./notification-service
    container_name: banking-notification-service
    ports:
      - "8084:8084"
    environment:
      - SIMULATE_LATENCY=false
    networks:
      - banking-network

  # Fraud Detection Service
  fraud-detection:
    build: ./fraud-detection
    container_name: banking-fraud-detection
    ports:
      - "8085:8085"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/frauddb
      - SPRING_DATASOURCE_USERNAME=root
      - SPRING_DATASOURCE_PASSWORD=bankingdemo
      - SIMULATE_ALERT_STORM=false
    depends_on:
      - mysql-db
    networks:
      - banking-network

  # API Gateway (Simplified)
  api-gateway:
    build: ./api-gateway
    container_name: banking-api-gateway
    ports:
      - "8080:8080"
    environment:
      - ACCOUNT_SERVICE_URL=http://account-service:8081
      - TRANSACTION_SERVICE_URL=http://transaction-service:8082
      - AUTH_SERVICE_URL=http://auth-service:8083
      - NOTIFICATION_SERVICE_URL=http://notification-service:8084
      - FRAUD_SERVICE_URL=http://fraud-detection:8085
    depends_on:
      - account-service
      - transaction-service
      - auth-service
      - notification-service
      - fraud-detection
    networks:
      - banking-network

  # ML Detection Service
  ml-detection:
    build:
      context: .
      dockerfile: Dockerfile.ml-service
    container_name: ddos-ml-detection
    ports:
      - "5001:5001"
    networks:
      - banking-network
    depends_on:
      - prometheus

  # Prometheus
  prometheus:
    image: prom/prometheus:v2.45.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/ddos_alert_rules.yml:/etc/prometheus/ddos_alert_rules.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - banking-network

  # Grafana
  grafana:
    image: grafana/grafana:10.0.0
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/datasources:/etc/grafana/provisioning/datasources
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
    networks:
      - banking-network
    depends_on:
      - prometheus

networks:
  banking-network:
    driver: bridge

volumes:
  mysql-data:
  prometheus-data:
  grafana-data:
EOF

echo "✅ Created docker-compose-fixed.yml"

# Create the test script
cat > test_fixed_system.sh << 'EOF'
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
EOF

chmod +x test_fixed_system.sh

echo "✅ Created test_fixed_system.sh (executable)"

echo ""
echo "🎉 All files created successfully!"
echo ""
echo "📋 Files created:"
echo "• Dockerfile.ml-service"
echo "• requirements-ml.txt"
echo "• docker-compose-fixed.yml"
echo "• grafana/datasources/datasource.yml"
echo "• grafana/dashboards/dashboard.yml"
echo "• test_fixed_system.sh"
echo ""
echo "🚀 Now you can run:"
echo "./test_fixed_system.sh"