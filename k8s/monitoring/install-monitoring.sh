#!/bin/bash

echo "📊 Installing Prometheus and Grafana for Cilium Demo"

# Create monitoring namespace
echo "📁 Creating monitoring namespace..."
kubectl apply -f namespace.yaml

# Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
echo "📈 Installing Prometheus..."
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --values prometheus-values.yaml \
  --wait

# Install Grafana
echo "📊 Installing Grafana..."
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --values grafana-values.yaml \
  --wait

# Wait for pods to be ready
echo "⏳ Waiting for monitoring stack to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

echo "✅ Monitoring stack installation completed!"
echo "📊 Grafana available at: http://localhost:32003"
echo "📈 Prometheus available at: http://localhost:32002"
echo "👤 Grafana credentials: admin/admin123"
echo ""
echo "🔍 Verify installation:"
echo "  kubectl get pods -n monitoring"
echo "  kubectl get svc -n monitoring"