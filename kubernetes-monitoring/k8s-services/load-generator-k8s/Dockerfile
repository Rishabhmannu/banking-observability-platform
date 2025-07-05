FROM python:3.11-alpine

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# Create non-root user
RUN adduser -D -s /bin/sh loadgen
USER loadgen

# Run the load generator
CMD ["python", "app.py"]