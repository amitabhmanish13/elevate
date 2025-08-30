# Cilium Network Observability Demo

A comprehensive demonstration of Cilium CNI with Hubble network observability, integrated with Prometheus and Grafana monitoring.

## 🏗️ Architecture

This demo showcases:
- **Cilium CNI** with eBPF-based networking
- **Hubble** for network flow visibility and security observability
- **Prometheus** for metrics collection
- **Grafana** for visualization and dashboards
- **Demo Application** with frontend (React), backend (Go), and database (PostgreSQL)

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster (kind, minikube, or any K8s cluster)
- Docker
- kubectl
- Helm 3
- 8GB+ RAM recommended

### One-Command Deployment
```bash
chmod +x deploy-demo.sh
./deploy-demo.sh
```

### Manual Step-by-Step Deployment

1. **Install Cilium with Hubble**
```bash
cd k8s/cilium
chmod +x install-cilium.sh
./install-cilium.sh
```

2. **Install Monitoring Stack**
```bash
cd ../monitoring
chmod +x install-monitoring.sh
./install-monitoring.sh
```

3. **Build and Deploy Demo Application**
```bash
# Build images
docker build -t demo/backend:latest ./backend
docker build -t demo/frontend:latest ./frontend

# Deploy application
cd ../demo-app
kubectl apply -f namespace.yaml
kubectl apply -f postgres.yaml
kubectl apply -f backend.yaml
kubectl apply -f frontend.yaml
kubectl apply -f traffic-generator.yaml

# Apply network policies
cd ../network-policies
kubectl apply -f .
```

## 🌐 Access Points

After deployment, access the following services:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Demo Application** | http://localhost:32000 | - |
| **Hubble UI** | http://localhost:12000 | - |
| **Grafana** | http://localhost:32003 | admin/admin123 |
| **Prometheus** | http://localhost:32002 | - |

## 🎯 Demo Scenarios

### 1. Network Flow Visualization
- Open Hubble UI to see real-time network flows
- Navigate through the demo app to generate traffic
- Observe HTTP, DNS, and database connections

### 2. Network Policy Enforcement
- View network policies: `kubectl get cnp -n demo`
- Test connectivity between services
- Observe blocked/allowed traffic in Hubble

### 3. Metrics and Monitoring
- Check Grafana dashboards for Cilium metrics
- View Prometheus targets and metrics
- Monitor application performance

### 4. Traffic Generation
- Use the "Generate Demo Traffic" buttons in the app
- Run: `hubble observe --namespace demo`
- Watch traffic patterns in real-time

## 🔧 Useful Commands

### Hubble CLI
```bash
# View all flows
hubble observe

# View flows for demo namespace
hubble observe --namespace demo

# View HTTP traffic only
hubble observe --protocol http

# View dropped packets
hubble observe --verdict DROPPED

# View flows between specific pods
hubble observe --from-pod demo/frontend --to-pod demo/backend
```

### Cilium CLI
```bash
# Check Cilium status
cilium status

# View network policies
cilium policy get

# Test connectivity
cilium connectivity test
```

### Kubernetes
```bash
# Monitor demo pods
kubectl get pods -n demo -w

# View network policies
kubectl get cnp -n demo -o yaml

# Check service endpoints
kubectl get endpoints -n demo

# View logs
kubectl logs -f deployment/backend -n demo
kubectl logs -f deployment/frontend -n demo
```

## 📊 Monitoring Dashboards

### Grafana Dashboards
1. **Cilium Network Overview** - Network flows, policy drops, endpoints
2. **Hubble Network Flows** - HTTP requests, DNS queries, service communication
3. **Demo Application Metrics** - Application-specific metrics

### Key Metrics
- Network flow rates (ingress/egress)
- Policy enforcement verdicts
- HTTP request rates and latency
- DNS query patterns
- Database connection metrics
- Service-to-service communication

## 🛡️ Network Policies

The demo includes several network policies:

- **Frontend Policy**: Allows ingress from world, egress to backend and external HTTPS
- **Backend Policy**: Allows ingress from frontend/traffic-generator, egress to database and external APIs
- **Database Policy**: Only allows ingress from backend
- **Traffic Generator Policy**: Allows egress to frontend and backend

## 🏗️ Application Components

### Frontend (React + TypeScript)
- Modern React application with Tailwind CSS
- Real-time dashboard with network metrics
- User and task management interfaces
- Traffic generation controls
- Links to observability tools

### Backend (Go + Gin)
- RESTful API with CRUD operations
- PostgreSQL database integration
- Prometheus metrics exposition
- Demo endpoints for traffic generation
- Health checks and monitoring

### Database (PostgreSQL)
- User and task data storage
- Sample data initialization
- Connection monitoring

### Traffic Generator
- Automated traffic generation for demo purposes
- Simulates realistic application usage
- Helps demonstrate network policies and flows

## 🔍 Observability Features

### Cilium/Hubble
- Layer 3/4 network visibility
- Layer 7 HTTP/DNS visibility
- Network policy enforcement
- Security event monitoring
- Flow logs and metrics

### Prometheus
- Application metrics collection
- Cilium and Hubble metrics
- Custom business metrics
- Alerting capabilities

### Grafana
- Pre-configured dashboards
- Real-time visualization
- Network topology views
- Performance monitoring

## 🧹 Cleanup

To remove the demo:

```bash
# Remove demo application
kubectl delete namespace demo

# Remove monitoring stack
helm uninstall prometheus -n monitoring
helm uninstall grafana -n monitoring
kubectl delete namespace monitoring

# Remove Cilium (optional - this will affect cluster networking)
helm uninstall cilium -n kube-system
```

## 🐛 Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource availability and image pull status
2. **Network policies too restrictive**: Temporarily disable with `kubectl delete cnp --all -n demo`
3. **Hubble not showing flows**: Ensure Hubble relay is running and accessible
4. **Grafana dashboards empty**: Check Prometheus service discovery and targets

### Debug Commands
```bash
# Check Cilium agent logs
kubectl logs -f ds/cilium -n kube-system

# Check Hubble relay status
kubectl logs -f deployment/hubble-relay -n kube-system

# Verify network connectivity
kubectl exec -it deployment/backend -n demo -- wget -qO- http://postgres:5432

# Check DNS resolution
kubectl exec -it deployment/backend -n demo -- nslookup postgres
```

## 📚 Learn More

- [Cilium Documentation](https://docs.cilium.io/)
- [Hubble Documentation](https://docs.cilium.io/en/stable/observability/hubble/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

---

**Happy networking with Cilium! 🕸️✨**