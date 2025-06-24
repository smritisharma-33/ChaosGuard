#!/bin/bash

set -e

GATEWAY_URL="http://$(minikube ip):30080"
PROMETHEUS_URL="http://$(minikube ip):30090"
GRAFANA_URL="http://$(minikube ip):30300"

echo "🏥 Running ChaosGuard Health Checks..."

# Function to check service health
check_service() {
    local service_name=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo "Checking $service_name..."
    
    response=$(curl -s -w "%{http_code}" -o /dev/null "$url" || echo "000")
    
    if [ "$response" -eq "$expected_status" ]; then
        echo "✅ $service_name is healthy (HTTP $response)"
        return 0
    else
        echo "❌ $service_name is unhealthy (HTTP $response)"
        return 1
    fi
}

# Function to check Kubernetes pods
check_pods() {
    echo "Checking Kubernetes pods..."
    
    local failed_pods=0
    
    while IFS= read -r line; do
        pod_name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $3}')
        
        if [[ "$status" == "Running" ]]; then
            echo "✅ Pod $pod_name is running"
        else
            echo "❌ Pod $pod_name is $status"
            ((failed_pods++))
        fi
    done < <(kubectl get pods -n chaosguard --no-headers)
    
    return $failed_pods
}

# Function to check service endpoints
check_endpoints() {
    echo "Checking service endpoints..."
    
    local failed=0
    
    # Check auth service
    check_service "Auth Service Health" "$GATEWAY_URL/auth/health" || ((failed++))
    
    # Check product service
    check_service "Product Service Health" "$GATEWAY_URL/products/health" || ((failed++))
    
    # Check payment service
    check_service "Payment Service Health" "$GATEWAY_URL/payment/health" || ((failed++))
    
    # Check gateway
    check_service "API Gateway" "$GATEWAY_URL/health" || ((failed++))
    
    return $failed
}

# Function to check monitoring services
check_monitoring() {
    echo "Checking monitoring services..."
    
    local failed=0
    
    # Check Prometheus
    check_service "Prometheus" "$PROMETHEUS_URL/-/healthy" || ((failed++))
    
    # Check Grafana
    check_service "Grafana" "$GRAFANA_URL/api/health" || ((failed++))
    
    return $failed
}

# Function to check metrics availability
check_metrics() {
    echo "Checking metrics availability..."
    
    local failed=0
    
    # Query some basic metrics
    local metrics=(
        "up"
        "auth_requests_total"
        "product_requests_total" 
        "payment_requests_total"
    )
    
    for metric in "${metrics[@]}"; do
        response=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=$metric" | jq -r '.status')
        if [[ "$response" == "success" ]]; then
            echo "✅ Metric '$metric' is available"
        else
            echo "❌ Metric '$metric' is not available"
            ((failed++))
        fi
    done
    
    return $failed
}

# Function to test basic functionality
test_functionality() {
    echo "Testing basic functionality..."
    
    local failed=0
    
    # Test auth login
    auth_response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"username":"test","password":"test"}' \
        "$GATEWAY_URL/auth/login")
    
    if [[ "$auth_response" == "200" || "$auth_response" == "401" ]]; then
        echo "✅ Auth service is responding"
    else
        echo "❌ Auth service test failed (HTTP $auth_response)"
        ((failed++))
    fi
    
    # Test product listing
    product_response=$(curl -s -o /dev/null -w "%{http_code}" \
        "$GATEWAY_URL/products/products")
    
    if [[ "$product_response" == "200" ]]; then
        echo "✅ Product service is responding"
    else
        echo "❌ Product service test failed (HTTP $product_response)"
        ((failed++))
    fi
    
    return $failed
}

# Main health check execution
main() {
    local total_failed=0
    
    echo "================================================"
    echo "ChaosGuard Health Check Report"
    echo "Timestamp: $(date)"
    echo "================================================"
    echo ""
    
    # Run all health checks
    check_pods || ((total_failed+=$?))
    echo ""
    
    check_endpoints || ((total_failed+=$?))
    echo ""
    
    check_monitoring || ((total_failed+=$?))
    echo ""
    
    check_metrics || ((total_failed+=$?))
    echo ""
    
    test_functionality || ((total_failed+=$?))
    echo ""
    
    # Final report
    echo "================================================"
    if [ $total_failed -eq 0 ]; then
        echo "🎉 All health checks passed!"
        echo "System Status: HEALTHY ✅"
    else
        echo "⚠️  $total_failed health check(s) failed"
        echo "System Status: DEGRADED ❌"
    fi
    echo "================================================"
    
    return $total_failed
}

# Run health checks
main
exit $?