#!/bin/bash

echo "🎯 Deploying demo application..."

# Create namespace
kubectl apply -f namespace.yaml

# Deploy database first
echo "🗄️  Deploying PostgreSQL database..."
kubectl apply -f postgres.yaml
kubectl wait --for=condition=ready pod -l app=postgres -n demo --timeout=300s

# Deploy backend
echo "⚙️  Deploying backend API..."
kubectl apply -f backend.yaml
kubectl wait --for=condition=ready pod -l app=backend -n demo --timeout=300s

# Deploy frontend
echo "🌐 Deploying frontend..."
kubectl apply -f frontend.yaml
kubectl wait --for=condition=ready pod -l app=frontend -n demo --timeout=300s

# Deploy traffic generator
echo "🚦 Deploying traffic generator..."
kubectl apply -f traffic-generator.yaml

echo "✅ Demo application deployed successfully!"
echo ""
echo "🔍 Check deployment status:"
echo "  kubectl get pods -n demo"
echo "  kubectl get svc -n demo"
echo ""
echo "🌐 Access the application at: http://localhost:32000"