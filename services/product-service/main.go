package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "strconv"
    "time"
    "math/rand"
    
    "github.com/gorilla/mux"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

type Product struct {
    ID          int     `json:"id"`
    Name        string  `json:"name"`
    Price       float64 `json:"price"`
    Description string  `json:"description"`
    Stock       int     `json:"stock"`
}

var products = []Product{
    {1, "Laptop", 999.99, "High-performance laptop", 50},
    {2, "Mouse", 29.99, "Wireless mouse", 100},
    {3, "Keyboard", 79.99, "Mechanical keyboard", 75},
    {4, "Monitor", 299.99, "4K monitor", 25},
    {5, "Headphones", 199.99, "Noise-cancelling headphones", 60},
}

var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "product_requests_total",
            Help: "Total number of product requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "product_request_duration_seconds",
            Help:    "Duration of product requests",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
    
    serviceHealth = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "product_service_health",
            Help: "Health status of product service",
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
    
    if rand.Float32() < 0.03 {
        serviceHealth.WithLabelValues("product").Set(0)
        requestsTotal.WithLabelValues(r.Method, "/health", "500").Inc()
        http.Error(w, "Service unhealthy", http.StatusInternalServerError)
        return
    }
    
    serviceHealth.WithLabelValues("product").Set(1)
    requestsTotal.WithLabelValues(r.Method, "/health", "200").Inc()
    requestDuration.WithLabelValues(r.Method, "/health").Observe(time.Since(start).Seconds())
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{"status": "healthy", "service": "product"})
}

func getProductsHandler(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    
    // Simulate processing delay
    time.Sleep(time.Duration(rand.Intn(200)) * time.Millisecond)
    
    requestsTotal.WithLabelValues(r.Method, "/products", "200").Inc()
    requestDuration.WithLabelValues(r.Method, "/products").Observe(time.Since(start).Seconds())
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(products)
}

func getProductHandler(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    
    vars := mux.Vars(r)
    id, err := strconv.Atoi(vars["id"])
    if err != nil {
        requestsTotal.WithLabelValues(r.Method, "/products/{id}", "400").Inc()
        http.Error(w, "Invalid product ID", http.StatusBadRequest)
        return
    }
    
    // Simulate database lookup delay
    time.Sleep(time.Duration(rand.Intn(150)) * time.Millisecond)
    
    for _, product := range products {
        if product.ID == id {
            requestsTotal.WithLabelValues(r.Method, "/products/{id}", "200").Inc()
            requestDuration.WithLabelValues(r.Method, "/products/{id}").Observe(time.Since(start).Seconds())
            w.Header().Set("Content-Type", "application/json")
            json.NewEncoder(w).Encode(product)
            return
        }
    }
    
    requestsTotal.WithLabelValues(r.Method, "/products/{id}", "404").Inc()
    requestDuration.WithLabelValues(r.Method, "/products/{id}").Observe(time.Since(start).Seconds())
    http.Error(w, "Product not found", http.StatusNotFound)
}

func main() {
    serviceHealth.WithLabelValues("product").Set(1)
    
    r := mux.NewRouter()
    r.HandleFunc("/health", healthHandler).Methods("GET")
    r.HandleFunc("/products", getProductsHandler).Methods("GET")
    r.HandleFunc("/products/{id}", getProductHandler).Methods("GET")
    r.Handle("/metrics", promhttp.Handler())
    
    port := os.Getenv("PORT")
    if port == "" {
        port = "8082"
    }
    
    log.Printf("Product service starting on port %s", port)
    log.Fatal(http.ListenAndServe(":"+port, r))
}