#!/bin/bash

set -e

echo "⚡ Running ChaosGuard experiments..."

EXPERIMENT=${1:-"all"}
DURATION=${2:-"300"}

run_experiment() {
    local experiment_name=$1
    echo "🧪 Running $experiment_name experiment..."
    
    # Apply the experiment
    kubectl apply -f chaos/${experiment_name}.yaml
    
    # Wait for completion
    sleep $DURATION
    
    # Check results
    kubectl get chaosresult -n chaosguard -l chaosengine=$experiment_name-chaos
    
    echo "✅ $experiment_name experiment completed"
}

case $EXPERIMENT in
    "pod-failure")
        run_experiment "pod-failure"
        ;;
    "network-latency")
        run_experiment "network-latency"
        ;;
    "cpu-stress")
        run_experiment "cpu-stress"
        ;;
    "all")
        echo "🚀 Running all chaos experiments..."
        run_experiment "pod-failure"
        sleep 60
        run_experiment "network-latency"
        sleep 60
        run_experiment "cpu-stress"
        ;;
    *)
        echo "Usage: $0 [pod-failure|network-latency|cpu-stress|all] [duration_seconds]"
        exit 1
        ;;
esac

echo "🎯 Generating RCA report..."
python3 scripts/rca-generator.py

echo "🎉 Chaos experiments completed! Check the reports/ directory for RCA analysis."