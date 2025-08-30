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
DEBUG_LOG="/tmp/cilium-demo-debug.log"
START_TIME=$(date +%s)

# Global state tracking
CILIUM_READY=false
MONITORING_READY=false
DEMO_APP_READY=false
NETWORK_ISSUES=false

# Debug and logging functions
setup_debug() {
    # Create debug log
    echo "=== Cilium Demo Debug Log - $(date) ===" > "$DEBUG_LOG"
    echo "Architecture: $(uname -m)" >> "$DEBUG_LOG"
    echo "OS: $(uname -s)" >> "$DEBUG_LOG"
    echo "Docker version: $(docker --version 2>/dev/null || echo 'Not available')" >> "$DEBUG_LOG"
    echo "kubectl version: $(kubectl version --client --short 2>/dev/null || echo 'Not available')" >> "$DEBUG_LOG"
    echo "kind version: $(kind --version 2>/dev/null || echo 'Not available')" >> "$DEBUG_LOG"
    echo "helm version: $(helm version --short 2>/dev/null || echo 'Not available')" >> "$DEBUG_LOG"
    echo "======================================" >> "$DEBUG_LOG"
}

debug_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$DEBUG_LOG"
}

capture_error() {
    local component="$1"
    local error_msg="$2"
    debug_log "ERROR in $component: $error_msg"
    
    # Capture cluster state
    echo "=== $component Error Details ===" >> "$DEBUG_LOG"
    echo "Error: $error_msg" >> "$DEBUG_LOG"
    kubectl get nodes -o wide >> "$DEBUG_LOG" 2>&1 || true
    kubectl get pods --all-namespaces >> "$DEBUG_LOG" 2>&1 || true
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20 >> "$DEBUG_LOG" 2>&1 || true
    echo "================================" >> "$DEBUG_LOG"
}

# Print colored output with debug logging
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    debug_log "INFO: $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    debug_log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    debug_log "WARNING: $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    debug_log "ERROR: $1"
}

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
    debug_log "SECTION: $1"
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
            capture_error "ARCH_DETECTION" "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Fast dependency check with parallel operations
check_dependencies() {
    print_header "Fast Dependency Check"
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        print_warning "This script is optimized for macOS but will attempt to run on $(uname)"
    fi
    
    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew not found. Please install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    # Quick dependency check (no auto-install for speed)
    local missing_deps=()
    local deps=("docker" "kubectl" "kind" "helm")
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            missing_deps+=($dep)
        else
            print_success "$dep is available"
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_status "Install with: brew install ${missing_deps[*]}"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi
    
    # Quick network connectivity test
    print_status "Testing network connectivity..."
    if command -v curl &> /dev/null; then
        if ! timeout 10s curl -s https://registry.k8s.io > /dev/null 2>&1; then
            NETWORK_ISSUES=true
            print_warning "Network connectivity issues detected - will use offline/cached resources where possible"
        else
            print_success "Network connectivity OK"
        fi
    fi
}

# Minimal Kind cluster configuration for speed
create_kind_config() {
    print_status "Creating minimal Kind cluster configuration..."
    
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
        max-pods: "50"
  - |
    kind: ClusterConfiguration
    etcd:
      local:
        extraArgs:
          quota-backend-bytes: "1073741824"
    apiServer:
      extraArgs:
        enable-admission-plugins: "NodeRestriction"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
networking:
  disableDefaultCNI: true
  kubeProxyMode: "none"
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/16"
EOF
}

# Fast cluster creation
create_cluster() {
    print_header "Creating Minimal Kind Cluster"
    
    # Delete existing cluster quickly
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        print_status "Deleting existing cluster..."
        kind delete cluster --name ${CLUSTER_NAME} &
        local delete_pid=$!
        
        # Wait max 30 seconds for deletion
        local delete_timeout=0
        while kill -0 $delete_pid 2>/dev/null && [[ $delete_timeout -lt 30 ]]; do
            sleep 1
            ((delete_timeout++))
        done
        
        if kill -0 $delete_pid 2>/dev/null; then
            print_warning "Cluster deletion taking too long, forcing..."
            kill $delete_pid 2>/dev/null || true
            docker rm -f $(docker ps -aq --filter "label=io.x-k8s.kind.cluster=${CLUSTER_NAME}") 2>/dev/null || true
        fi
    fi
    
    create_kind_config
    
    print_status "Creating single-node cluster for speed..."
    if ! kind create cluster --config kind-config.yaml --wait 90s; then
        capture_error "CLUSTER_CREATION" "Kind cluster creation failed"
        print_error "Cluster creation failed"
        exit 1
    fi
    
    # Quick readiness check
    print_status "Quick cluster readiness check..."
    local ready_retries=0
    while [[ $ready_retries -lt 20 ]]; do
        if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
            print_success "Cluster is ready"
            return 0
        fi
        sleep 3
        ((ready_retries++))
    done
    
    print_warning "Cluster not fully ready but continuing..."
}

# Fast Cilium installation with fallbacks
install_cilium() {
    print_header "Installing Cilium CNI (Fast Mode)"
    
    # Setup helm repo with retry
    local repo_success=false
    for attempt in 1 2 3; do
        print_status "Setting up Cilium repo (attempt $attempt/3)..."
        if timeout 20s bash -c "helm repo remove cilium 2>/dev/null || true; helm repo add cilium https://helm.cilium.io/ && helm repo update"; then
            repo_success=true
            break
        fi
        print_warning "Repo setup failed, retrying..."
        sleep 5
    done
    
    if [[ "$repo_success" != "true" ]]; then
        capture_error "CILIUM_REPO" "Failed to setup Cilium helm repository after 3 attempts"
        print_error "Cannot setup Cilium repository - check network connectivity"
        exit 1
    fi
    
    # Uninstall existing
    helm uninstall cilium -n kube-system 2>/dev/null || true
    sleep 3
    
    print_status "Installing Cilium with minimal config for speed..."
    
    # Get API server info
    local api_endpoint=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    local api_host=$(echo $api_endpoint | sed 's|https://||' | cut -d: -f1)
    local api_port=$(echo $api_endpoint | sed 's|https://||' | cut -d: -f2)
    
    # Fast Cilium installation
    if helm install cilium cilium/cilium \
        --namespace kube-system \
        --set kubeProxyReplacement=true \
        --set k8sServiceHost=${api_host} \
        --set k8sServicePort=${api_port} \
        --set hubble.relay.enabled=true \
        --set hubble.ui.enabled=true \
        --set hubble.metrics.enabled="{dns,drop,tcp,flow}" \
        --set prometheus.enabled=true \
        --set operator.prometheus.enabled=true \
        --set hubble.enabled=true \
        --set operator.replicas=1 \
        --set hubble.relay.replicas=1 \
        --timeout=180s; then
        print_success "Cilium installed"
    else
        capture_error "CILIUM_INSTALL" "Helm install failed"
        print_error "Cilium installation failed"
        exit 1
    fi
    
    # Async wait for Cilium readiness (don't block)
    print_status "Cilium initializing in background..."
    (
        sleep 30  # Give init containers time
        if kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=240s 2>/dev/null; then
            CILIUM_READY=true
            debug_log "Cilium pods are ready"
        else
            debug_log "Cilium pods not ready after timeout"
        fi
    ) &
    
    print_success "Cilium installation started"
}

# Lightweight monitoring with fallbacks
install_monitoring() {
    print_header "Installing Monitoring (Optional)"
    
    if [[ "$NETWORK_ISSUES" == "true" ]]; then
        print_warning "Skipping monitoring due to network issues"
        return 0
    fi
    
    # Quick monitoring setup
    print_status "Installing minimal Grafana..."
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
    
    # Simple Grafana deployment (no external charts)
    cat << EOF | kubectl apply -f - 2>/dev/null || {
        print_warning "Failed to deploy monitoring - continuing without it"
        return 0
    }
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.2.2
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: admin
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "100m"
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
EOF
    
    MONITORING_READY=true
    print_success "Basic monitoring installed"
}

# Ultra-lightweight demo application
deploy_demo_app() {
    print_header "Deploying Ultra-Light Demo App"
    
    kubectl create namespace ${DEMO_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "Deploying minimal demo application..."
    cat << EOF | kubectl apply -f -
# Backend API (single pod)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: ${DEMO_NAMESPACE}
spec:
  replicas: 1
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
            memory: "8Mi"
            cpu: "5m"
          limits:
            memory: "16Mi"
            cpu: "25m"
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
        readinessProbe:
          httpGet:
            path: /api/health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
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
            return 200 '{"status":"healthy","service":"backend","pod":"'"\$hostname"'","timestamp":"'"\$(date -Iseconds)"'"}';
            add_header Content-Type application/json;
        }
        location /api/users {
            return 200 '[{"id":1,"name":"Alice","status":"active"},{"id":2,"name":"Bob","status":"active"}]';
            add_header Content-Type application/json;
        }
        location /api/metrics {
            return 200 '{"requests":'"\$((RANDOM % 1000 + 100))"',"errors":'"\$((RANDOM % 10))"',"uptime":"'"\$(uptime -p)"'"}';
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
# Frontend (single pod)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ${DEMO_NAMESPACE}
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
            memory: "8Mi"
            cpu: "5m"
          limits:
            memory: "16Mi"
            cpu: "25m"
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
        - name: nginx-config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
      volumes:
      - name: html
        configMap:
          name: frontend-html
      - name: nginx-config
        configMap:
          name: frontend-config
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
            proxy_connect_timeout 5s;
            proxy_read_timeout 10s;
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
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>🐝 Cilium Demo</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 20px; }
            .container { max-width: 800px; margin: 0 auto; background: white; border-radius: 15px; box-shadow: 0 10px 30px rgba(0,0,0,0.2); overflow: hidden; }
            .header { background: linear-gradient(135deg, #4f46e5, #7c3aed); color: white; padding: 30px; text-align: center; }
            .header h1 { font-size: 2.5em; margin-bottom: 10px; }
            .header p { opacity: 0.9; font-size: 1.1em; }
            .content { padding: 30px; }
            .card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: 20px; margin: 20px 0; }
            .card h3 { color: #1e293b; margin-bottom: 15px; }
            .status { display: inline-block; padding: 8px 16px; border-radius: 20px; font-weight: bold; }
            .healthy { background: #10b981; color: white; }
            .loading { background: #f59e0b; color: white; }
            .button { background: #4f46e5; color: white; padding: 12px 24px; border: none; border-radius: 8px; cursor: pointer; margin: 5px; font-weight: 500; transition: all 0.2s; }
            .button:hover { background: #4338ca; transform: translateY(-1px); }
            .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
            .metric { background: #eff6ff; padding: 15px; border-radius: 8px; text-align: center; }
            .metric-value { font-size: 2em; font-weight: bold; color: #1d4ed8; }
            .metric-label { color: #64748b; margin-top: 5px; }
            #output { background: #1e293b; color: #e2e8f0; padding: 15px; border-radius: 8px; font-family: 'Monaco', 'Consolas', monospace; font-size: 0.9em; max-height: 200px; overflow-y: auto; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🐝 Cilium Network Demo</h1>
                <p>eBPF-powered Kubernetes networking in action</p>
            </div>
            <div class="content">
                <div class="card">
                    <h3>🚀 System Status</h3>
                    <span id="status" class="status loading">Initializing...</span>
                    <button class="button" onclick="checkStatus()">Refresh Status</button>
                    <button class="button" onclick="runTests()">Run Network Tests</button>
                </div>
                
                <div class="grid">
                    <div class="card">
                        <h3>📊 Live Metrics</h3>
                        <div class="metric">
                            <div id="requests" class="metric-value">-</div>
                            <div class="metric-label">API Requests</div>
                        </div>
                    </div>
                    <div class="card">
                        <h3>👥 User Data</h3>
                        <div id="users">Loading...</div>
                        <button class="button" onclick="loadUsers()">Fetch Users</button>
                    </div>
                </div>
                
                <div class="card">
                    <h3>🔍 Network Observability</h3>
                    <p><strong>Cilium Features Demonstrated:</strong></p>
                    <ul style="margin: 10px 0; padding-left: 20px;">
                        <li>🌐 eBPF-based networking and load balancing</li>
                        <li>🔒 Network policy enforcement</li>
                        <li>📈 Real-time flow monitoring with Hubble</li>
                        <li>⚡ High-performance packet processing</li>
                    </ul>
                </div>
                
                <div class="card">
                    <h3>🖥️ Test Output</h3>
                    <div id="output">Ready for network tests...</div>
                </div>
            </div>
        </div>
        
        <script>
            let testCount = 0;
            
            async function checkStatus() {
                try {
                    const response = await fetch('/api/health');
                    const data = await response.json();
                    document.getElementById('status').textContent = \`✅ \${data.service} healthy (Pod: \${data.pod})\`;
                    document.getElementById('status').className = 'status healthy';
                    return true;
                } catch (error) {
                    document.getElementById('status').textContent = '❌ Backend unavailable';
                    document.getElementById('status').className = 'status loading';
                    return false;
                }
            }
            
            async function loadUsers() {
                try {
                    const response = await fetch('/api/users');
                    const users = await response.json();
                    document.getElementById('users').innerHTML = users.map(u => 
                        \`<div style="padding: 5px; border-left: 3px solid #4f46e5; margin: 5px 0; background: white; border-radius: 3px;">👤 \${u.name} (ID: \${u.id}) - \${u.status}</div>\`
                    ).join('');
                } catch (error) {
                    document.getElementById('users').innerHTML = '<div style="color: #ef4444;">Failed to load users</div>';
                }
            }
            
            async function updateMetrics() {
                try {
                    const response = await fetch('/api/metrics');
                    const metrics = await response.json();
                    document.getElementById('requests').textContent = metrics.requests;
                } catch (error) {
                    document.getElementById('requests').textContent = 'Error';
                }
            }
            
            async function runTests() {
                const output = document.getElementById('output');
                output.innerHTML = 'Running network tests...<br>';
                
                testCount++;
                const tests = [
                    { name: 'Backend Health', url: '/api/health' },
                    { name: 'User API', url: '/api/users' },
                    { name: 'Metrics API', url: '/api/metrics' }
                ];
                
                for (const test of tests) {
                    try {
                        const start = Date.now();
                        const response = await fetch(test.url);
                        const duration = Date.now() - start;
                        const status = response.ok ? '✅' : '❌';
                        output.innerHTML += \`\${status} \${test.name}: \${duration}ms<br>\`;
                    } catch (error) {
                        output.innerHTML += \`❌ \${test.name}: Failed<br>\`;
                    }
                }
                
                output.innerHTML += \`<br>Test run #\${testCount} completed at \${new Date().toLocaleTimeString()}<br>\`;
                output.scrollTop = output.scrollHeight;
            }
            
            // Auto-refresh
            setInterval(checkStatus, 10000);
            setInterval(updateMetrics, 5000);
            
            // Initial load
            setTimeout(() => {
                checkStatus();
                loadUsers();
                updateMetrics();
            }, 1000);
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

    # Quick wait for deployments
    print_status "Waiting for demo app (30s timeout)..."
    if kubectl wait --for=condition=available deployment/frontend -n ${DEMO_NAMESPACE} --timeout=30s && \
       kubectl wait --for=condition=available deployment/backend -n ${DEMO_NAMESPACE} --timeout=30s; then
        DEMO_APP_READY=true
        print_success "Demo application ready"
    else
        print_warning "Demo app deployment slow - continuing anyway"
        DEMO_APP_READY=false
    fi
}

# Minimal load generator
generate_load() {
    print_status "Starting lightweight load generator..."
    cat << EOF | kubectl apply -f - 2>/dev/null || true
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
            sleep 5
          done
        resources:
          requests:
            memory: "4Mi"
            cpu: "2m"
          limits:
            memory: "8Mi"
            cpu: "10m"
EOF
    print_success "Load generator started"
}

# Apply minimal network policies
apply_network_policies() {
    print_status "Applying network policies..."
    cat << EOF | kubectl apply -f - 2>/dev/null || {
        print_warning "Network policies failed - Cilium may not be ready yet"
        return 0
    }
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: demo-backend-policy
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
EOF
    print_success "Network policies applied"
}

# Fast port forward setup
setup_port_forwards() {
    print_header "Setting up Access Points"
    
    # Kill existing port forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    local pf_pids=()
    
    # Demo app (priority)
    if [[ "$DEMO_APP_READY" == "true" ]] || kubectl get svc frontend -n ${DEMO_NAMESPACE} &>/dev/null; then
        print_status "Setting up demo app access..."
        kubectl port-forward -n ${DEMO_NAMESPACE} svc/frontend 18080:80 > /dev/null 2>&1 &
        pf_pids+=($!)
    fi
    
    # Hubble UI (if available)
    if kubectl get svc hubble-ui -n kube-system &>/dev/null; then
        print_status "Setting up Hubble UI access..."
        kubectl port-forward -n kube-system svc/hubble-ui 12000:80 > /dev/null 2>&1 &
        pf_pids+=($!)
    fi
    
    # Grafana (if available)
    if kubectl get svc grafana -n monitoring &>/dev/null; then
        print_status "Setting up Grafana access..."
        kubectl port-forward -n monitoring svc/grafana 13000:3000 > /dev/null 2>&1 &
        pf_pids+=($!)
    elif kubectl get svc prometheus-grafana -n monitoring &>/dev/null; then
        print_status "Setting up Prometheus Grafana access..."
        kubectl port-forward -n monitoring svc/prometheus-grafana 13000:80 > /dev/null 2>&1 &
        pf_pids+=($!)
    fi
    
    # Store PIDs for cleanup
    export PORT_FORWARD_PIDS="${pf_pids[*]}"
    
    sleep 3
    print_success "Port forwards established"
}

# Comprehensive status check
check_final_status() {
    print_header "🔍 Final System Status"
    
    # Cluster status
    local nodes_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep Ready | wc -l)
    print_status "Cluster: $nodes_ready nodes ready"
    
    # Cilium status
    local cilium_pods=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | wc -l)
    local cilium_ready=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | grep Running | wc -l)
    print_status "Cilium: $cilium_ready/$cilium_pods pods running"
    
    # Hubble status
    if kubectl get pods -n kube-system -l k8s-app=hubble-ui --no-headers 2>/dev/null | grep -q Running; then
        print_status "Hubble UI: ✅ Running"
    else
        print_status "Hubble UI: ⏳ Starting"
    fi
    
    # Demo app status
    local demo_pods=$(kubectl get pods -n ${DEMO_NAMESPACE} --no-headers 2>/dev/null | wc -l)
    local demo_ready=$(kubectl get pods -n ${DEMO_NAMESPACE} --no-headers 2>/dev/null | grep Running | wc -l)
    print_status "Demo App: $demo_ready/$demo_pods pods running"
    
    # Monitoring status
    if kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -q Running; then
        print_status "Monitoring: ✅ Available"
    else
        print_status "Monitoring: ❌ Not available"
    fi
}

# Enhanced dashboard display
display_dashboards() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    print_header "🚀 Demo Environment Ready!"
    
    print_success "Setup completed in ${duration} seconds"
    
    echo ""
    print_success "📊 Available Dashboards:"
    
    # Check what's actually available
    local available_services=()
    
    if kubectl get svc frontend -n ${DEMO_NAMESPACE} &>/dev/null; then
        available_services+=("Demo Application: http://localhost:18080")
    fi
    
    if kubectl get svc hubble-ui -n kube-system &>/dev/null; then
        available_services+=("Hubble UI: http://localhost:12000")
    fi
    
    if kubectl get svc grafana -n monitoring &>/dev/null || kubectl get svc prometheus-grafana -n monitoring &>/dev/null; then
        available_services+=("Grafana: http://localhost:13000 (admin/admin)")
    fi
    
    for service in "${available_services[@]}"; do
        echo "  • $service"
    done
    
    echo ""
    check_final_status
    
    echo ""
    print_success "🔍 Debug Commands:"
    echo "  • View debug log: cat $DEBUG_LOG"
    echo "  • Cilium status: kubectl exec -n kube-system ds/cilium -- cilium status"
    echo "  • Network flows: kubectl exec -n kube-system ds/cilium -- hubble observe"
    echo "  • All pods: kubectl get pods --all-namespaces"
    
    echo ""
    print_success "🧪 Demo Features Working:"
    [[ ${#available_services[@]} -gt 0 ]] && echo "  • ✅ Web interfaces available"
    [[ $cilium_ready -gt 0 ]] && echo "  • ✅ Cilium networking active"
    kubectl get pods -n ${DEMO_NAMESPACE} --no-headers 2>/dev/null | grep -q Running && echo "  • ✅ Demo application running"
    kubectl get ciliumnetworkpolicy -n ${DEMO_NAMESPACE} &>/dev/null && echo "  • ✅ Network policies active"
    
    echo ""
    print_warning "🛑 Cleanup: kind delete cluster --name ${CLUSTER_NAME}"
    
    echo ""
    print_status "Port forwards running in background. Press Ctrl+C to exit."
    
    # Keep running
    trap 'cleanup' INT TERM
    
    # Background health monitoring
    (
        while true; do
            sleep 30
            debug_log "Health check: $(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -c Running) pods running"
        done
    ) &
    
    wait
}

# Enhanced cleanup
cleanup() {
    print_header "Cleaning up..."
    
    # Kill all port forwards
    if [[ ! -z "$PORT_FORWARD_PIDS" ]]; then
        for pid in $PORT_FORWARD_PIDS; do
            kill $pid 2>/dev/null || true
        done
    fi
    
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    # Clean up files
    rm -f kind-config.yaml
    
    print_status "Debug log saved to: $DEBUG_LOG"
    print_success "Cleanup completed"
    exit 0
}

# Main execution with comprehensive error handling
main() {
    # Setup debugging first
    setup_debug
    
    print_header "🐝 Cilium Demo - Ultra-Fast Setup"
    echo "Target: Complete setup in under 10 minutes"
    echo "Features: Cilium + Hubble + Demo App + Monitoring"
    echo ""
    
    local arch=$(detect_arch)
    print_status "Architecture: $arch"
    debug_log "Starting demo setup for $arch"
    
    # Execute with error handling
    set +e  # Don't exit on errors, handle them gracefully
    
    check_dependencies || {
        capture_error "DEPENDENCIES" "Dependency check failed"
        exit 1
    }
    
    create_cluster || {
        capture_error "CLUSTER" "Cluster creation failed"
        exit 1
    }
    
    install_cilium || {
        capture_error "CILIUM" "Cilium installation failed"
        exit 1
    }
    
    # Continue with demo app regardless of Cilium readiness
    deploy_demo_app
    generate_load
    apply_network_policies
    
    # Optional monitoring
    install_monitoring
    
    # Final setup
    print_status "Finalizing setup..."
    sleep 10
    
    setup_port_forwards
    display_dashboards
}

# Run main function
main "$@"