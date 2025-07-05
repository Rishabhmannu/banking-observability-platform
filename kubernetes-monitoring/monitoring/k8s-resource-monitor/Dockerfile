FROM python:3.11-alpine

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# Create non-root user
RUN adduser -D -s /bin/sh k8smonitor
USER k8smonitor

# Expose metrics port
EXPOSE 9419

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9419/metrics || exit 1

# Run the monitor
CMD ["python", "app.py"]