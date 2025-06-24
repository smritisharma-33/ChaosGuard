import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";

// Custom metrics
const errorRate = new Rate('errors');
const authLatency = new Trend('auth_duration');
const productLatency = new Trend('product_duration');
const paymentLatency = new Trend('payment_duration');
const requestCount = new Counter('requests_total');

export let options = {
  stages: [
    { duration: '1m', target: 5 },   // Warm up
    { duration: '2m', target: 10 },  // Ramp up to 10 users
    { duration: '3m', target: 25 },  // Ramp up to 25 users  
    { duration: '2m', target: 50 },  // Ramp up to 50 users
    { duration: '5m', target: 50 },  // Stay at 50 users for 5 minutes
    { duration: '2m', target: 25 },  // Ramp down to 25 users
    { duration: '2m', target: 10 },  // Ramp down to 10 users
    { duration: '1m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'], // 95% of requests under 1s
    http_req_failed: ['rate<0.01'],    // Error rate under 1%
    errors: ['rate<0.01'],             // Custom error rate under 1%
    auth_duration: ['p(95)<500'],      // Auth service latency
    product_duration: ['p(95)<300'],   // Product service latency  
    payment_duration: ['p(95)<800'],   // Payment service latency
  },
};

// Get base URL from environment or use default
const BASE_URL = __ENV.BASE_URL || 'http://localhost:30080';

// Test data
const users = [
  { username: 'alice', password: 'password123' },
  { username: 'bob', password: 'securepass' },
  { username: 'charlie', password: 'mypassword' },
  { username: 'diana', password: 'testpass' },
  { username: 'eve', password: 'userpass' },
];

const products = [1, 2, 3, 4, 5];

const paymentData = [
  { amount: 29.99, currency: 'USD', card_token: 'tok_visa_4242' },
  { amount: 79.99, currency: 'USD', card_token: 'tok_mc_5555' },
  { amount: 199.99, currency: 'EUR', card_token: 'tok_amex_3782' },
  { amount: 299.99, currency: 'USD', card_token: 'tok_discover_6011' },
  { amount: 999.99, currency: 'USD', card_token: 'tok_visa_4000' },
];

// Utility function to select random item from array
function randomChoice(array) {
  return array[Math.floor(Math.random() * array.length)];
}

// Test authentication service
function testAuthService() {
  const user = randomChoice(users);
  const payload = JSON.stringify(user);
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    tags: { service: 'auth', endpoint: 'login' },
  };

  const response = http.post(`${BASE_URL}/auth/login`, payload, params);
  
  authLatency.add(response.timings.duration);
  requestCount.add(1);
  
  const success = check(response, {
    'auth login status is 200 or 401': (r) => [200, 401].includes(r.status),
    'auth response has token on success': (r) => 
      r.status === 401 || (r.status === 200 && JSON.parse(r.body).token),
    'auth response time < 1s': (r) => r.timings.duration < 1000,
  });
  
  if (!success) {
    errorRate.add(1);
  }
  
  return response.status === 200 ? JSON.parse(response.body).token : null;
}

// Test token validation
function testTokenValidation(token) {
  if (!token) return false;
  
  const params = {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    tags: { service: 'auth', endpoint: 'validate' },
  };

  const response = http.post(`${BASE_URL}/auth/validate`, '{}', params);
  
  requestCount.add(1);
  
  const success = check(response, {
    'token validation status is 200 or 401': (r) => [200, 401].includes(r.status),
    'token validation response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  if (!success) {
    errorRate.add(1);
  }
  
  return response.status === 200;
}

// Test product service
function testProductService() {
  // Test product listing
  let response = http.get(`${BASE_URL}/products/products`, {
    tags: { service: 'product', endpoint: 'list' },
  });
  
  productLatency.add(response.timings.duration);
  requestCount.add(1);
  
  let success = check(response, {
    'product list status is 200': (r) => r.status === 200,
    'product list has products': (r) => JSON.parse(r.body).length > 0,
    'product list response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  if (!success) {
    errorRate.add(1);
  }
  
  // Test individual product fetch
  const productId = randomChoice(products);
  response = http.get(`${BASE_URL}/products/products/${productId}`, {
    tags: { service: 'product', endpoint: 'get' },
  });
  
  productLatency.add(response.timings.duration);
  requestCount.add(1);
  
  success = check(response, {
    'product get status is 200 or 404': (r) => [200, 404].includes(r.status),
    'product get response time < 300ms': (r) => r.timings.duration < 300,
    'product has required fields': (r) => {
      if (r.status === 200) {
        const product = JSON.parse(r.body);
        return product.id && product.name && product.price !== undefined;
      }
      return true;
    },
  });
  
  if (!success) {
    errorRate.add(1);
  }
}

// Test payment service
function testPaymentService(token) {
  const payment = randomChoice(paymentData);
  const payload = JSON.stringify({
    ...payment,
    user_id: 'load_test_user',
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    tags: { service: 'payment', endpoint: 'process' },
  };
  
  // Add auth header if token available
  if (token) {
    params.headers['Authorization'] = `Bearer ${token}`;
  }

  const response = http.post(`${BASE_URL}/payment/process`, payload, params);
  
  paymentLatency.add(response.timings.duration);
  requestCount.add(1);
  
  const success = check(response, {
    'payment status is 200 or 400': (r) => [200, 400].includes(r.status),
    'payment response time < 1s': (r) => r.timings.duration < 1000,
    'payment has transaction_id on success': (r) => 
      r.status === 400 || (r.status === 200 && JSON.parse(r.body).transaction_id),
  });
  
  if (!success) {
    errorRate.add(1);
  }
}

// Test health endpoints
function testHealthEndpoints() {
  const endpoints = [
    { url: `${BASE_URL}/auth/health`, service: 'auth' },
    { url: `${BASE_URL}/products/health`, service: 'product' },
    { url: `${BASE_URL}/payment/health`, service: 'payment' },
    { url: `${BASE_URL}/health`, service: 'gateway' },
  ];
  
  endpoints.forEach(endpoint => {
    const response = http.get(endpoint.url, {
      tags: { service: endpoint.service, endpoint: 'health' },
    });
    
    requestCount.add(1);
    
    const success = check(response, {
      [`${endpoint.service} health status is 200`]: (r) => r.status === 200,
      [`${endpoint.service} health response time < 200ms`]: (r) => r.timings.duration < 200,
    });
    
    if (!success) {
      errorRate.add(1);
    }
  });
}

// Main test function
export default function() {
  // Simulate realistic user behavior
  const scenario = Math.random();
  
  if (scenario < 0.1) {
    // 10% of traffic: Just health checks (monitoring)
    testHealthEndpoints();
  } else if (scenario < 0.3) {
    // 20% of traffic: Browse products only
    testProductService();
  } else if (scenario < 0.7) {
    // 40% of traffic: Login and browse
    const token = testAuthService();
    sleep(Math.random() * 2); // Think time
    testProductService();
    if (token) {
      testTokenValidation(token);
    }
  } else {
    // 30% of traffic: Full user journey (login, browse, purchase)
    const token = testAuthService();
    sleep(Math.random() * 1); // Think time
    
    testProductService();
    sleep(Math.random() * 2); // Think time
    
    if (token && testTokenValidation(token)) {
      testPaymentService(token);
    } else {
      // Anonymous payment attempt
      testPaymentService(null);
    }
  }
  
  // Random think time between requests
  sleep(Math.random() * 3 + 1); // 1-4 seconds
}

// Setup function (runs once at the beginning)
export function setup() {
  console.log(`Starting load test against: ${BASE_URL}`);
  console.log('Test scenarios:');
  console.log('  - 10% Health checks');
  console.log('  - 20% Product browsing');
  console.log('  - 40% Login + browsing');
  console.log('  - 30% Full user journey');
  
  // Verify services are reachable
  const healthCheck = http.get(`${BASE_URL}/health`);
  if (healthCheck.status !== 200) {
    console.error(`Gateway health check failed: ${healthCheck.status}`);
  }
  
  return { baseUrl: BASE_URL };
}

// Teardown function (runs once at the end)
export function teardown(data) {
  console.log('Load test completed');
  console.log(`Total requests made: ${requestCount.count}`);
}

// Generate HTML report
export function handleSummary(data) {
  return {
    "summary.html": htmlReport(data),
    "summary.json": JSON.stringify(data, null, 2),
  };
}