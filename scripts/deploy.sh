#!/bin/bash

set -e

echo "🚀 Deploying ChaosGuard application..."

# Create namespace
kubectl apply -f k8s/namespace.yaml

# Deploy services
kubectl apply -f k8s/auth-service.yaml
kubectl apply -f k8s/product-service.yaml
kubectl apply -f k8s/payment-service.yaml
kubectl apply -f k8s/gateway.yaml

# Deploy monitoring
kubectl apply -f k8s/monitoring/prometheus.yaml
kubectl apply -f k8s/monitoring/grafana.yaml

# Create LitmusChaos service account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: litmus-admin
  namespace: chaosguard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: litmus-admin
rules:
- apiGroups: [""]
  resources: ["pods","events","configmaps","secrets","nodes","services"]
  verbs: ["create","delete","get","list","patch","update","watch"]
- apiGroups: ["apps"]
  resources: ["deployments","daemonsets","replicasets","statefulsets"]
  verbs: ["create","delete","get","list","patch","update","watch"]
- apiGroups: ["litmuschaos.io"]
  resources: ["chaosengines","chaosexperiments","chaosresults"]
  verbs: ["create","delete","get","list","patch","update","watch"]
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["create","delete","get","list","patch","update","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: litmus-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: litmus-admin
subjects:
- kind: ServiceAccount
  name: litmus-admin
  namespace: chaosguard
EOF

# Install chaos experiments
kubectl apply -f chaos/pod-failure.yaml
kubectl apply -f chaos/network-latency.yaml
kubectl apply -f chaos/cpu-stress.yaml

# Wait for deployments to be ready
echo "⏳ Waiting for deployments..."
kubectl wait --for=condition=available --timeout=300s deployment/auth-service -n chaosguard
kubectl wait --for=condition=available --timeout=300s deployment/product-service -n chaosguard
kubectl wait --for=condition=available --timeout=300s deployment/payment-service -n chaosguard
kubectl wait --for=condition=available --timeout=300s deployment/api-gateway -n chaosguard
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n chaosguard
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n chaosguard

echo "✅ Deployment complete!"

# Display access information
echo ""
echo "🌐 Access URLs:"
echo "API Gateway: http://$(minikube ip):30080"
echo "Prometheus: http://$(minikube ip):30090"
echo "Grafana: http://$(minikube ip):30300 (admin/admin123)"
echo ""
echo "🧪 To run chaos experiments: ./scripts/chaos-runner.sh"