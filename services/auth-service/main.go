package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "time"
    "math/rand"
    
    "github.com/gorilla/mux"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

type AuthRequest struct {
    Username string `json:"username"`
    Password string `json:"password"`
}

type AuthResponse struct {
    Token   string `json:"token"`
    UserID  string `json:"user_id"`
    Success bool   `json:"success"`
}

var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "auth_requests_total",
            Help: "Total number of auth requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "auth_request_duration_seconds",
            Help:    "Duration of auth requests",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
    
    serviceHealth = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "auth_service_health",
            Help: "Health status of auth service",
        },
        []string{"service"},
    )
)

func init() {
    prometheus.MustRegister(requestsTotal)
    prometheus.MustRegister(requestDuration)
    prometheus.MustRegister(serviceHealth)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    
    // Simulate occasional health check failures
    if rand.Float32() < 0.05 {
        serviceHealth.WithLabelValues("auth").Set(0)
        requestsTotal.WithLabelValues(r.Method, "/health", "500").Inc()
        http.Error(w, "Service unhealthy", http.StatusInternalServerError)
        return
    }
    
    serviceHealth.WithLabelValues("auth").Set(1)
    requestsTotal.WithLabelValues(r.Method, "/health", "200").Inc()
    requestDuration.WithLabelValues(r.Method, "/health").Observe(time.Since(start).Seconds())
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{"status": "healthy", "service": "auth"})
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    
    var authReq AuthRequest
    if err := json.NewDecoder(r.Body).Decode(&authReq); err != nil {
        requestsTotal.WithLabelValues(r.Method, "/login", "400").Inc()
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }
    
    // Simulate processing delay
    time.Sleep(time.Duration(rand.Intn(100)) * time.Millisecond)
    
    // Simulate authentication logic with occasional failures
    success := authReq.Username != "" && authReq.Password != "" && rand.Float32() > 0.1
    
    if success {
        requestsTotal.WithLabelValues(r.Method, "/login", "200").Inc()
        response := AuthResponse{
            Token:   fmt.Sprintf("token_%s_%d", authReq.Username, time.Now().Unix()),
            UserID:  fmt.Sprintf("user_%s", authReq.Username),
            Success: true,
        }
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(response)
    } else {
        requestsTotal.WithLabelValues(r.Method, "/login", "401").Inc()
        http.Error(w, "Authentication failed", http.StatusUnauthorized)
    }
    
    requestDuration.WithLabelValues(r.Method, "/login").Observe(time.Since(start).Seconds())
}

func validateHandler(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    
    token := r.Header.Get("Authorization")
    if token == "" {
        requestsTotal.WithLabelValues(r.Method, "/validate", "401").Inc()
        http.Error(w, "Missing token", http.StatusUnauthorized)
        return
    }
    
    // Simulate token validation with occasional failures
    if rand.Float32() < 0.05 {
        requestsTotal.WithLabelValues(r.Method, "/validate", "401").Inc()
        http.Error(w, "Invalid token", http.StatusUnauthorized)
        return
    }
    
    requestsTotal.WithLabelValues(r.Method, "/validate", "200").Inc()
    requestDuration.WithLabelValues(r.Method, "/validate").Observe(time.Since(start).Seconds())
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]interface{}{
        "valid": true,
        "user_id": "user_validated",
    })
}

func main() {
    serviceHealth.WithLabelValues("auth").Set(1)
    
    r := mux.NewRouter()
    r.HandleFunc("/health", healthHandler).Methods("GET")
    r.HandleFunc("/login", loginHandler).Methods("POST")
    r.HandleFunc("/validate", validateHandler).Methods("POST")
    r.Handle("/metrics", promhttp.Handler())
    
    port := os.Getenv("PORT")
    if port == "" {
        port = "8081"
    }
    
    log.Printf("Auth service starting on port %s", port)
    log.Fatal(http.ListenAndServe(":"+port, r))
}