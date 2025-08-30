#!/bin/bash

echo "🏗️  Building demo application images..."

# Build backend image
echo "📦 Building backend image..."
cd ../../backend
docker build -t demo/backend:latest .

# Build frontend image  
echo "📦 Building frontend image..."
cd ../frontend
docker build -t demo/frontend:latest .

echo "✅ Images built successfully!"
echo ""
echo "📋 Built images:"
docker images | grep demo/

cd ../k8s/demo-app