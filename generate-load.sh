#!/bin/bash
echo "🚀 Generating load to create monitoring data..."

BASE_URL="http://localhost:8080"

# Function to make requests
make_requests() {
    local endpoint=$1
    local method=${2:-GET}
    local data=${3:-""}
    
    for i in {1..10}; do
        if [ "$method" = "POST" ]; then
            curl -s -X POST "$BASE_URL$endpoint" \
                -H "Content-Type: application/json" \
                -d "$data" > /dev/null
        else
            curl -s "$BASE_URL$endpoint" > /dev/null
        fi
        echo -n "."
        sleep 0.5
    done
    echo ""
}

echo "Generating traffic patterns..."

while true; do
    echo "🔐 Testing auth service..."
    make_requests "/auth/health"
    make_requests "/auth/login" "POST" '{"username":"user'$RANDOM'","password":"pass123"}'
    
    echo "📦 Testing product service..."
    make_requests "/products/health"
    make_requests "/products/products"
    make_requests "/products/products/1"
    make_requests "/products/products/2"
    
    echo "💳 Testing payment service..."
    make_requests "/payment/health"
    make_requests "/payment/process" "POST" '{"amount":'$((RANDOM % 1000 + 10))',"currency":"USD","card_token":"test_token","user_id":"user_'$RANDOM'"}'
    
    echo "😴 Sleeping for 10 seconds..."
    sleep 10
done
