#!/bin/bash

echo "Waiting for RabbitMQ to start..."
sleep 10

echo "Enabling RabbitMQ Prometheus plugin..."
docker exec banking-rabbitmq rabbitmq-plugins enable rabbitmq_prometheus

echo "RabbitMQ Prometheus plugin enabled!"
echo "Metrics available at: http://localhost:15692/metrics"