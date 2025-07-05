#!/bin/bash
echo "🚀 Starting Kubernetes Monitoring Services..."

# Start kube-state-metrics port-forward
kubectl port-forward -n kube-system svc/kube-state-metrics 8080:8080 &
echo "✅ kube-state-metrics port-forward started (port 8080)"

# Start k8s-resource-monitor port-forward  
kubectl port-forward -n banking-k8s-test svc/k8s-resource-monitor 9419:9419 &
echo "✅ k8s-resource-monitor port-forward started (port 9419)"

echo "🎉 All monitoring services started!"
echo "📊 Check Prometheus targets: http://localhost:9090/targets"
echo "📈 Check Grafana dashboards: http://localhost:3000"

# Keep script running
wait