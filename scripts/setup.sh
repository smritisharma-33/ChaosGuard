#!/bin/bash

set -e

echo "🚀 Setting up ChaosGuard..."

# Check prerequisites
command -v minikube >/dev/null 2>&1 || { echo "minikube is required but not installed. Aborting." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "docker is required but not installed. Aborting." >&2; exit 1; }

# Start minikube if not running
if ! minikube status >/dev/null 2>&1; then
    echo "Starting minikube..."
    minikube start --cpus=4 --memory=8192 --disk-size=20g
fi

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server

# Set docker environment
eval $(minikube docker-env)

echo "✅ Prerequisites setup complete"

# Build Docker images
echo "🐳 Building Docker images..."

docker build -t chaosguard/auth-service:latest services/auth-service/
docker build -t chaosguard/product-service:latest services/product-service/
docker build -t chaosguard/payment-service:latest services/payment-service/

echo "✅ Docker images built"

# Install LitmusChaos
echo "⚡ Installing LitmusChaos..."

kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.8.0.yaml

# Wait for LitmusChaos to be ready
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=litmus --timeout=300s -n litmus

echo "✅ LitmusChaos installed"

# Install Argo Workflows (for chaos orchestration)
echo "🔄 Installing Argo Workflows..."

kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.4/install.yaml

# Wait for Argo to be ready
kubectl wait --for=condition=Ready pods -l app=workflow-controller --timeout=300s -n argo

echo "✅ Argo Workflows installed"

echo "🎉 Setup complete! Run './scripts/deploy.sh' to deploy the application."