# ChaosGuard - Chaos Engineering Simulation Platform

A comprehensive chaos engineering platform for testing microservices resilience with automated incident response and reporting.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![LitmusChaos](https://img.shields.io/badge/LitmusChaos-3.0+-green.svg)](https://litmuschaos.io/)

## 🎯 Overview

ChaosGuard provides a complete chaos engineering ecosystem featuring:

- **Mock E-commerce Microservices**: Auth, Product, and Payment services
- **Kubernetes Deployment**: Full containerized deployment on Minikube
- **Chaos Experiments**: Pod failures, network latency, and CPU stress testing
- **Comprehensive Monitoring**: Prometheus metrics and Grafana dashboards
- **Automated Reporting**: AI-generated RCA reports with actionable insights
- **CI/CD Integration**: GitHub Actions workflow for automated testing

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Auth Service  │    │ Product Service │    │ Payment Service │
│     (Go)        │    │      (Go)       │    │      (Go)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                        ┌─────────────────┐
                        │  API Gateway    │
                        │    (Nginx)      │
                        └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │   Kubernetes    │
                        │   (Minikube)    │
                        └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  LitmusChaos    │    │   Prometheus    │    │     Grafana     │
│ (Experiments)   │    │  (Metrics)      │    │  (Dashboards)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Project Structure

```
chaosguard/
├── README.md
├── Makefile
├── docker-compose.yml
├── .github/
│   └── workflows/
│       └── chaos-experiment.yml
├── services/
│   ├── auth-service/
│   │   ├── Dockerfile
│   │   ├── main.go
│   │   ├── go.mod
│   │   └── go.sum
│   ├── product-service/
│   │   ├── Dockerfile
│   │   ├── main.go
│   │   ├── go.mod
│   │   └── go.sum
│   └── payment-service/
│       ├── Dockerfile
│       ├── main.go
│       ├── go.mod
│       └── go.sum
├── k8s/
│   ├── namespace.yaml
│   ├── auth-service.yaml
│   ├── product-service.yaml
│   ├── payment-service.yaml
│   ├── gateway.yaml
│   └── monitoring/
│       ├── prometheus.yaml
│       ├── grafana.yaml
│       └── service-monitor.yaml
├── chaos/
│   ├── pod-failure.yaml
│   ├── network-latency.yaml
│   ├── cpu-stress.yaml
│   └── chaos-workflow.yaml
├── monitoring/
│   ├── prometheus.yml
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── chaos-overview.json
│   │   │   └── slo-dashboard.json
│   │   └── provisioning/
│   │       ├── dashboards/
│   │       │   └── dashboard.yml
│   │       └── datasources/
│   │           └── prometheus.yml
│   └── alert-rules.yml
├── scripts/
│   ├── setup.sh
│   ├── deploy.sh
│   ├── chaos-runner.sh
│   └── rca-generator.py
├── tests/
│   ├── load-test.js
│   └── health-check.sh
└── reports/
    └── template-rca.md
```

## 🚀 Quick Start

### Prerequisites

Ensure you have the following installed:

- [Docker](https://docs.docker.com/get-docker/) (v20.10+)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) (v1.32+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (v1.28+)
- [Go](https://golang.org/doc/install) (v1.21+)
- [Python](https://www.python.org/downloads/) (v3.9+)
- [k6](https://k6.io/docs/get-started/installation/) (for load testing)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-org/chaosguard.git
   cd chaosguard
   ```

2. **Setup the environment:**
   ```bash
   make setup
   ```

3. **Deploy the application:**
   ```bash
   make deploy
   ```

4. **Verify deployment:**
   ```bash
   make status
   ```

### Access the Services

Once deployed, you can access:

- **API Gateway**: `http://$(minikube ip):30080`
- **Prometheus**: `http://$(minikube ip):30090`
- **Grafana**: `http://$(minikube ip):30300` (admin/admin123)

## 🧪 Running Chaos Experiments

### Individual Experiments

```bash
# Run pod failure experiment
make chaos-pod

# Run network latency experiment  
make chaos-network

# Run CPU stress experiment
make chaos-cpu
```

### Full Chaos Suite

```bash
# Run all experiments sequentially
make chaos
```

### Custom Experiment Duration

```bash
# Run with custom duration (in seconds)
./scripts/chaos-runner.sh pod-failure 300
```

## 📊 Monitoring & Observability

### Service Level Objectives (SLOs)

ChaosGuard monitors these SLOs:

| Metric | SLO | Alert Threshold |
|--------|-----|----------------|
| Error Rate | < 1% | > 0.5% |
| P95 Latency | < 1000ms | > 800ms |
| Availability | > 99.9% | < 99.5% |

### Key Metrics

- **Request Rate**: Requests per second across all services
- **Error Rate**: 5xx error rate by service
- **Latency**: P50, P95, P99 response times
- **Resource Usage**: CPU, memory, network I/O
- **Service Health**: Health check status

### Dashboards

Access Grafana dashboards:

1. **SLO Dashboard**: Real-time SLO compliance
2. **Chaos Overview**: Chaos experiment impact
3. **Service Metrics**: Detailed service performance

## 🔬 Load Testing

Run performance tests alongside chaos experiments:

```bash
# Basic load test
make test

# Custom load test
k6 run tests/load-test.js --duration 5m --vus 50
```

## 📋 Automated Reporting

ChaosGuard automatically generates comprehensive RCA reports:

```bash
# Generate RCA report
python3 scripts/rca-generator.py
```

Reports include:

- **Executive Summary**: High-level incident overview
- **Experiment Results**: Detailed chaos experiment outcomes
- **Metrics Analysis**: SLO breach analysis and trends
- **Root Cause Analysis**: AI-generated insights
- **Recommendations**: Actionable mitigation strategies
- **Follow-up Actions**: Tracked improvement tasks

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CHAOS_DURATION` | Default experiment duration | `300s` |
| `PROMETHEUS_URL` | Prometheus endpoint | `http://localhost:30090` |
| `GRAFANA_URL` | Grafana endpoint | `http://localhost:30300` |

### Customizing Experiments

Edit chaos experiment files in `chaos/` directory:

- `pod-failure.yaml`: Pod deletion parameters
- `network-latency.yaml`: Network latency injection
- `cpu-stress.yaml`: CPU stress testing

### Adding New Services

1. Create service directory under `services/`
2. Add Dockerfile and Kubernetes manifests
3. Update `k8s/` with service deployment
4. Add Prometheus metrics endpoints
5. Include in chaos experiments

## 🔄 CI/CD Integration

### GitHub Actions

The included workflow (`.github/workflows/chaos-experiment.yml`) provides:

- **Scheduled Experiments**: Weekly chaos testing
- **Manual Triggers**: On-demand experiment execution
- **Automated Reporting**: RCA report generation
- **Alert Integration**: Slack/email notifications
- **Issue Creation**: Automatic incident tracking

### Local Development Workflow

```bash
# Development cycle
make build      # Build Docker images
make deploy     # Deploy to Minikube
make test       # Run load tests
make chaos      # Execute chaos experiments
make clean      # Clean up resources
```

## 🛠️ Troubleshooting

### Common Issues

**Minikube not starting:**
```bash
minikube delete
minikube start --cpus=4 --memory=8192
```

**Services not accessible:**
```bash
# Check service status
kubectl get pods -n chaosguard
kubectl get svc -n chaosguard

# View logs
make logs
```

**Chaos experiments failing:**
```bash
# Check LitmusChaos installation
kubectl get pods -n litmus

# Verify service account permissions
kubectl get clusterrolebinding litmus-admin
```

**Prometheus metrics missing:**
```bash
# Verify service discovery
kubectl get servicemonitor -n chaosguard

# Check metric endpoints
curl http://$(minikube ip):30080/auth/metrics
```

### Health Checks

Run comprehensive health checks:

```bash
# Automated health verification
./tests/health-check.sh
```

### Debug Mode

Enable verbose logging:

```bash
export DEBUG=1
make deploy
```

## 📚 Documentation

### API Endpoints

**Auth Service:**
- `POST /login` - User authentication
- `POST /validate` - Token validation
- `GET /health` - Health check

**Product Service:**
- `GET /products` - List all products
- `GET /products/{id}` - Get specific product
- `GET /health` - Health check

**Payment Service:**
- `POST /process` - Process payment
- `GET /health` - Health check

### Metrics Endpoints

All services expose Prometheus metrics at `/metrics`:
- Request counts and rates
- Response time histograms
- Error rates by status code
- Service health status

## 🙏 Acknowledgments

- [LitmusChaos](https://litmuschaos.io/) for chaos engineering framework
- [Prometheus](https://prometheus.io/) for metrics collection
- [Grafana](https://grafana.com/) for visualization
- [Kubernetes](https://kubernetes.io/) for container orchestration

---

*Happy Chaos Engineering! 🔥*