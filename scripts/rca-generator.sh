#!/usr/bin/env python3

import os
import json
import requests
import datetime
from typing import Dict, List, Any
import subprocess
import time

class ChaosRCAGenerator:
    def __init__(self):
        self.prometheus_url = self.get_prometheus_url()
        self.report_dir = "reports"
        self.ensure_report_dir()
    
    def get_prometheus_url(self) -> str:
        """Get Prometheus URL from minikube"""
        try:
            result = subprocess.run(['minikube', 'ip'], capture_output=True, text=True)
            minikube_ip = result.stdout.strip()
            return f"http://{minikube_ip}:30090"
        except Exception:
            return "http://localhost:30090"
    
    def ensure_report_dir(self):
        """Create reports directory if it doesn't exist"""
        os.makedirs(self.report_dir, exist_ok=True)
    
    def query_prometheus(self, query: str, start_time: str = None, end_time: str = None) -> Dict:
        """Query Prometheus for metrics"""
        try:
            if start_time and end_time:
                url = f"{self.prometheus_url}/api/v1/query_range"
                params = {
                    'query': query,
                    'start': start_time,
                    'end': end_time,
                    'step': '30s'
                }
            else:
                url = f"{self.prometheus_url}/api/v1/query"
                params = {'query': query}
            
            response = requests.get(url, params=params, timeout=10)
            return response.json()
        except Exception as e:
            print(f"Error querying Prometheus: {e}")
            return {'status': 'error', 'data': {'result': []}}
    
    def get_chaos_events(self) -> List[Dict]:
        """Get chaos experiment events from Kubernetes"""
        try:
            result = subprocess.run([
                'kubectl', 'get', 'events', '-n', 'chaosguard',
                '--sort-by=.firstTimestamp', '-o', 'json'
            ], capture_output=True, text=True)
            
            events = json.loads(result.stdout)
            chaos_events = []
            
            for event in events.get('items', []):
                if 'chaos' in event.get('reason', '').lower() or \
                   'chaos' in event.get('message', '').lower():
                    chaos_events.append({
                        'timestamp': event.get('firstTimestamp'),
                        'reason': event.get('reason'),
                        'message': event.get('message'),
                        'object': event.get('involvedObject', {}).get('name'),
                        'namespace': event.get('involvedObject', {}).get('namespace')
                    })
            
            return chaos_events
        except Exception as e:
            print(f"Error getting chaos events: {e}")
            return []
    
    def analyze_error_rates(self, start_time: str, end_time: str) -> Dict:
        """Analyze error rates during chaos experiments"""
        queries = {
            'auth_errors': 'rate(auth_requests_total{status=~"5.."}[5m])',
            'product_errors': 'rate(product_requests_total{status=~"5.."}[5m])',
            'payment_errors': 'rate(payment_requests_total{status=~"5.."}[5m])',
            'total_requests': 'rate(auth_requests_total[5m]) + rate(product_requests_total[5m]) + rate(payment_requests_total[5m])'
        }
        
        results = {}
        for name, query in queries.items():
            data = self.query_prometheus(query, start_time, end_time)
            results[name] = data.get('data', {}).get('result', [])
        
        return results
    
    def analyze_latency(self, start_time: str, end_time: str) -> Dict:
        """Analyze latency metrics during chaos experiments"""
        queries = {
            'auth_p95': 'histogram_quantile(0.95, rate(auth_request_duration_seconds_bucket[5m]))',
            'product_p95': 'histogram_quantile(0.95, rate(product_request_duration_seconds_bucket[5m]))',
            'payment_p95': 'histogram_quantile(0.95, rate(payment_request_duration_seconds_bucket[5m]))',
            'auth_p99': 'histogram_quantile(0.99, rate(auth_request_duration_seconds_bucket[5m]))',
            'product_p99': 'histogram_quantile(0.99, rate(product_request_duration_seconds_bucket[5m]))',
            'payment_p99': 'histogram_quantile(0.99, rate(payment_request_duration_seconds_bucket[5m]))'
        }
        
        results = {}
        for name, query in queries.items():
            data = self.query_prometheus(query, start_time, end_time)
            results[name] = data.get('data', {}).get('result', [])
        
        return results
    
    def analyze_service_health(self, start_time: str, end_time: str) -> Dict:
        """Analyze service health metrics"""
        queries = {
            'auth_health': 'auth_service_health',
            'product_health': 'product_service_health', 
            'payment_health': 'payment_service_health',
            'pod_restarts': 'rate(kube_pod_container_status_restarts_total[5m])'
        }
        
        results = {}
        for name, query in queries.items():
            data = self.query_prometheus(query, start_time, end_time)
            results[name] = data.get('data', {}).get('result', [])
        
        return results
    
    def get_chaos_results(self) -> List[Dict]:
        """Get chaos experiment results"""
        try:
            result = subprocess.run([
                'kubectl', 'get', 'chaosresult', '-n', 'chaosguard', '-o', 'json'
            ], capture_output=True, text=True)
            
            chaos_results = json.loads(result.stdout)
            results = []
            
            for item in chaos_results.get('items', []):
                results.append({
                    'name': item.get('metadata', {}).get('name'),
                    'experiment': item.get('spec', {}).get('experimentName'),
                    'verdict': item.get('status', {}).get('experimentStatus', {}).get('verdict'),
                    'phase': item.get('status', {}).get('experimentStatus', {}).get('phase'),
                    'fail_step': item.get('status', {}).get('experimentStatus', {}).get('failStep'),
                    'probe_success': item.get('status', {}).get('experimentStatus', {}).get('probeSuccessPercentage')
                })
            
            return results
        except Exception as e:
            print(f"Error getting chaos results: {e}")
            return []
    
    def calculate_slo_breach(self, metrics: Dict) -> Dict:
        """Calculate SLO breaches"""
        slo_breaches = {
            'error_rate_breach': False,
            'latency_breach': False,
            'availability_breach': False
        }
        
        # Check error rate SLO (< 1%)
        for service in ['auth_errors', 'product_errors', 'payment_errors']:
            if service in metrics:
                for result in metrics[service]:
                    for value in result.get('values', []):
                        if float(value[1]) > 0.01:  # 1% error rate threshold
                            slo_breaches['error_rate_breach'] = True
        
        # Check latency SLO (p95 < 1s)
        for service in ['auth_p95', 'product_p95', 'payment_p95']:
            if service in metrics:
                for result in metrics[service]:
                    for value in result.get('values', []):
                        if float(value[1]) > 1.0:  # 1 second threshold
                            slo_breaches['latency_breach'] = True
        
        return slo_breaches
    
    def generate_recommendations(self, chaos_results: List[Dict], slo_breaches: Dict) -> List[str]:
        """Generate mitigation recommendations"""
        recommendations = []
        
        # Analyze chaos experiment results
        failed_experiments = [r for r in chaos_results if r.get('verdict') == 'Fail']
        
        if failed_experiments:
            recommendations.append("🚨 **Critical**: Some chaos experiments failed completely")
            recommendations.append("   - Review application resilience patterns")
            recommendations.append("   - Implement circuit breakers")
            recommendations.append("   - Add retry mechanisms with exponential backoff")
        
        if slo_breaches['error_rate_breach']:
            recommendations.append("📈 **Error Rate SLO Breach Detected**")
            recommendations.append("   - Implement graceful degradation")
            recommendations.append("   - Add health checks and readiness probes")
            recommendations.append("   - Consider implementing bulkhead pattern")
        
        if slo_breaches['latency_breach']:
            recommendations.append("⏱️ **Latency SLO Breach Detected**")
            recommendations.append("   - Optimize database queries")
            recommendations.append("   - Implement request timeouts")
            recommendations.append("   - Add caching layers")
            recommendations.append("   - Consider horizontal pod autoscaling")
        
        # Pod failure specific recommendations
        pod_failures = [r for r in chaos_results if 'pod-delete' in r.get('experiment', '')]
        if pod_failures:
            recommendations.append("🔄 **Pod Failure Resilience**")
            recommendations.append("   - Increase replica count for critical services")
            recommendations.append("   - Implement pod disruption budgets")
            recommendations.append("   - Review resource requests and limits")
        
        # Network latency specific recommendations
        network_issues = [r for r in chaos_results if 'network' in r.get('experiment', '')]
        if network_issues:
            recommendations.append("🌐 **Network Resilience**")
            recommendations.append("   - Implement connection pooling")
            recommendations.append("   - Add request timeouts and retries")
            recommendations.append("   - Consider service mesh for traffic management")
        
        # CPU stress specific recommendations
        cpu_stress = [r for r in chaos_results if 'cpu' in r.get('experiment', '')]
        if cpu_stress:
            recommendations.append("💻 **Resource Management**")
            recommendations.append("   - Review CPU resource limits")
            recommendations.append("   - Implement horizontal pod autoscaler")
            recommendations.append("   - Consider vertical pod autoscaler")
            recommendations.append("   - Optimize application performance")
        
        if not recommendations:
            recommendations.append("✅ **Good Job!** All experiments passed successfully")
            recommendations.append("   - Continue regular chaos testing")
            recommendations.append("   - Consider more complex failure scenarios")
            recommendations.append("   - Implement chaos engineering in CI/CD")
        
        return recommendations
    
    def generate_markdown_report(self) -> str:
        """Generate comprehensive RCA report"""
        timestamp = datetime.datetime.now()
        end_time = int(timestamp.timestamp())
        start_time = end_time - 3600  # Last hour
        
        # Collect data
        chaos_events = self.get_chaos_events()
        chaos_results = self.get_chaos_results()
        
        # Analyze metrics
        error_metrics = self.analyze_error_rates(str(start_time), str(end_time))
        latency_metrics = self.analyze_latency(str(start_time), str(end_time))
        health_metrics = self.analyze_service_health(str(start_time), str(end_time))
        
        # Calculate SLO breaches
        all_metrics = {**error_metrics, **latency_metrics}
        slo_breaches = self.calculate_slo_breach(all_metrics)
        
        # Generate recommendations
        recommendations = self.generate_recommendations(chaos_results, slo_breaches)
        
        # Create report
        report = f"""# ChaosGuard - Post-Incident RCA Report

**Generated:** {timestamp.strftime('%Y-%m-%d %H:%M:%S UTC')}  
**Analysis Period:** {datetime.datetime.fromtimestamp(start_time).strftime('%Y-%m-%d %H:%M:%S')} - {datetime.datetime.fromtimestamp(end_time).strftime('%Y-%m-%d %H:%M:%S')}

## 📊 Executive Summary

This report analyzes the impact of chaos engineering experiments on the ChaosGuard e-commerce platform. The analysis covers service availability, error rates, latency metrics, and overall system resilience.

### Key Findings
- **Total Experiments Run:** {len(chaos_results)}
- **SLO Breaches:** {'Yes' if any(slo_breaches.values()) else 'No'}
- **Critical Issues:** {'Detected' if any(r.get('verdict') == 'Fail' for r in chaos_results) else 'None'}

## 🧪 Chaos Experiment Results

### Experiment Summary
"""

        # Add experiment results
        if chaos_results:
            for result in chaos_results:
                verdict_emoji = "✅" if result.get('verdict') == 'Pass' else "❌"
                report += f"""
**{verdict_emoji} {result.get('experiment', 'Unknown')}**
- **Status:** {result.get('verdict', 'Unknown')}
- **Phase:** {result.get('phase', 'Unknown')}
- **Probe Success:** {result.get('probe_success', 'N/A')}%
"""
        else:
            report += "\n*No chaos experiment results found in the last hour.*\n"

        # Add timeline
        report += f"""

## ⏰ Incident Timeline

### Chaos Events
"""
        
        if chaos_events:
            for event in chaos_events[-10:]:  # Last 10 events
                report += f"""
**{event.get('timestamp', 'Unknown')}** - {event.get('reason', 'Unknown')}  
*Object:* {event.get('object', 'Unknown')} (*{event.get('namespace', 'Unknown')}*)  
*Message:* {event.get('message', 'No message')}
"""
        else:
            report += "\n*No chaos-related events found.*\n"

        # Add metrics analysis
        report += f"""

## 📈 Metrics Analysis

### Service Level Objectives (SLOs)

| SLO | Status | Description |
|-----|--------|-------------|
| Error Rate < 1% | {'❌ BREACH' if slo_breaches['error_rate_breach'] else '✅ OK'} | Application error rate threshold |
| P95 Latency < 1s | {'❌ BREACH' if slo_breaches['latency_breach'] else '✅ OK'} | Response time performance |
| Availability > 99.9% | {'❌ BREACH' if slo_breaches['availability_breach'] else '✅ OK'} | Service availability target |

### Error Rate Analysis
"""

        # Add error rate details
        for service, data in error_metrics.items():
            if data:
                max_error_rate = 0
                for result in data:
                    for value in result.get('values', []):
                        max_error_rate = max(max_error_rate, float(value[1]))
                report += f"- **{service.replace('_', ' ').title()}:** Peak error rate {max_error_rate:.4f}/s\n"

        report += f"""

### Latency Analysis
"""

        # Add latency details
        for service, data in latency_metrics.items():
            if data:
                max_latency = 0
                for result in data:
                    for value in result.get('values', []):
                        if value[1] != 'NaN':
                            max_latency = max(max_latency, float(value[1]))
                report += f"- **{service.replace('_', ' ').title()}:** Peak latency {max_latency:.3f}s\n"

        # Add recommendations
        report += f"""

## 🔧 Recommendations & Mitigations

### Immediate Actions Required
"""
        
        for recommendation in recommendations:
            report += f"{recommendation}\n"

        report += f"""

### Long-term Improvements
- **Implement Comprehensive Monitoring:** Add more detailed application metrics
- **Enhance Alerting:** Set up proactive alerts for SLO breaches
- **Automate Recovery:** Implement self-healing mechanisms
- **Expand Testing:** Include more failure scenarios in chaos experiments
- **Documentation:** Update runbooks based on experiment findings

## 🔍 Technical Details

### Prometheus Queries Used
```promql
# Error Rate
rate(auth_requests_total{{status=~"5.."}}[5m])
rate(product_requests_total{{status=~"5.."}}[5m])
rate(payment_requests_total{{status=~"5.."}}[5m])

# Latency
histogram_quantile(0.95, rate(auth_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(product_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(payment_request_duration_seconds_bucket[5m]))

# Service Health
auth_service_health
product_service_health
payment_service_health