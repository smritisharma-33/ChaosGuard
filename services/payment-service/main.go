package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "time"
    "math/rand"
    
    "github.com/gorilla/mux"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

type PaymentRequest struct {
    Amount    float64 `json:"amount"`
    Currency  string  `json:"currency"`
    CardToken string  `json:"card_token"`
    UserID    string  `json:"user_id"`
}

type PaymentResponse struct {
    TransactionID string  `json:"transaction_id"`
    Amount        float64 `json:"amount"`
    Status        string  `json:"status"`
    Timestamp     string  `json:"timestamp"`
}

var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "payment_requests_total",
            Help: "Total number of payment requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "payment_request_duration_seconds",
            Help:    "Duration of payment requests",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
    
    serviceHealth = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "payment_service_health",
            Help: "Health status of payment service",
        },
        []string{"service"},
    )
    
    paymentsProcessed = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "payments_processed_total",
            Help: "Total number of processed payments",
        },
        []string{"status"},
    )
    
    paymentAmount = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "payment_amount",
            Help:    "Payment amounts",
            Buckets: []float64{10, 50, 100, 500, 1000, 5000},
        },
        []string{"currency"},
    )
)

func init() {
    prometheus.MustRegister(requestsTotal)
    prometheus.MustRegister(requestDuration)
    prometheus.MustRegister(serviceHealth)
    prometheus.MustRegister(paymentsProcessed)
    prometheus.MustRegister(paymentAmount)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    
    if rand.Float32() < 0.04 {
        serviceHealth.WithLabelValues("payment").Set(0)
        requestsTotal.WithLabelValues(r.Method, "/health", "500").Inc()
        http.Error(w, "Service unhealthy", http.StatusInternalServerError)
        return
    }
    
    serviceHealth.WithLabelValues("payment").Set(1)
    requestsTotal.WithLabelValues(r.Method, "/health", "200").Inc()
    requestDuration.WithLabelValues(r.Method, "/health").Observe(time.Since(start).Seconds())
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{"status": "healthy", "service": "payment"})
}

func processPaymentHandler(w http.ResponseWriter, r *http.Request) {
    start := time.Now()
    
    var paymentReq PaymentRequest
    if err := json.NewDecoder(r.Body).Decode(&paymentReq); err != nil {
        requestsTotal.WithLabelValues(r.Method, "/process", "400").Inc()
        http.Error(w, "Invalid request", http.StatusBadRequest)
        return
    }
    
    // Simulate payment processing delay
    time.Sleep(time.Duration(rand.Intn(500)+200) * time.Millisecond)
    
    // Simulate payment failures (10% chance)
    if rand.Float32() < 0.1 {
        requestsTotal.WithLabelValues(r.Method, "/process", "400").Inc()
        paymentsProcessed.WithLabelValues("failed").Inc()
        requestDuration.WithLabelValues(r.Method, "/process").Observe(time.Since(start).Seconds())
        http.Error(w, "Payment failed", http.StatusBadRequest)
        return
    }
    
    transactionID := generateTransactionID()
    
    response := PaymentResponse{
        TransactionID: transactionID,
        Amount:        paymentReq.Amount,
        Status:        "success",
        Timestamp:     time.Now().UTC().Format(time.RFC3339),
    }
    
    requestsTotal.WithLabelValues(r.Method, "/process", "200").Inc()
    paymentsProcessed.WithLabelValues("success").Inc()
    paymentAmount.WithLabelValues(paymentReq.Currency).Observe(paymentReq.Amount)
    requestDuration.WithLabelValues(r.Method, "/process").Observe(time.Since(start).Seconds())
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func generateTransactionID() string {
    return "txn_" + string(rune(rand.Intn(1000000000)))
}

func main() {
    serviceHealth.WithLabelValues("payment").Set(1)
    
    r := mux.NewRouter()
    r.HandleFunc("/health", healthHandler).Methods("GET")
    r.HandleFunc("/process", processPaymentHandler).Methods("POST")
    r.Handle("/metrics", promhttp.Handler())
    
    port := os.Getenv("PORT")
    if port == "" {
        port = "8083"
    }
    
    log.Printf("Payment service starting on port %s", port)
    log.Fatal(http.ListenAndServe(":"+port, r))
}