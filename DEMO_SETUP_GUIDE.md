# 🕸️ Cilium Network Observability Demo - Setup Guide

## 📋 Overview

This demo provides a complete environment showcasing:
- **Cilium CNI** with eBPF-based networking
- **Hubble** for real-time network observability
- **Prometheus** for metrics collection
- **Grafana** for visualization
- **Sample Application** demonstrating network flows

## 🎯 What You'll Learn

- How to deploy Cilium with Hubble for network observability
- Network policy enforcement and visualization
- Real-time network flow monitoring
- Integration with Prometheus and Grafana
- L3/L4 and L7 traffic analysis

## 🛠️ Prerequisites

### Required Tools
```bash
# Kubernetes cluster (one of the following)
kind create cluster --name cilium-demo
# OR
minikube start --memory=8192 --cpus=4
# OR use existing cluster

# Required CLI tools
kubectl version --client
helm version
docker version
```

### System Requirements
- 8GB+ RAM
- 4+ CPU cores
- 20GB+ disk space
- Internet connectivity

## 🚀 Quick Start (Automated)

### Option 1: Full Automated Deployment
```bash
# Clone and deploy everything
git clone <this-repo>
cd <repo-directory>
./deploy-demo.sh
```

### Option 2: Step-by-Step Manual Deployment

#### Step 1: Install Cilium with Hubble
```bash
cd k8s/cilium
./install-cilium.sh
```

#### Step 2: Install Monitoring Stack
```bash
cd ../monitoring
./install-monitoring.sh
```

#### Step 3: Build and Deploy Demo App
```bash
cd ../demo-app
./build-images.sh
./deploy-app.sh
```

#### Step 4: Apply Network Policies
```bash
cd ../network-policies
kubectl apply -f .
```

## 🌐 Access Points

After successful deployment:

| Component | URL | Purpose |
|-----------|-----|---------|
| **Demo App** | http://localhost:32000 | Main application interface |
| **Hubble UI** | http://localhost:12000 | Network flow visualization |
| **Grafana** | http://localhost:32003 | Metrics dashboards |
| **Prometheus** | http://localhost:32002 | Metrics collection |

### Default Credentials
- **Grafana**: admin / admin123

## 🎮 Demo Scenarios

### Scenario 1: Basic Network Visibility
1. Open the Demo App at http://localhost:32000
2. Navigate between Users and Tasks pages
3. Open Hubble UI to see HTTP flows
4. Observe service-to-service communication

### Scenario 2: Traffic Generation
1. In the Demo App, click "Generate Demo Traffic" buttons
2. Watch real-time flows in Hubble UI
3. Check Grafana dashboards for metrics
4. Run CLI: `hubble observe --namespace demo`

### Scenario 3: Network Policy Testing
1. View current policies: `kubectl get cnp -n demo`
2. Try to access restricted endpoints
3. Observe blocked traffic in Hubble
4. Modify policies and test changes

### Scenario 4: L7 HTTP Monitoring
1. Generate HTTP traffic through the app
2. Use: `hubble observe --protocol http`
3. View HTTP metrics in Grafana
4. Analyze request patterns and response codes

### Scenario 5: Security Monitoring
1. Generate error traffic using demo buttons
2. Monitor dropped packets: `hubble observe --verdict DROPPED`
3. Check security events in dashboards
4. Analyze policy enforcement

## 🔧 Advanced Configuration

### Custom Network Policies
```bash
# Edit network policies
kubectl edit cnp frontend-policy -n demo

# Test connectivity
kubectl exec -it deployment/frontend -n demo -- wget -qO- http://backend:8080/health
```

### Hubble Configuration
```bash
# Enable additional flow types
hubble observe --type drop --type trace

# Filter by specific services
hubble observe --from-service demo/frontend --to-service demo/backend

# Export flows to file
hubble observe --output json > flows.json
```

### Grafana Dashboard Customization
1. Login to Grafana (admin/admin123)
2. Go to Dashboards → Browse
3. Import additional dashboards from grafana.com
4. Customize panels and queries

## 📊 Key Metrics to Monitor

### Network Metrics
- Flow rates (ingress/egress)
- Connection counts
- Policy verdicts (allow/deny)
- Latency distributions

### Application Metrics
- HTTP request rates
- Response times
- Error rates
- Database connections

### Security Metrics
- Policy violations
- Dropped packets
- Blocked connections
- Anomalous traffic patterns

## 🐛 Troubleshooting

### Common Issues

#### Pods Not Starting
```bash
# Check pod status
kubectl get pods -n demo
kubectl describe pod <pod-name> -n demo

# Check logs
kubectl logs -f deployment/backend -n demo
```

#### Network Connectivity Issues
```bash
# Check Cilium status
cilium status

# Test connectivity
cilium connectivity test

# Check network policies
kubectl get cnp -n demo -o yaml
```

#### Hubble Not Showing Flows
```bash
# Check Hubble relay
kubectl logs -f deployment/hubble-relay -n kube-system

# Restart Hubble UI port-forward
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

#### Grafana Dashboards Empty
```bash
# Check Prometheus targets
curl http://localhost:32002/targets

# Verify service monitors
kubectl get servicemonitor -n monitoring
```

### Debug Commands
```bash
# View all network policies
kubectl get cnp -A

# Check service endpoints
kubectl get endpoints -n demo

# Monitor events
kubectl get events -n demo --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top pods -n demo
```

## 🧪 Testing Scenarios

### Generate Load
```bash
# Run comprehensive load test
./k8s/demo-app/load-test.sh

# Or manual testing
for i in {1..100}; do
  curl -s http://localhost:32000/api/v1/users >/dev/null &
done
```

### Test Network Policies
```bash
# Try to access database directly (should fail)
kubectl exec -it deployment/frontend -n demo -- nc -zv postgres 5432

# Test allowed connections
kubectl exec -it deployment/backend -n demo -- nc -zv postgres 5432
```

## 📚 Learning Resources

### Cilium Documentation
- [Getting Started](https://docs.cilium.io/en/stable/gettingstarted/)
- [Network Policies](https://docs.cilium.io/en/stable/policy/)
- [Hubble Observability](https://docs.cilium.io/en/stable/observability/hubble/)

### Best Practices
- Start with permissive policies, then tighten
- Monitor before enforcing policies
- Use labels for policy targeting
- Regular security audits

## 🎓 Demo Script

For presentations, follow this flow:

1. **Introduction** (5 min)
   - Show architecture diagram
   - Explain Cilium and eBPF benefits

2. **Basic Connectivity** (10 min)
   - Deploy application
   - Show normal traffic flows
   - Demonstrate Hubble UI

3. **Network Policies** (10 min)
   - Apply security policies
   - Show blocked traffic
   - Demonstrate policy enforcement

4. **Observability** (10 min)
   - Explore Grafana dashboards
   - Show Prometheus metrics
   - Analyze traffic patterns

5. **Advanced Features** (5 min)
   - L7 HTTP monitoring
   - DNS observability
   - Security events

## 🧹 Cleanup

```bash
# Full cleanup
./cleanup-demo.sh

# Partial cleanup (keep Cilium)
kubectl delete namespace demo monitoring
```

---

**Ready to explore network observability with Cilium! 🎉**