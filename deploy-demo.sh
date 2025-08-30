#!/bin/bash

set -e

echo "🚀 Deploying Cilium Network Observability Demo"
echo "=============================================="

# Check prerequisites
echo "🔍 Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ helm is required but not installed. Aborting." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ docker is required but not installed. Aborting." >&2; exit 1; }

# Check if cluster is accessible
kubectl cluster-info >/dev/null 2>&1 || { echo "❌ Kubernetes cluster is not accessible. Aborting." >&2; exit 1; }

echo "✅ Prerequisites check passed"

# Build application images
echo "🏗️  Building application images..."
cd backend
docker build -t demo/backend:latest .
cd ../frontend
docker build -t demo/frontend:latest .
cd ..

echo "✅ Application images built"

# Deploy Cilium with Hubble
echo "🕸️  Installing Cilium with Hubble..."
cd k8s/cilium
chmod +x install-cilium.sh
./install-cilium.sh

# Wait for Cilium to be ready
echo "⏳ Waiting for Cilium to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=300s

echo "✅ Cilium installation completed"

# Deploy monitoring stack
echo "📊 Installing monitoring stack..."
cd ../monitoring
chmod +x install-monitoring.sh
./install-monitoring.sh

echo "✅ Monitoring stack installation completed"

# Deploy demo application
echo "🎯 Deploying demo application..."
cd ../demo-app

# Create namespace
kubectl apply -f namespace.yaml

# Deploy database
kubectl apply -f postgres.yaml
echo "⏳ Waiting for database to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n demo --timeout=300s

# Deploy backend
kubectl apply -f backend.yaml
echo "⏳ Waiting for backend to be ready..."
kubectl wait --for=condition=ready pod -l app=backend -n demo --timeout=300s

# Deploy frontend
kubectl apply -f frontend.yaml
echo "⏳ Waiting for frontend to be ready..."
kubectl wait --for=condition=ready pod -l app=frontend -n demo --timeout=300s

# Deploy traffic generator
kubectl apply -f traffic-generator.yaml

echo "✅ Demo application deployed"

# Apply network policies
echo "🛡️  Applying network policies..."
cd ../network-policies
kubectl apply -f frontend-policy.yaml
kubectl apply -f backend-policy.yaml
kubectl apply -f database-policy.yaml
kubectl apply -f traffic-generator-policy.yaml

echo "✅ Network policies applied"

# Import Grafana dashboards
echo "📈 Setting up Grafana dashboards..."
cd ../monitoring

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

# Get Grafana pod name
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

# Copy dashboard files to Grafana pod
kubectl cp cilium-dashboard.json monitoring/$GRAFANA_POD:/var/lib/grafana/dashboards/cilium/ || true
kubectl cp hubble-dashboard.json monitoring/$GRAFANA_POD:/var/lib/grafana/dashboards/hubble/ || true

echo "✅ Grafana dashboards configured"

# Display access information
echo ""
echo "🎉 Demo deployment completed successfully!"
echo "========================================"
echo ""
echo "🌐 Access URLs:"
echo "  📱 Demo Application:    http://localhost:32000"
echo "  🕸️  Hubble UI:          http://localhost:12000"
echo "  📊 Grafana:            http://localhost:32003 (admin/admin123)"
echo "  📈 Prometheus:         http://localhost:32002"
echo ""
echo "🔍 Useful Commands:"
echo "  # View network flows"
echo "  hubble observe"
echo ""
echo "  # View flows for specific namespace"
echo "  hubble observe --namespace demo"
echo ""
echo "  # View HTTP flows"
echo "  hubble observe --protocol http"
echo ""
echo "  # View dropped packets"
echo "  hubble observe --verdict DROPPED"
echo ""
echo "  # Check Cilium status"
echo "  cilium status"
echo ""
echo "  # View network policies"
echo "  kubectl get cnp -n demo"
echo ""
echo "  # Monitor pods"
echo "  kubectl get pods -n demo -w"
echo ""
echo "🚀 The demo is now ready! Visit the URLs above to explore network observability."