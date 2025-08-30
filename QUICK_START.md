# 🚀 Quick Start - Cilium Network Demo

## One-Command Deployment

```bash
./deploy-demo.sh
```

## What Gets Deployed

### 🕸️ Cilium + Hubble
- eBPF-based CNI with network observability
- Real-time flow monitoring
- L3/L4 and L7 traffic analysis
- Network policy enforcement

### 📊 Monitoring Stack
- Prometheus for metrics collection
- Grafana with pre-configured dashboards
- Service monitoring and alerting

### 🎯 Demo Application
- **Frontend**: React app with network dashboard
- **Backend**: Go API with Prometheus metrics
- **Database**: PostgreSQL with sample data
- **Traffic Generator**: Automated traffic for demo

## 🌐 Access After Deployment

| Service | URL | Purpose |
|---------|-----|---------|
| Demo App | http://localhost:32000 | Main application |
| Hubble UI | http://localhost:12000 | Network flows |
| Grafana | http://localhost:32003 | Dashboards |
| Prometheus | http://localhost:32002 | Metrics |

## 🎮 Demo Actions

1. **Generate Traffic**: Use buttons in demo app
2. **View Flows**: Check Hubble UI for real-time flows
3. **Monitor Metrics**: Explore Grafana dashboards
4. **Test Policies**: Try restricted connections

## 🧪 Testing

```bash
# Test deployment
./test-demo.sh

# Generate load
./k8s/demo-app/load-test.sh

# View live flows
hubble observe --namespace demo
```

## 🧹 Cleanup

```bash
./cleanup-demo.sh
```

---

**Get started in 5 minutes! 🎉**