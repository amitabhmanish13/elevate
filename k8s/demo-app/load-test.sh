#!/bin/bash

echo "🚀 Running load test to generate network traffic for Cilium demo"

# Function to make API calls
make_requests() {
    local endpoint=$1
    local count=${2:-10}
    
    echo "📡 Making $count requests to $endpoint..."
    for i in $(seq 1 $count); do
        curl -s "http://localhost:32000$endpoint" >/dev/null &
        sleep 0.1
    done
    wait
}

# Generate various types of traffic
echo "🎯 Generating diverse network traffic patterns..."

# Normal API traffic
make_requests "/api/v1/users" 20
make_requests "/api/v1/tasks" 15
make_requests "/health" 10

# Slow requests (for latency metrics)
echo "🐌 Generating slow requests..."
for i in {1..5}; do
    curl -s "http://localhost:32000/api/v1/demo/slow" >/dev/null &
done

# Error requests (for error rate metrics)
echo "❌ Generating error requests..."
for i in {1..8}; do
    curl -s "http://localhost:32000/api/v1/demo/error" >/dev/null &
done

# External calls (for egress traffic)
echo "🌐 Generating external calls..."
for i in {1..3}; do
    curl -s "http://localhost:32000/api/v1/demo/external" >/dev/null &
done

wait

echo "✅ Load test completed!"
echo ""
echo "🔍 Check the results in:"
echo "  📊 Grafana: http://localhost:32003"
echo "  🕸️  Hubble UI: http://localhost:12000"
echo "  📈 Prometheus: http://localhost:32002"
echo ""
echo "🧪 Or use CLI commands:"
echo "  hubble observe --namespace demo"
echo "  hubble observe --protocol http"
echo "  hubble observe --verdict DROPPED"