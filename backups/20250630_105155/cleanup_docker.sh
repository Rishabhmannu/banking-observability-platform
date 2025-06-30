#!/bin/bash

echo "🧹 Cleaning up Docker environment..."

# Stop all containers
echo "Stopping all containers..."
docker compose down --volumes --remove-orphans

# Clean up Docker system
echo "Cleaning Docker system..."
docker system prune -f
docker builder prune -f

# Remove any stuck containers/images
echo "Removing old images..."
docker image prune -a -f

echo "✅ Docker cleanup complete!"