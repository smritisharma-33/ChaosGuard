.PHONY: help setup deploy test chaos clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Setup the development environment
	@echo "🚀 Setting up ChaosGuard..."
	chmod +x scripts/*.sh
	./scripts/setup.sh

deploy: ## Deploy the application to Kubernetes
	@echo "🚀 Deploying ChaosGuard..."
	./scripts/deploy.sh

test: ## Run load tests
	@echo "🧪 Running load tests..."
	k6 run tests/load-test.js

chaos: ## Run chaos experiments
	@echo "⚡ Running chaos experiments..."
	./scripts/chaos-runner.sh all

chaos-pod: ## Run pod failure experiment
	@echo "⚡ Running pod failure experiment..."
	./scripts/chaos-runner.sh pod-failure

chaos-network: ## Run network latency experiment
	@echo "⚡ Running network latency experiment..."
	./scripts/chaos-runner.sh network-latency

chaos-cpu: ## Run CPU stress experiment
	@echo "⚡ Running CPU stress experiment..."
	./scripts/chaos-runner.sh cpu-stress

status: ## Check cluster status
	@echo "📊 Checking cluster status..."
	kubectl get pods -n chaosguard
	kubectl get svc -n chaosguard
	@echo ""
	@echo "🌐 Access URLs:"
	@echo "API Gateway: http://$(shell minikube ip):30080"
	@echo "Prometheus: http://$(shell minikube ip):30090"
	@echo "Grafana: http://$(shell minikube ip):30300"

logs: ## Show service logs
	@echo "📝 Showing recent logs..."
	kubectl logs -l app=auth-service -n chaosguard --tail=50
	kubectl logs -l app=product-service -n chaosguard --tail=50
	kubectl logs -l app=payment-service -n chaosguard --tail=50

clean: ## Clean up resources
	@echo "🧹 Cleaning up..."
	kubectl delete namespace chaosguard || true
	kubectl delete namespace litmus || true
	kubectl delete namespace argo || true
	minikube stop || true

restart: clean setup deploy ## Clean and restart everything

build: ## Build Docker images
	@echo "🐳 Building Docker images..."
	eval $$(minikube docker-env) && \
	docker build -t chaosguard/auth-service:latest services/auth-service/ && \
	docker build -t chaosguard/product-service:latest services/product-service/ && \
	docker build -t chaosguard/payment-service:latest services/payment-service/

port-forward: ## Setup port forwarding for local access
	@echo "🔗 Setting up port forwarding..."
	kubectl port-forward svc/prometheus 9090:9090 -n chaosguard &
	kubectl port-forward svc/grafana 3000:3000 -n chaosguard &
	kubectl port-forward svc/api-gateway 8080:80 -n chaosguard &
	@echo "Services available at:"
	@echo "  Prometheus: http://localhost:9090"
	@echo "  Grafana: http://localhost:3000"
	@echo "  API Gateway: http://localhost:8080"