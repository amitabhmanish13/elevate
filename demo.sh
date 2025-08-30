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

# Create Kind cluster configuration
create_kind_config() {
    local arch=$1
    print_status "Creating Kind cluster configuration for $arch architecture..."
    
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
- role: worker
  image: kindest/node:v1.29.0
- role: worker
  image: kindest/node:v1.29.0
networking:
  disableDefaultCNI: true
  kubeProxyMode: "none"
EOF
}

# Create Kind cluster
create_cluster() {
    print_header "Creating Kind Cluster"
    
    # Delete existing cluster if it exists
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        print_status "Deleting existing cluster..."
        kind delete cluster --name ${CLUSTER_NAME}
    fi
    
    local arch=$(detect_arch)
    create_kind_config $arch
    
    print_status "Creating new Kind cluster..."
    kind create cluster --config kind-config.yaml --wait 300s
    
    # Set kubectl context
    kubectl cluster-info --context kind-${CLUSTER_NAME}
    print_success "Kind cluster created successfully"
}

# Install Cilium
install_cilium() {
    print_header "Installing Cilium CNI"
    
    # Add Cilium Helm repository
    helm repo add cilium https://helm.cilium.io/
    helm repo update
    
    # Install Cilium with optimized settings for demo
    print_status "Installing Cilium..."
    helm install cilium cilium/cilium \
        --namespace kube-system \
        --set kubeProxyReplacement=strict \
        --set k8sServiceHost=127.0.0.1 \
        --set k8sServicePort=6443 \
        --set hubble.relay.enabled=true \
        --set hubble.ui.enabled=true \
        --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}" \
        --set prometheus.enabled=true \
        --set operator.prometheus.enabled=true \
        --set hubble.enabled=true \
        --set hubble.metrics.enabled=true \
        --wait
    
    # Wait for Cilium to be ready
    print_status "Waiting for Cilium to be ready..."
    kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=300s
    
    print_success "Cilium installed successfully"
}

# Install monitoring stack
install_monitoring() {
    print_header "Installing Monitoring Stack"
    
    # Add Prometheus community Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Prometheus
    print_status "Installing Prometheus..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.retention=1h \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=2Gi \
        --set alertmanager.enabled=false \
        --set grafana.adminPassword=admin \
        --set grafana.persistence.enabled=false \
        --wait
    
    print_success "Monitoring stack installed successfully"
}

# Deploy demo application
deploy_demo_app() {
    print_header "Deploying Demo Application"
    
    # Create demo namespace
    kubectl create namespace ${DEMO_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy PostgreSQL database
    print_status "Deploying PostgreSQL database..."
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: ${DEMO_NAMESPACE}
  labels:
    app: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13-alpine
        env:
        - name: POSTGRES_DB
          value: demoapp
        - name: POSTGRES_USER
          value: demo
        - name: POSTGRES_PASSWORD
          value: password
        ports:
        - containerPort: 5432
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: ${DEMO_NAMESPACE}
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
EOF

    # Deploy backend API
    print_status "Deploying backend API..."
    cat << EOF | kubectl apply -f -
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
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
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
            return 200 '{"status":"healthy","service":"backend","timestamp":"'$(date -Iseconds)'"}';
            add_header Content-Type application/json;
        }
        location /api/users {
            return 200 '[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"},{"id":3,"name":"Charlie"}]';
            add_header Content-Type application/json;
        }
        location /api/metrics {
            return 200 '{"requests":1234,"errors":5,"uptime":"2h34m"}';
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
EOF

    # Deploy frontend
    print_status "Deploying frontend..."
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ${DEMO_NAMESPACE}
  labels:
    app: frontend
spec:
  replicas: 2
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
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
        - name: html
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: config
        configMap:
          name: frontend-config
      - name: html
        configMap:
          name: frontend-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: ${DEMO_NAMESPACE}
data:
  default.conf: |
    server {
        listen 80;
        location / {
            try_files \$uri \$uri/ /index.html;
        }
        location /api/ {
            proxy_pass http://backend/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
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
            .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .header { text-align: center; color: #2c3e50; margin-bottom: 30px; }
            .card { background: #ecf0f1; padding: 20px; margin: 15px 0; border-radius: 5px; border-left: 4px solid #3498db; }
            .status { display: inline-block; padding: 5px 10px; border-radius: 3px; color: white; font-weight: bold; }
            .healthy { background: #27ae60; }
            .button { background: #3498db; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; margin: 5px; }
            .button:hover { background: #2980b9; }
            #users, #metrics { margin-top: 10px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🐝 Cilium Demo Application</h1>
                <p>Showcasing Kubernetes networking with Cilium CNI</p>
            </div>
            
            <div class="card">
                <h3>Backend Health Status</h3>
                <span id="health-status" class="status healthy">Loading...</span>
                <button class="button" onclick="checkHealth()">Refresh Health</button>
            </div>
            
            <div class="card">
                <h3>User Data from Backend API</h3>
                <button class="button" onclick="loadUsers()">Load Users</button>
                <div id="users"></div>
            </div>
            
            <div class="card">
                <h3>Backend Metrics</h3>
                <button class="button" onclick="loadMetrics()">Load Metrics</button>
                <div id="metrics"></div>
            </div>
            
            <div class="card">
                <h3>Network Flow Visibility</h3>
                <p>This demo showcases:</p>
                <ul>
                    <li>🔍 <strong>Hubble:</strong> Real-time network flow monitoring</li>
                    <li>📊 <strong>Grafana:</strong> Metrics visualization and dashboards</li>
                    <li>⚡ <strong>Prometheus:</strong> Metrics collection and alerting</li>
                    <li>🌐 <strong>Cilium:</strong> eBPF-based networking and security</li>
                </ul>
            </div>
        </div>
        
        <script>
            async function checkHealth() {
                try {
                    const response = await fetch('/api/health');
                    const data = await response.json();
                    document.getElementById('health-status').textContent = 
                        \`✅ \${data.service} - \${data.status} (\${data.timestamp})\`;
                } catch (error) {
                    document.getElementById('health-status').textContent = '❌ Backend Unreachable';
                    document.getElementById('health-status').className = 'status';
                    document.getElementById('health-status').style.background = '#e74c3c';
                }
            }
            
            async function loadUsers() {
                try {
                    const response = await fetch('/api/users');
                    const users = await response.json();
                    document.getElementById('users').innerHTML = 
                        '<ul>' + users.map(u => \`<li>👤 \${u.name} (ID: \${u.id})</li>\`).join('') + '</ul>';
                } catch (error) {
                    document.getElementById('users').innerHTML = '<p style="color: red;">Failed to load users</p>';
                }
            }
            
            async function loadMetrics() {
                try {
                    const response = await fetch('/api/metrics');
                    const metrics = await response.json();
                    document.getElementById('metrics').innerHTML = 
                        \`<p>📈 Requests: \${metrics.requests} | ❌ Errors: \${metrics.errors} | ⏱️ Uptime: \${metrics.uptime}</p>\`;
                } catch (error) {
                    document.getElementById('metrics').innerHTML = '<p style="color: red;">Failed to load metrics</p>';
                }
            }
            
            // Auto-refresh health status
            setInterval(checkHealth, 5000);
            checkHealth();
        </script>
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
EOF

    # Deploy ingress
    print_status "Deploying ingress..."
    cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress
  namespace: ${DEMO_NAMESPACE}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
EOF
}

# Setup Hubble UI port forwarding
setup_hubble() {
    print_header "Setting up Hubble UI"
    
    print_status "Waiting for Hubble UI to be ready..."
    kubectl wait --for=condition=available deployment/hubble-ui -n kube-system --timeout=300s
    
    print_status "Starting Hubble UI port forwarding..."
    kubectl port-forward -n kube-system svc/hubble-ui 12000:80 > /dev/null 2>&1 &
    HUBBLE_PID=$!
    
    print_success "Hubble UI will be available at http://localhost:12000"
}

# Setup Grafana port forwarding
setup_grafana() {
    print_header "Setting up Grafana"
    
    print_status "Waiting for Grafana to be ready..."
    kubectl wait --for=condition=available deployment/prometheus-grafana -n monitoring --timeout=300s
    
    print_status "Starting Grafana port forwarding..."
    kubectl port-forward -n monitoring svc/prometheus-grafana 13000:80 > /dev/null 2>&1 &
    GRAFANA_PID=$!
    
    print_success "Grafana will be available at http://localhost:13000 (admin/admin)"
}

# Setup Prometheus port forwarding
setup_prometheus() {
    print_status "Setting up Prometheus..."
    kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 19090:9090 > /dev/null 2>&1 &
    PROMETHEUS_PID=$!
    
    print_success "Prometheus will be available at http://localhost:19090"
}

# Generate sample load
generate_load() {
    print_header "Generating Sample Load"
    
    print_status "Waiting for demo application to be ready..."
    kubectl wait --for=condition=available deployment/frontend -n ${DEMO_NAMESPACE} --timeout=300s
    kubectl wait --for=condition=available deployment/backend -n ${DEMO_NAMESPACE} --timeout=300s
    
    # Create load generator
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
            curl -s http://frontend/api/health > /dev/null
            curl -s http://frontend/api/users > /dev/null
            curl -s http://frontend/api/metrics > /dev/null
            curl -s http://backend/api/health > /dev/null
            sleep 2
          done
        resources:
          requests:
            memory: "16Mi"
            cpu: "10m"
          limits:
            memory: "32Mi"
            cpu: "20m"
EOF
    
    print_success "Load generator deployed"
}

# Import Grafana dashboards
import_dashboards() {
    print_status "Importing Cilium dashboards to Grafana..."
    
    # Wait a bit for Grafana to be fully ready
    sleep 10
    
    # Create Cilium dashboard
    cat << 'EOF' > cilium-dashboard.json
{
  "dashboard": {
    "id": null,
    "title": "Cilium Demo Dashboard",
    "tags": ["cilium", "demo"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Network Policy Drops",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(cilium_drop_count_total[5m]))",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Active Connections",
        "type": "graph",
        "targets": [
          {
            "expr": "cilium_connections_total",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      }
    ],
    "time": {"from": "now-15m", "to": "now"},
    "refresh": "5s"
  }
}
EOF
    
    # Import dashboard (this is a simplified version - in real scenarios you'd use Grafana API)
    print_success "Dashboard configuration created"
}

# Setup NGINX Ingress Controller
setup_ingress() {
    print_header "Setting up NGINX Ingress Controller"
    
    print_status "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    print_status "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    print_success "NGINX Ingress Controller ready"
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
    echo "  • Demo Application:  http://localhost:8080"
    echo "  • Hubble UI:         http://localhost:12000"
    echo "  • Grafana:           http://localhost:13000 (admin/admin)"
    echo "  • Prometheus:        http://localhost:19090"
    
    echo ""
    print_success "🔍 Useful Commands:"
    echo "  • View network flows: kubectl exec -n kube-system ds/cilium -- hubble observe"
    echo "  • Check Cilium status: kubectl exec -n kube-system ds/cilium -- cilium status"
    echo "  • View demo pods: kubectl get pods -n ${DEMO_NAMESPACE}"
    echo "  • View all services: kubectl get svc --all-namespaces"
    
    echo ""
    print_success "🧪 Demo Features:"
    echo "  • ✅ Cilium CNI with eBPF networking"
    echo "  • ✅ Hubble for network observability"
    echo "  • ✅ Prometheus metrics collection"
    echo "  • ✅ Grafana dashboards"
    echo "  • ✅ Multi-tier demo application"
    echo "  • ✅ Automated load generation"
    echo "  • ✅ Network policy demonstrations"
    
    echo ""
    print_warning "🛑 To cleanup: kind delete cluster --name ${CLUSTER_NAME}"
    
    # Keep port forwards running
    echo ""
    print_status "Port forwards are running in the background..."
    echo "Press Ctrl+C to stop all port forwards and exit"
    
    # Wait for interrupt
    trap 'cleanup' INT
    wait
}

# Cleanup function
cleanup() {
    print_header "Cleaning up..."
    
    # Kill port forwards
    if [[ ! -z "$HUBBLE_PID" ]]; then
        kill $HUBBLE_PID 2>/dev/null || true
    fi
    if [[ ! -z "$GRAFANA_PID" ]]; then
        kill $GRAFANA_PID 2>/dev/null || true
    fi
    if [[ ! -z "$PROMETHEUS_PID" ]]; then
        kill $PROMETHEUS_PID 2>/dev/null || true
    fi
    
    # Kill any remaining port forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Clean up temporary files
    rm -f kind-config.yaml cilium-dashboard.json
    
    print_success "Cleanup completed"
    exit 0
}

# Apply network policies for demo
apply_network_policies() {
    print_header "Applying Network Policies"
    
    cat << EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: frontend-policy
  namespace: ${DEMO_NAMESPACE}
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  egress:
  - toEndpoints:
    - matchLabels:
        app: backend
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
  - toFQDNs:
    - matchName: "kubernetes.default.svc.cluster.local"
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
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
  egress:
  - toEndpoints:
    - matchLabels:
        app: postgres
    toPorts:
    - ports:
      - port: "5432"
        protocol: TCP
EOF
    
    print_success "Network policies applied"
}

# Main execution
main() {
    print_header "🐝 Cilium Kubernetes Demo Setup"
    echo "This script will create a complete Kubernetes demo environment with:"
    echo "• Kind cluster with Cilium CNI"
    echo "• Hubble for network observability"
    echo "• Prometheus + Grafana monitoring"
    echo "• Demo application with load generation"
    echo ""
    
    # Detect architecture early
    local arch=$(detect_arch)
    print_status "Detected architecture: $arch"
    
    # Check dependencies
    check_dependencies
    
    # Create cluster
    create_cluster
    
    # Install Cilium
    install_cilium
    
    # Setup ingress controller
    setup_ingress
    
    # Install monitoring stack
    install_monitoring
    
    # Deploy demo application
    deploy_demo_app
    
    # Apply network policies
    apply_network_policies
    
    # Generate load
    generate_load
    
    # Setup port forwards and dashboards
    setup_hubble
    setup_grafana
    setup_prometheus
    
    # Import dashboards
    import_dashboards
    
    # Display final information
    display_dashboards
}

# Run main function
main "$@"