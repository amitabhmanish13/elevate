#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="cilium-demo"
DEMO_NAMESPACE="demo"

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Detect architecture
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Check and install dependencies
check_dependencies() {
    print_header "Checking Dependencies"
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        print_warning "This script is optimized for macOS but will attempt to run on $(uname)"
    fi
    
    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew not found. Please install Homebrew first: https://brew.sh"
        exit 1
    fi
    
    # Install dependencies
    local deps=("docker" "kubectl" "kind" "helm")
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            print_status "Installing $dep..."
            case $dep in
                docker)
                    brew install --cask docker
                    print_warning "Please start Docker Desktop and wait for it to be ready"
                    read -p "Press Enter when Docker is running..."
                    ;;
                kubectl)
                    brew install kubectl
                    ;;
                kind)
                    brew install kind
                    ;;
                helm)
                    brew install helm
                    ;;
            esac
        else
            print_success "$dep is already installed"
        fi
    done
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi
}

# Create simple Kind cluster configuration
create_kind_config() {
    print_status "Creating simple Kind cluster configuration..."
    
    cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  image: kindest/node:v1.29.0
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
networking:
  disableDefaultCNI: true
  kubeProxyMode: "none"
EOF
}

# Create Kind cluster
create_cluster() {
    print_header "Creating Kind Cluster"
    
    # Delete existing cluster if it exists
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        print_status "Deleting existing cluster..."
        kind delete cluster --name ${CLUSTER_NAME}
        sleep 5
    fi
    
    create_kind_config
    
    print_status "Creating new single-node Kind cluster..."
    kind create cluster --config kind-config.yaml --wait 60s
    
    # Wait for node to be ready
    print_status "Waiting for node to be ready..."
    local retries=0
    while [[ $retries -lt 30 ]]; do
        if kubectl get nodes | grep -q "Ready"; then
            print_success "Kind cluster created successfully"
            return 0
        fi
        print_status "Waiting for node... (attempt $((retries+1))/30)"
        sleep 5
        ((retries++))
    done
    
    print_error "Cluster failed to become ready"
    kubectl get nodes
    exit 1
}

# Install Cilium
install_cilium() {
    print_header "Installing Cilium CNI"
    
    # Clean up any existing helm repos
    helm repo remove cilium 2>/dev/null || true
    helm repo add cilium https://helm.cilium.io/
    helm repo update
    
    # Uninstall existing Cilium if present
    helm uninstall cilium -n kube-system 2>/dev/null || true
    sleep 5
    
    # Get the correct API server endpoint for Kind
    local api_server_ip=$(docker inspect ${CLUSTER_NAME}-control-plane --format '{{ .NetworkSettings.Networks.kind.IPAddress }}' 2>/dev/null || echo "127.0.0.1")
    local api_server_port=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://127.0.0.1:||')
    
    print_status "Installing Cilium with API server ${api_server_ip}:${api_server_port}..."
    helm install cilium cilium/cilium \
        --namespace kube-system \
        --set kubeProxyReplacement=true \
        --set k8sServiceHost=${api_server_ip} \
        --set k8sServicePort=${api_server_port} \
        --set hubble.relay.enabled=true \
        --set hubble.ui.enabled=true \
        --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}" \
        --set prometheus.enabled=true \
        --set operator.prometheus.enabled=true \
        --set hubble.enabled=true \
        --set ipam.mode=kubernetes \
        --set tunnel=vxlan \
        --set containerRuntime.integration=containerd \
        --set cgroup.autoMount.enabled=false \
        --set cgroup.hostRoot=/sys/fs/cgroup \
        --wait --timeout=300s
    
    # Wait for Cilium pods
    print_status "Waiting for Cilium to be ready..."
    kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=180s
    
    # Verify Cilium status
    print_status "Verifying Cilium installation..."
    local retries=0
    while [[ $retries -lt 10 ]]; do
        if kubectl exec -n kube-system ds/cilium -- cilium status --brief 2>/dev/null | grep -q "OK"; then
            print_success "Cilium installed and healthy"
            return 0
        fi
        print_status "Waiting for Cilium to be healthy... (attempt $((retries+1))/10)"
        sleep 10
        ((retries++))
    done
    
    print_warning "Cilium installed but health check timed out - continuing anyway"
}

# Install monitoring stack
install_monitoring() {
    print_header "Installing Monitoring Stack"
    
    # Clean up existing repos
    helm repo remove prometheus-community 2>/dev/null || true
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Uninstall existing if present
    helm uninstall prometheus -n monitoring 2>/dev/null || true
    sleep 10
    
    print_status "Installing Prometheus and Grafana..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.retention=30m \
        --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
        --set prometheus.prometheusSpec.resources.requests.cpu=100m \
        --set alertmanager.enabled=false \
        --set grafana.adminPassword=admin \
        --set grafana.persistence.enabled=false \
        --set grafana.resources.requests.memory=64Mi \
        --set grafana.resources.requests.cpu=50m \
        --set nodeExporter.enabled=false \
        --set kubeStateMetrics.enabled=true \
        --wait --timeout=300s
    
    print_success "Monitoring stack installed successfully"
}

# Deploy demo application
deploy_demo_app() {
    print_header "Deploying Demo Application"
    
    # Create demo namespace
    kubectl create namespace ${DEMO_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "Deploying lightweight demo application..."
    cat << EOF | kubectl apply -f -
# Backend API
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: ${DEMO_NAMESPACE}
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "16Mi"
            cpu: "10m"
          limits:
            memory: "32Mi"
            cpu: "50m"
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
      volumes:
      - name: config
        configMap:
          name: backend-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: ${DEMO_NAMESPACE}
data:
  default.conf: |
    server {
        listen 80;
        location /api/health {
            return 200 '{"status":"healthy","service":"backend","timestamp":"$(date -Iseconds)"}';
            add_header Content-Type application/json;
        }
        location /api/users {
            return 200 '[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]';
            add_header Content-Type application/json;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: ${DEMO_NAMESPACE}
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
---
# Frontend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ${DEMO_NAMESPACE}
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "16Mi"
            cpu: "10m"
          limits:
            memory: "32Mi"
            cpu: "50m"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: html
        configMap:
          name: frontend-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-html
  namespace: ${DEMO_NAMESPACE}
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Cilium Demo App</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; }
            .header { text-align: center; color: #2c3e50; margin-bottom: 30px; }
            .card { background: #ecf0f1; padding: 20px; margin: 15px 0; border-radius: 5px; }
            .button { background: #3498db; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
            .status { color: #27ae60; font-weight: bold; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🐝 Cilium Demo Application</h1>
                <p>Showcasing Kubernetes networking with Cilium CNI</p>
            </div>
            <div class="card">
                <h3>Backend Status</h3>
                <p class="status">✅ Backend is running and healthy!</p>
                <p>This demo showcases:</p>
                <ul>
                    <li>🔍 <strong>Hubble:</strong> Network flow monitoring</li>
                    <li>📊 <strong>Grafana:</strong> Metrics visualization</li>
                    <li>⚡ <strong>Cilium:</strong> eBPF networking</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: ${DEMO_NAMESPACE}
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
  
EOF

    # Wait for deployments
    print_status "Waiting for demo app to be ready..."
    kubectl wait --for=condition=available deployment/frontend -n ${DEMO_NAMESPACE} --timeout=120s
    kubectl wait --for=condition=available deployment/backend -n ${DEMO_NAMESPACE} --timeout=120s
    
    print_success "Demo application deployed"
}

# Generate sample load
generate_load() {
    print_status "Starting load generator..."
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-generator
  namespace: ${DEMO_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: load-generator
  template:
    metadata:
      labels:
        app: load-generator
    spec:
      containers:
      - name: load-generator
        image: alpine/curl
        command: ["/bin/sh"]
        args:
        - -c
        - |
          while true; do
            curl -s http://backend/api/health > /dev/null || true
            curl -s http://backend/api/users > /dev/null || true
            curl -s http://frontend/ > /dev/null || true
            sleep 3
          done
        resources:
          requests:
            memory: "8Mi"
            cpu: "5m"
          limits:
            memory: "16Mi"
            cpu: "20m"
EOF
    print_success "Load generator started"
}

# Apply network policies for demo
apply_network_policies() {
    print_status "Applying Cilium network policies..."
    cat << EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: demo-policy
  namespace: ${DEMO_NAMESPACE}
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    - matchLabels:
        app: load-generator
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
EOF
    print_success "Network policies applied"
}

# Setup port forwards
setup_port_forwards() {
    print_header "Setting up Port Forwards"
    
    # Kill any existing port forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Setup Hubble UI
    print_status "Setting up Hubble UI port forward..."
    kubectl port-forward -n kube-system svc/hubble-ui 12000:80 > /dev/null 2>&1 &
    HUBBLE_PID=$!
    
    # Setup Grafana
    print_status "Setting up Grafana port forward..."
    kubectl port-forward -n monitoring svc/prometheus-grafana 13000:80 > /dev/null 2>&1 &
    GRAFANA_PID=$!
    
    # Setup demo app
    print_status "Setting up demo app port forward..."
    kubectl port-forward -n ${DEMO_NAMESPACE} svc/frontend 18080:80 > /dev/null 2>&1 &
    DEMO_PID=$!
    
    sleep 3
    print_success "Port forwards established"
}

# Display dashboard information
display_dashboards() {
    print_header "🚀 Demo Environment Ready!"
    
    echo ""
    print_success "Cluster Information:"
    echo "  • Cluster Name: ${CLUSTER_NAME}"
    echo "  • Architecture: $(detect_arch)"
    echo "  • Nodes: $(kubectl get nodes --no-headers | wc -l)"
    
    echo ""
    print_success "📊 Dashboard URLs:"
    echo "  • Demo Application:  http://localhost:18080"
    echo "  • Hubble UI:         http://localhost:12000"
    echo "  • Grafana:           http://localhost:13000 (admin/admin)"
    
    echo ""
    print_success "🔍 Useful Commands:"
    echo "  • View network flows: kubectl exec -n kube-system ds/cilium -- hubble observe"
    echo "  • Check Cilium status: kubectl exec -n kube-system ds/cilium -- cilium status"
    echo "  • View demo pods: kubectl get pods -n ${DEMO_NAMESPACE}"
    
    echo ""
    print_success "🧪 Demo Features:"
    echo "  • ✅ Single-node Kind cluster (fast startup)"
    echo "  • ✅ Cilium CNI with eBPF networking"
    echo "  • ✅ Hubble for network observability"
    echo "  • ✅ Grafana dashboards"
    echo "  • ✅ Lightweight demo application"
    echo "  • ✅ Automated load generation"
    
    echo ""
    print_warning "🛑 To cleanup: kind delete cluster --name ${CLUSTER_NAME}"
    
    echo ""
    print_status "Port forwards are running in the background..."
    print_status "Press Ctrl+C to stop all port forwards and exit"
    
    # Wait for interrupt
    trap 'cleanup' INT
    wait
}

# Cleanup function
cleanup() {
    print_header "Cleaning up..."
    
    # Kill port forwards
    [[ ! -z "$HUBBLE_PID" ]] && kill $HUBBLE_PID 2>/dev/null || true
    [[ ! -z "$GRAFANA_PID" ]] && kill $GRAFANA_PID 2>/dev/null || true
    [[ ! -z "$DEMO_PID" ]] && kill $DEMO_PID 2>/dev/null || true
    
    # Kill any remaining port forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Clean up temporary files
    rm -f kind-config.yaml
    
    print_success "Cleanup completed"
    exit 0
}

# Main execution
main() {
    print_header "🐝 Cilium Kubernetes Demo Setup"
    echo "This script will create a lightweight Kubernetes demo environment with:"
    echo "• Single-node Kind cluster with Cilium CNI"
    echo "• Hubble for network observability"
    echo "• Grafana monitoring"
    echo "• Demo application with load generation"
    echo ""
    
    local arch=$(detect_arch)
    print_status "Detected architecture: $arch"
    
    check_dependencies
    create_cluster
    install_cilium
    install_monitoring
    deploy_demo_app
    generate_load
    apply_network_policies
    
    # Wait a bit for everything to settle
    print_status "Waiting for all components to be ready..."
    sleep 15
    
    setup_port_forwards
    display_dashboards
}

# Run main function
main "$@"