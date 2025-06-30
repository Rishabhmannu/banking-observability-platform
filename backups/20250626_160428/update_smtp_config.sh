#!/bin/bash

echo "🔧 Updating Grafana SMTP Configuration"
echo "====================================="

# Prompt for Gmail credentials
echo "Please provide your Gmail details:"
read -p "Gmail address: " GMAIL_ADDRESS
read -s -p "Gmail App Password (16 characters): " GMAIL_APP_PASSWORD
echo ""

# Backup existing docker-compose file
cp docker-compose-fixed.yml docker-compose-fixed.yml.backup
echo "✅ Backup created: docker-compose-fixed.yml.backup"

# Create updated docker-compose with SMTP configuration
cat > docker-compose-smtp.yml << EOF
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

  # API Gateway
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

  # Grafana with SMTP Configuration
  grafana:
    image: grafana/grafana:10.0.0
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      # SMTP Configuration for Gmail
      - GF_SMTP_ENABLED=true
      - GF_SMTP_HOST=smtp.gmail.com:587
      - GF_SMTP_USER=${GMAIL_ADDRESS}
      - GF_SMTP_PASSWORD=${GMAIL_APP_PASSWORD}
      - GF_SMTP_FROM_ADDRESS=${GMAIL_ADDRESS}
      - GF_SMTP_FROM_NAME=DDoS Detection System
      - GF_SMTP_SKIP_VERIFY=false
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

echo "✅ Created docker-compose-smtp.yml with SMTP configuration"

# Restart Grafana with new SMTP settings
echo "🔄 Restarting services with SMTP configuration..."
export GMAIL_ADDRESS="$GMAIL_ADDRESS"
export GMAIL_APP_PASSWORD="$GMAIL_APP_PASSWORD"

docker compose -f docker-compose-smtp.yml down grafana
docker compose -f docker-compose-smtp.yml up -d grafana

echo "✅ Grafana restarted with SMTP configuration"
echo ""
echo "🧪 Testing instructions:"
echo "1. Wait 30 seconds for Grafana to start"
echo "2. Go to: http://localhost:3000"
echo "3. Login with admin/admin"
echo "4. Go to Alerting → Contact points"
echo "5. Edit your gmail-ddos-alerts contact point"
echo "6. Click 'Test contact point'"
echo ""
echo "📧 You should now receive a test email!"
EOF

chmod +x update_smtp_config.sh

echo "✅ SMTP configuration script created!"
echo ""
echo "🚀 To update your system:"
echo "1. ./update_smtp_config.sh"
echo "2. Enter your Gmail address and App Password"
echo "3. Test the email in Grafana"