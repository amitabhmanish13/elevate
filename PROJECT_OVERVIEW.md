# 🕸️ Cilium Network Observability Demo - Project Overview

## 📁 Project Structure

```
cilium-network-demo/
├── 📜 README.md                    # Main project documentation
├── 🚀 deploy-demo.sh              # One-command deployment script
├── 🧪 test-demo.sh                # Testing and verification script
├── 🧹 cleanup-demo.sh             # Cleanup script
├── ⚡ QUICK_START.md              # Quick start guide
├── 📖 DEMO_SETUP_GUIDE.md         # Comprehensive setup guide
├── 🐳 docker-compose.dev.yml      # Local development environment
│
├── 🎯 backend/                     # Go backend application
│   ├── main.go                    # Enhanced API with Prometheus metrics
│   ├── go.mod                     # Go dependencies
│   ├── go.sum                     # Go dependency checksums
│   └── Dockerfile                 # Backend container image
│
├── 🌐 frontend/                    # React frontend application
│   ├── src/
│   │   ├── App.tsx                # Main app with network dashboard
│   │   ├── App.css                # Styling
│   │   └── components/
│   │       ├── UsersPage.tsx      # User management interface
│   │       ├── TasksPage.tsx      # Task management interface
│   │       └── NetworkDashboard.tsx # Network observability dashboard
│   ├── Dockerfile                 # Frontend container image
│   ├── nginx.conf                 # Nginx configuration
│   └── package.json               # Node.js dependencies
│
└── 🔧 k8s/                        # Kubernetes manifests
    ├── 🕸️ cilium/                 # Cilium CNI configuration
    │   ├── cilium-values.yaml     # Helm values for Cilium
    │   └── install-cilium.sh      # Cilium installation script
    │
    ├── 📊 monitoring/              # Prometheus + Grafana stack
    │   ├── namespace.yaml          # Monitoring namespace
    │   ├── prometheus-values.yaml # Prometheus configuration
    │   ├── grafana-values.yaml    # Grafana configuration
    │   ├── install-monitoring.sh  # Monitoring stack installer
    │   ├── cilium-dashboard.json  # Cilium Grafana dashboard
    │   └── hubble-dashboard.json  # Hubble Grafana dashboard
    │
    ├── 🎯 demo-app/               # Demo application manifests
    │   ├── namespace.yaml          # Demo namespace
    │   ├── postgres.yaml           # PostgreSQL deployment
    │   ├── backend.yaml            # Backend deployment
    │   ├── frontend.yaml           # Frontend deployment
    │   ├── traffic-generator.yaml  # Traffic generator
    │   ├── build-images.sh         # Image building script
    │   ├── deploy-app.sh           # Application deployment script
    │   ├── load-test.sh            # Load testing script
    │   └── init.sql                # Database initialization
    │
    └── 🛡️ network-policies/        # Cilium network policies
        ├── frontend-policy.yaml    # Frontend network policy
        ├── backend-policy.yaml     # Backend network policy
        ├── database-policy.yaml    # Database network policy
        └── traffic-generator-policy.yaml # Traffic generator policy
```

## 🎯 Key Components

### 🕸️ Cilium + Hubble
- **Purpose**: eBPF-based CNI with network observability
- **Features**: L3/L4/L7 monitoring, network policies, flow logs
- **Access**: Hubble UI at http://localhost:12000

### 📊 Monitoring Stack
- **Prometheus**: Metrics collection from Cilium, Hubble, and demo app
- **Grafana**: Visualization with pre-configured dashboards
- **Dashboards**: Cilium overview, Hubble flows, application metrics

### 🎯 Demo Application
- **Frontend**: React app with network dashboard and traffic controls
- **Backend**: Go API with CRUD operations and Prometheus metrics
- **Database**: PostgreSQL with sample users and tasks
- **Traffic Generator**: Automated traffic for demonstration

### 🛡️ Network Policies
- **Micro-segmentation**: Each component has specific ingress/egress rules
- **Security**: Database only accessible from backend
- **Observability**: Policy violations visible in Hubble

## 🚀 Deployment Options

### Option 1: Full Automated (Recommended)
```bash
./deploy-demo.sh
```

### Option 2: Development Environment
```bash
docker-compose -f docker-compose.dev.yml up
```

### Option 3: Manual Step-by-Step
```bash
# 1. Install Cilium
cd k8s/cilium && ./install-cilium.sh

# 2. Install monitoring
cd ../monitoring && ./install-monitoring.sh

# 3. Deploy application
cd ../demo-app && ./build-images.sh && ./deploy-app.sh

# 4. Apply network policies
cd ../network-policies && kubectl apply -f .
```

## 🎮 Demo Workflow

1. **Deploy** using automated script
2. **Access** demo app at http://localhost:32000
3. **Generate** traffic using app controls
4. **Observe** flows in Hubble UI
5. **Monitor** metrics in Grafana
6. **Test** network policies
7. **Analyze** security events

## 📈 Observability Features

### Real-Time Network Visibility
- Service-to-service communication
- HTTP request/response monitoring
- DNS query analysis
- Network policy enforcement

### Metrics and Dashboards
- Flow rates and patterns
- Latency distributions
- Error rates and types
- Security policy violations

### CLI Tools
- `hubble observe` for live flow monitoring
- `cilium status` for system health
- `kubectl` for resource management

## 🎓 Learning Outcomes

After running this demo, you'll understand:
- How Cilium provides network observability
- eBPF-based traffic monitoring
- Network policy enforcement
- Integration with monitoring stacks
- L7 application-layer visibility
- Security event analysis

## 🔧 Customization

### Adding New Services
1. Create deployment YAML
2. Add network policy
3. Update monitoring configuration
4. Add to traffic generator

### Custom Network Policies
1. Edit policy YAML files
2. Apply with `kubectl apply`
3. Test with `hubble observe`
4. Monitor in Grafana

### Additional Dashboards
1. Import from grafana.com
2. Create custom panels
3. Add new metrics sources
4. Configure alerts

---

**Ready to explore the future of network observability! 🌟**