#!/bin/bash

echo "🧪 Testing Cilium Network Observability Demo"
echo "============================================"

# Function to check if service is accessible
check_service() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo -n "Testing $name... "
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$status" = "$expected_status" ]; then
        echo "✅ OK ($status)"
        return 0
    else
        echo "❌ FAIL ($status)"
        return 1
    fi
}

# Function to check if kubectl resource exists
check_k8s_resource() {
    local resource=$1
    local namespace=${2:-default}
    
    echo -n "Checking $resource in $namespace... "
    if kubectl get $resource -n $namespace >/dev/null 2>&1; then
        echo "✅ OK"
        return 0
    else
        echo "❌ FAIL"
        return 1
    fi
}

echo "🔍 Checking Kubernetes resources..."

# Check namespaces
check_k8s_resource "namespace demo"
check_k8s_resource "namespace monitoring"

# Check Cilium
echo -n "Checking Cilium pods... "
cilium_ready=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$cilium_ready" -gt 0 ]; then
    echo "✅ OK ($cilium_ready pods running)"
else
    echo "❌ FAIL (no Cilium pods running)"
fi

# Check demo application pods
echo -n "Checking demo app pods... "
demo_ready=$(kubectl get pods -n demo --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$demo_ready" -gt 0 ]; then
    echo "✅ OK ($demo_ready pods running)"
else
    echo "❌ FAIL (no demo pods running)"
fi

# Check monitoring pods
echo -n "Checking monitoring pods... "
monitoring_ready=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$monitoring_ready" -gt 0 ]; then
    echo "✅ OK ($monitoring_ready pods running)"
else
    echo "❌ FAIL (no monitoring pods running)"
fi

echo ""
echo "🌐 Testing service accessibility..."

# Wait a moment for services to be ready
sleep 5

# Test services
check_service "Demo Application" "http://localhost:32000"
check_service "Hubble UI" "http://localhost:12000"
check_service "Grafana" "http://localhost:32003"
check_service "Prometheus" "http://localhost:32002"

echo ""
echo "🔗 Testing API endpoints..."

# Test backend API endpoints
check_service "Backend Health" "http://localhost:32000/health"
check_service "Backend Users API" "http://localhost:32000/api/v1/users"
check_service "Backend Tasks API" "http://localhost:32000/api/v1/tasks"
check_service "Backend Metrics" "http://localhost:32000/metrics"

echo ""
echo "🧪 Testing network policies..."

# Test if Hubble is observing flows
echo -n "Testing Hubble flow observation... "
if command -v hubble >/dev/null 2>&1; then
    flows=$(timeout 5s hubble observe --count 1 2>/dev/null || echo "")
    if [ -n "$flows" ]; then
        echo "✅ OK (flows observed)"
    else
        echo "⚠️  WARNING (no flows observed yet)"
    fi
else
    echo "⚠️  WARNING (hubble CLI not installed)"
fi

echo ""
echo "📊 Testing traffic generation..."

# Generate some test traffic
echo "Generating test traffic..."
curl -s "http://localhost:32000/api/v1/demo/slow" >/dev/null 2>&1 &
curl -s "http://localhost:32000/api/v1/demo/error" >/dev/null 2>&1 &
curl -s "http://localhost:32000/api/v1/demo/external" >/dev/null 2>&1 &

echo "✅ Test traffic generated"

echo ""
echo "📋 Summary:"
echo "=========="
kubectl get pods -A | grep -E "(cilium|hubble|prometheus|grafana|demo)"

echo ""
echo "🎯 Next steps:"
echo "  1. Open http://localhost:32000 - Demo Application"
echo "  2. Open http://localhost:12000 - Hubble UI for network flows"
echo "  3. Open http://localhost:32003 - Grafana dashboards (admin/admin123)"
echo "  4. Run 'hubble observe --namespace demo' to see live flows"
echo "  5. Generate traffic using the demo app buttons"
echo ""
echo "🔍 For troubleshooting, check:"
echo "  kubectl logs -f ds/cilium -n kube-system"
echo "  kubectl get cnp -n demo"
echo "  kubectl describe pod <pod-name> -n demo"