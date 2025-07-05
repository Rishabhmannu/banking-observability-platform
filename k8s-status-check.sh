#!/bin/bash
echo "🔍 Kubernetes Health Check"
echo "========================="
echo "1. Cluster: $(kubectl get nodes --no-headers | awk '{print $2}' | head -1)"
echo "2. Pods: $(kubectl get pods -n banking-k8s-test --no-headers | grep -c Running)/$(kubectl get pods -n banking-k8s-test --no-headers | wc -l) running"
echo "3. HPA: $(kubectl get hpa -n banking-k8s-test --no-headers | awk '{print $3 " " $7 "/" $6 " replicas"}')"
echo "4. Resource Monitor: $(curl -s http://localhost:9419/metrics >/dev/null && echo "✅ UP" || echo "❌ DOWN")"
echo "5. Metrics Server: $(kubectl top nodes >/dev/null 2>&1 && echo "✅ UP" || echo "❌ DOWN")"