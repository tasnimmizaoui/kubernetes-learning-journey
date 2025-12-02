#!/bin/bash

# Canary Deployment Automation Script
set -e

# Configuration
NAMESPACE="lab"
STABLE_DEPLOYMENT="webapp-stable"
CANARY_DEPLOYMENT="webapp-canary"
SERVICE_NAME="webapp-canary-service"
CANARY_IMAGE="nginx:1.22"  # New version to test
STABLE_IMAGE="nginx:1.21"  # Current stable version
TRAFFIC_SPLITS=("10" "25" "50" "100")  # Canary progression stages
HEALTH_CHECK_TIMEOUT=300  # 5 minutes per stage
LOAD_GENERATOR_REPLICAS=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Health check functions
check_pod_health() {
    local deployment=$1
    local namespace=$2
    local replicas=$3
    
    log_info "Checking health of $deployment pods..."
    
    # Get ready replicas - handle empty response
    local ready_pods=$(kubectl get deployment $deployment -n $namespace -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    if [ -z "$ready_pods" ]; then
        ready_pods=0
    fi
    
    # Get desired replicas - handle empty response  
    local desired_pods=$(kubectl get deployment $deployment -n $namespace -o jsonpath='{.status.replicas}' 2>/dev/null)
    if [ -z "$desired_pods" ]; then
        desired_pods=0
    fi
    
    # Handle the case where both are 0 (intentional)
    if [ "$replicas" -eq 0 ] && [ "$ready_pods" -eq 0 ] && [ "$desired_pods" -eq 0 ]; then
        log_success "$deployment has 0 replicas (as expected)"
        return 0
    fi
    
    if [ "$ready_pods" -eq "$desired_pods" ] && [ "$desired_pods" -eq "$replicas" ]; then
        log_success "All $deployment pods are healthy ($ready_pods/$desired_pods)"
        return 0
    else
        log_error "Pod health check failed for $deployment ($ready_pods/$desired_pods ready, desired: $replicas)"
        return 1
    fi
}

check_service_endpoints() {
    local service=$1
    local namespace=$2
    local expected_endpoints=$3
    
    log_info "Checking service endpoints for $service..."
    
    local endpoints=$(kubectl get endpoints $service -n $namespace -o jsonpath='{.subsets[0].addresses[*].ip}' | wc -w)
    
    if [ "$endpoints" -eq "$expected_endpoints" ]; then
        log_success "Service $service has $endpoints endpoints (expected: $expected_endpoints)"
        return 0
    else
        log_error "Service endpoint check failed: $endpoints endpoints found, expected $expected_endpoints"
        return 1
    fi
}

check_application_health() {
    local service=$1
    local namespace=$2
    local sample_size=5
    
    log_info "Performing application health checks ($sample_size requests)..."
    
    local success_count=0
    for i in $(seq 1 $sample_size); do
        # Use temporary busybox pod to test service
        if kubectl run -it --rm test-health --image=busybox --restart=Never -n $namespace -- \
            wget -q -T 5 -O- http://$service >/dev/null 2>&1; then
            ((success_count++))
        fi
        sleep 1
    done
    
    if [ "$success_count" -eq "$sample_size" ]; then
        log_success "Application health check passed ($success_count/$sample_size successful)"
        return 0
    else
        log_error "Application health check failed ($success_count/$sample_size successful)"
        return 1
    fi
}

check_error_rates() {
    local deployment=$1
    local namespace=$2
    local threshold=5  # 5% error rate threshold
    
    log_info "Checking error rates for $deployment..."
    
    # Get pod names
    local pods=$(kubectl get pods -n $namespace -l app=webapp -o jsonpath='{.items[*].metadata.name}')
    local total_errors=0
    local total_requests=0
    
    for pod in $pods; do
        # Count error logs (simplified - adjust based on your app logging)
        local errors=$(kubectl logs $pod -n $namespace --tail=100 | grep -c "ERROR\|500\|Exception" || true)
        local requests=$(kubectl logs $pod -n $namespace --tail=100 | grep -c "REQUEST\|GET\|POST" || true)
        
        total_errors=$((total_errors + errors))
        total_requests=$((total_requests + requests))
    done
    
    if [ "$total_requests" -gt 0 ]; then
        local error_rate=$((total_errors * 100 / total_requests))
        if [ "$error_rate" -lt "$threshold" ]; then
            log_success "Error rate acceptable: $error_rate% (threshold: ${threshold}%)"
            return 0
        else
            log_error "Error rate too high: $error_rate% (threshold: ${threshold}%)"
            return 1
        fi
    else
        log_warning "No requests found for error rate calculation"
        return 0
    fi
}

# Canary progression function
deploy_canary() {
    local canary_traffic_percent=$1
    local total_replicas=10
    
    # Calculate replica counts
    local canary_replicas=$((total_replicas * canary_traffic_percent / 100))
    local stable_replicas=$((total_replicas - canary_replicas))
    
    log_info "Progressing canary to ${canary_traffic_percent}% traffic"
    log_info "Stable replicas: $stable_replicas, Canary replicas: $canary_replicas"
    
    # Scale deployments
    kubectl scale deployment $STABLE_DEPLOYMENT -n $NAMESPACE --replicas=$stable_replicas
    kubectl scale deployment $CANARY_DEPLOYMENT -n $NAMESPACE --replicas=$canary_replicas
    
    # Wait for scaling to complete
    log_info "Waiting for deployments to scale..."
    kubectl rollout status deployment/$STABLE_DEPLOYMENT -n $NAMESPACE --timeout=${HEALTH_CHECK_TIMEOUT}s
    kubectl rollout status deployment/$CANARY_DEPLOYMENT -n $NAMESPACE --timeout=${HEALTH_CHECK_TIMEOUT}s
    
    # Perform health checks
    log_info "Performing health checks for ${canary_traffic_percent}% stage..."
    
    if check_pod_health $STABLE_DEPLOYMENT $NAMESPACE $stable_replicas && \
       check_pod_health $CANARY_DEPLOYMENT $NAMESPACE $canary_replicas && \
       check_service_endpoints $SERVICE_NAME $NAMESPACE $total_replicas && \
       check_application_health $SERVICE_NAME $NAMESPACE && \
       check_error_rates $CANARY_DEPLOYMENT $NAMESPACE; then
        
        log_success "All health checks passed for ${canary_traffic_percent}% canary stage"
        return 0
    else
        log_error "Health checks failed for ${canary_traffic_percent}% canary stage"
        return 1
    fi
}

# Rollback function
rollback_canary() {
    log_error "Initiating canary rollback..."
    
    # Scale down canary completely
    kubectl scale deployment $CANARY_DEPLOYMENT -n $NAMESPACE --replicas=0
    # Scale stable back to full capacity
    kubectl scale deployment $STABLE_DEPLOYMENT -n $NAMESPACE --replicas=10
    
    log_success "Rollback completed. 100% traffic back to stable version."
    exit 1
}

# Main canary deployment process
main() {
    log_info "Starting automated canary deployment..."
    log_info "Canary image: $CANARY_IMAGE"
    log_info "Stable image: $STABLE_IMAGE"
    
    # Verify initial state
    log_info "Verifying initial cluster state..."
    if ! check_pod_health $STABLE_DEPLOYMENT $NAMESPACE 10; then
        log_error "Initial stable deployment is not healthy. Aborting canary deployment."
        exit 1
    fi
    
    # Deploy canary with 0% traffic initially
    log_info "Deploying canary version with 0% traffic..."
    kubectl scale deployment $CANARY_DEPLOYMENT -n $NAMESPACE --replicas=0
    
    # Start load generator (optional)
    log_info "Starting load generator..."
    kubectl run load-generator --image=busybox --restart=Never -n $NAMESPACE -- \
        /bin/sh -c "while true; do wget -q -O- http://$SERVICE_NAME; sleep 0.5; done" &
    LOAD_GENERATOR_PID=$!
    
    # Progress through canary stages
    for stage in "${TRAFFIC_SPLITS[@]}"; do
        log_info "=========================================="
        log_info "Starting canary stage: $stage% traffic"
        log_info "=========================================="
        
        if deploy_canary $stage; then
            log_success "Canary stage $stage% completed successfully"
            
            # Wait for monitoring period (adjust as needed)
            local monitor_time=60
            log_info "Monitoring canary at $stage% for ${monitor_time} seconds..."
            sleep $monitor_time
            
            # Additional health check after monitoring period
            if ! check_error_rates $CANARY_DEPLOYMENT $NAMESPACE; then
                log_error "Error rate increased during monitoring period. Rolling back."
                kill $LOAD_GENERATOR_PID 2>/dev/null || true
                rollback_canary
            fi
            
        else
            log_error "Canary stage $stage% failed. Rolling back."
            kill $LOAD_GENERATOR_PID 2>/dev/null || true
            rollback_canary
        fi
    done
    
    # Canary deployment successful - complete the rollout
    log_success "=========================================="
    log_success "Canary deployment completed successfully!"
    log_success "=========================================="
    
    # Update stable deployment to canary image
    log_info "Updating stable deployment to canary image..."
    kubectl set image deployment/$STABLE_DEPLOYMENT nginx=$CANARY_IMAGE -n $NAMESPACE
    kubectl scale deployment $STABLE_DEPLOYMENT -n $NAMESPACE --replicas=10
    kubectl scale deployment $CANARY_DEPLOYMENT -n $NAMESPACE --replicas=0
    
    # Clean up
    kill $LOAD_GENERATOR_PID 2>/dev/null || true
    kubectl delete pod load-generator -n $NAMESPACE 2>/dev/null || true
    
    log_success "Canary deployment fully completed. Stable version now running $CANARY_IMAGE"
}

# Signal handling for graceful interruption
trap 'log_warning "Script interrupted. Initiating rollback..."; kill $LOAD_GENERATOR_PID 2>/dev/null; rollback_canary' INT TERM

# Run main function
main "$@"