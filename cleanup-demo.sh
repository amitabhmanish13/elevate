#!/bin/bash

echo "🧹 Cleaning up Cilium Network Observability Demo"
echo "==============================================="

# Stop port forwards
echo "🔌 Stopping port forwards..."
pkill -f "kubectl port-forward" || true

# Remove demo application
echo "🗑️  Removing demo application..."
kubectl delete namespace demo --ignore-not-found=true

# Remove monitoring stack
echo "📊 Removing monitoring stack..."
helm uninstall prometheus -n monitoring --ignore-not-found || true
helm uninstall grafana -n monitoring --ignore-not-found || true
kubectl delete namespace monitoring --ignore-not-found=true

# Ask before removing Cilium (as it affects cluster networking)
read -p "🤔 Do you want to remove Cilium? This will affect cluster networking (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🕸️  Removing Cilium..."
    helm uninstall cilium -n kube-system --ignore-not-found || true
    echo "⚠️  Cilium removed. You may need to reinstall a CNI for your cluster."
else
    echo "ℹ️  Keeping Cilium installed."
fi

# Remove demo images
echo "🐳 Removing demo Docker images..."
docker rmi demo/backend:latest demo/frontend:latest 2>/dev/null || true

echo ""
echo "✅ Cleanup completed!"
echo "🔄 To redeploy, run: ./deploy-demo.sh"