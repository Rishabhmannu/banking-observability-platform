FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# Expose port
EXPOSE 5004

# Environment variables
ENV PROMETHEUS_URL=http://prometheus:9090
ENV TRANSACTION_MONITOR_URL=http://transaction-monitor:5003

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
    CMD curl -f http://localhost:5004/health || exit 1

# Run the application
CMD ["python", "app.py"]