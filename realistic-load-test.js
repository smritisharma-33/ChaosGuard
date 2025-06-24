import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 10 },
    { duration: '5m', target: 20 },
    { duration: '2m', target: 0 },
  ],
};

const BASE_URL = 'http://localhost:8080';

export default function() {
  // Simulate realistic user behavior
  let response;
  
  // 1. Health check
  response = http.get(`${BASE_URL}/auth/health`);
  check(response, { 'auth health': (r) => r.status === 200 });
  
  // 2. Login
  response = http.post(`${BASE_URL}/auth/login`, JSON.stringify({
    username: `user${Math.floor(Math.random() * 1000)}`,
    password: 'test123'
  }), { headers: { 'Content-Type': 'application/json' } });
  
  check(response, { 'login success': (r) => r.status === 200 });
  
  sleep(1);
  
  // 3. Browse products
  response = http.get(`${BASE_URL}/products/products`);
  check(response, { 'products listed': (r) => r.status === 200 });
  
  sleep(2);
  
  // 4. Make payment (some fail intentionally)
  response = http.post(`${BASE_URL}/payment/process`, JSON.stringify({
    amount: Math.floor(Math.random() * 500) + 10,
    currency: 'USD',
    card_token: 'test_token',
    user_id: `user_${Math.floor(Math.random() * 1000)}`
  }), { headers: { 'Content-Type': 'application/json' } });
  
  check(response, { 'payment processed': (r) => r.status === 200 || r.status === 400 });
  
  sleep(3);
}
