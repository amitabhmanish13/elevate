#!/bin/bash

echo "🚀 Installing Cilium with Hubble for Network Observability Demo"

# Add Cilium Helm repository
echo "📦 Adding Cilium Helm repository..."
helm repo add cilium https://helm.cilium.io/
helm repo update

# Install Cilium with custom values
echo "🔧 Installing Cilium with Hubble enabled..."
helm upgrade --install cilium cilium/cilium \
  --version 1.16.5 \
  --namespace kube-system \
  --values cilium-values.yaml \
  --wait

# Wait for Cilium to be ready
echo "⏳ Waiting for Cilium to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=300s

# Enable Hubble UI port-forward (run in background)
echo "🌐 Setting up Hubble UI access..."
kubectl port-forward -n kube-system svc/hubble-ui 12000:80 &

# Install Hubble CLI
echo "🔧 Installing Hubble CLI..."
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

# Enable Hubble relay port-forward
echo "🔗 Setting up Hubble relay access..."
kubectl port-forward -n kube-system svc/hubble-relay 4245:80 &

echo "✅ Cilium installation completed!"
echo "🌐 Hubble UI available at: http://localhost:12000"
echo "🔗 Hubble CLI ready for use"
echo ""
echo "🔍 Verify installation:"
echo "  kubectl get pods -n kube-system -l k8s-app=cilium"
echo "  hubble status"
echo "  hubble observe"