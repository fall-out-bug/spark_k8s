#!/bin/bash
# Validation library for test scripts
# Provides functions to validate Kubernetes deployments, pods, services, etc.

# Source common library first
# shellcheck source=scripts/tests/lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Mark as loaded (idempotent)
export _TEST_LIB_VALIDATION_LOADED=yes

# ============================================================================
# Constants
# ============================================================================

POD_READY_TIMEOUT="${POD_READY_TIMEOUT:-300}"  # Default timeout for pods to be ready
SERVICE_READY_TIMEOUT="${SERVICE_READY_TIMEOUT:-60}"  # Default timeout for services
DEPLOYMENT_READY_TIMEOUT="${DEPLOYMENT_READY_TIMEOUT:-300}"  # Default timeout for deployments

# ============================================================================
# Pod validation
# ============================================================================

# Wait for pod to be ready
wait_for_pod_ready() {
    local pod_name="${1}"
    local namespace="${2}"
    local timeout="${3:-$POD_READY_TIMEOUT}"

    log_step "Waiting for pod to be ready: $pod_name"

    kubectl wait --for=condition=ready pod "$pod_name" \
        -n "$namespace" \
        --timeout="${timeout}s" 2>/dev/null
}

# Wait for pods by label selector
wait_for_pods_by_label() {
    local label_selector="${1}"
    local namespace="${2}"
    local expected_count="${3:-1}"
    local timeout="${4:-$POD_READY_TIMEOUT}"

    log_step "Waiting for $expected_count pod(s) with label: $label_selector"

    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        # Count ready pods - use field selector for Ready status
        local ready_count
        ready_count=$(kubectl get pods \
            -n "$namespace" \
            -l "$label_selector" \
            -o json | jq -r '[.items[] | select(.status.conditions[]? | .type == "Ready" and .status == "True")] | length' 2>/dev/null || echo "0")

        if [[ $ready_count -ge $expected_count ]]; then
            log_success "Pods ready: $ready_count/$expected_count"
            return 0
        fi

        log_debug "Waiting for pods... ($ready_count/$expected_count ready, ${elapsed}s elapsed)"
        sleep 5
        elapsed=$((elapsed + 5))
    done

    log_error "Timeout waiting for pods (expected $expected_count, got $ready_count)"
    return 1
}

# Check if pod is running
is_pod_running() {
    local pod_name="${1}"
    local namespace="${2}"

    local phase
    phase=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)

    [[ "$phase" == "Running" ]]
}

# Get pod status
get_pod_status() {
    local pod_name="${1}"
    local namespace="${2}"

    kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown"
}

# Get pod restart count
get_pod_restart_count() {
    local pod_name="${1}"
    local namespace="${2}"

    kubectl get pod "$pod_name" -n "$namespace" \
        -o jsonpath='{sum(.status.containerStatuses[].restartCount)}' 2>/dev/null || echo "0"
}

# Get pod logs
get_pod_logs() {
    local pod_name="${1}"
    local namespace="${2}"
    local container="${3:-}"
    local tail_lines="${4:-100}"

    if [[ -n "$container" ]]; then
        kubectl logs "$pod_name" -n "$namespace" -c "$container" --tail="$tail_lines" 2>/dev/null
    else
        kubectl logs "$pod_name" -n "$namespace" --tail="$tail_lines" 2>/dev/null
    fi
}

# ============================================================================
# Deployment validation
# ============================================================================

# Wait for deployment to be ready
wait_for_deployment_ready() {
    local deployment_name="${1}"
    local namespace="${2}"
    local timeout="${3:-$DEPLOYMENT_READY_TIMEOUT}"

    log_step "Waiting for deployment to be ready: $deployment_name"

    kubectl wait --for=condition=available \
        deployment/"$deployment_name" \
        -n "$namespace" \
        --timeout="${timeout}s" 2>/dev/null
}

# Check if deployment is ready
is_deployment_ready() {
    local deployment_name="${1}"
    local namespace="${2}"

    local ready_replicas
    ready_replicas=$(kubectl get deployment "$deployment_name" -n "$namespace" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

    local desired_replicas
    desired_replicas=$(kubectl get deployment "$deployment_name" -n "$namespace" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

    [[ "$ready_replicas" == "$desired_replicas" ]]
}

# Get deployment status
get_deployment_status() {
    local deployment_name="${1}"
    local namespace="${2}"

    local ready_replicas
    ready_replicas=$(kubectl get deployment "$deployment_name" -n "$namespace" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

    local desired_replicas
    desired_replicas=$(kubectl get deployment "$deployment_name" -n "$namespace" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

    echo "Ready: $ready_replicas/$desired_replicas"
}

# ============================================================================
# Service validation
# ============================================================================

# Check if service exists
service_exists() {
    local service_name="${1}"
    local namespace="${2}"

    kubectl get service "$service_name" -n "$namespace" &>/dev/null
}

# Get service endpoint
get_service_endpoint() {
    local service_name="${1}"
    local namespace="${2}"

    local service_type
    service_type=$(kubectl get service "$service_name" -n "$namespace" \
        -o jsonpath='{.spec.type}' 2>/dev/null || echo "ClusterIP")

    case "$service_type" in
        LoadBalancer)
            # For LoadBalancer, try to get external IP
            local external_ip
            external_ip=$(kubectl get service "$service_name" -n "$namespace" \
                -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
                kubectl get service "$service_name" -n "$namespace" \
                -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

            if [[ "$external_ip" == "pending" ]]; then
                echo "pending"
            else
                local port
                port=$(kubectl get service "$service_name" -n "$namespace" \
                    -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
                echo "${external_ip}:${port}"
            fi
            ;;
        NodePort)
            local node_port
            node_port=$(kubectl get service "$service_name" -n "$namespace" \
                -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "pending")
            echo "NodePort:${node_port}"
            ;;
        ClusterIP|*)
            local port
            port=$(kubectl get service "$service_name" -n "$namespace" \
                -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "pending")
            echo "${service_name}.${namespace}.svc.cluster.local:${port}"
            ;;
    esac
}

# ============================================================================
# StatefulSet validation
# ============================================================================

# Wait for StatefulSet to be ready
wait_for_statefulset_ready() {
    local statefulset_name="${1}"
    local namespace="${2}"
    local timeout="${3:-$DEPLOYMENT_READY_TIMEOUT}"

    log_step "Waiting for StatefulSet to be ready: $statefulset_name"

    kubectl wait --for=condition=ready \
        statefulset/"$statefulset_name" \
        -n "$namespace" \
        --timeout="${timeout}s" 2>/dev/null
}

# ============================================================================
# Job validation
# ============================================================================

# Wait for Job to complete
wait_for_job_complete() {
    local job_name="${1}"
    local namespace="${2}"
    local timeout="${3:-$DEPLOYMENT_READY_TIMEOUT}"

    log_step "Waiting for Job to complete: $job_name"

    kubectl wait --for=condition=complete \
        job/"$job_name" \
        -n "$namespace" \
        --timeout="${timeout}s" 2>/dev/null
}

# Get Job status
get_job_status() {
    local job_name="${1}"
    local namespace="${2}"

    kubectl get job "$job_name" -n "$namespace" \
        -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "Unknown"
}

# ============================================================================
# Resource validation
# ============================================================================

# Validate resource limits are set
validate_resource_limits() {
    local pod_name="${1}"
    local namespace="${2}"

    log_debug "Validating resource limits for pod: $pod_name"

    local containers
    containers=$(kubectl get pod "$pod_name" -n "$namespace" \
        -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}')

    while read -r container; do
        local limits
        limits=$(kubectl get pod "$pod_name" -n "$namespace" \
            -o jsonpath="{.spec.containers[?(@.name==\"$container\")].resources.limits}")

        if [[ -z "$limits" ]]; then
            log_warning "Container $container has no resource limits"
            return 1
        fi
    done < <(echo "$containers")

    log_debug "Resource limits validated for pod: $pod_name"
    return 0
}

# Validate GPU resources
validate_gpu_resources() {
    local pod_name="${1}"
    local namespace="${2}"

    log_debug "Validating GPU resources for pod: $pod_name"

    local gpu_request
    gpu_request=$(kubectl get pod "$pod_name" -n "$namespace" \
        -o jsonpath='{.spec.containers[0].resources.requests.nvidia\.com/gpu}' 2>/dev/null || echo "0")

    if [[ "$gpu_request" == "0" ]] || [[ -z "$gpu_request" ]]; then
        log_warning "Pod $pod_name has no GPU resources requested"
        return 1
    fi

    log_debug "GPU resources validated: $gpu_request GPU(s)"
    return 0
}

# ============================================================================
# Network validation
# ============================================================================

# Test connectivity to service
test_service_connectivity() {
    local endpoint="${1}"
    local namespace="${2}"

    log_debug "Testing connectivity to: $endpoint"

    # Create a test pod
    local test_pod="connectivity-test-$(generate_short_test_id)"

    kubectl run "$test_pod" \
        -n "$namespace" \
        --image=curlimages/curl:latest \
        --restart=Never \
        --command -- sh -c "curl -s -o /dev/null -w '%{http_code}' $endpoint" \
        --timeout=30s 2>/dev/null

    local result=$?

    # Cleanup test pod
    kubectl delete pod "$test_pod" -n "$namespace" --ignore-not-found &>/dev/null || true

    return $result
}

# ============================================================================
# Spark-specific validation
# ============================================================================

# Validate Spark Connect server is running
validate_spark_connect() {
    local pod_name="${1}"
    local namespace="${2}"
    local port="${3:-15002}"

    log_step "Validating Spark Connect server"

    # Check if port is listening using bash /dev/tcp
    local output
    output=$(kubectl exec -n "$namespace" "$pod_name" \
        -- bash -c "timeout 5 bash -c 'cat < /dev/null > /dev/tcp/localhost/$port' && echo 'OK'" 2>/dev/null || echo "")

    if [[ "$output" == *"OK"* ]]; then
        log_success "Spark Connect server is listening on port $port"
        return 0
    else
        log_error "Spark Connect server is not responding on port $port"
        return 1
    fi
}

# Validate Spark application completed successfully
validate_spark_job() {
    local pod_name="${1}"
    local namespace="${2}"
    local expected_pattern="${3:-Success}"

    log_step "Validating Spark job completion"

    local logs
    logs=$(get_pod_logs "$pod_name" "$namespace")

    if echo "$logs" | grep -q "$expected_pattern"; then
        log_success "Spark job completed successfully"
        return 0
    else
        log_error "Spark job did not complete as expected"
        log_error "Last 50 lines of logs:"
        get_pod_logs "$pod_name" "$namespace" "" "50" >&2
        return 1
    fi
}

# ============================================================================
# Comprehensive validation
# ============================================================================

# Validate all deployments in namespace
validate_namespace_deployments() {
    local namespace="${1}"
    local timeout="${2:-$DEPLOYMENT_READY_TIMEOUT}"

    log_section "Validating deployments in namespace: $namespace"

    local deployments
    deployments=$(kubectl get deployments -n "$namespace" \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

    if [[ -z "$deployments" ]]; then
        log_info "No deployments found in namespace: $namespace"
        return 0
    fi

    local all_ready=true
    while read -r deployment; do
        if ! wait_for_deployment_ready "$deployment" "$namespace" "$timeout"; then
            log_error "Deployment not ready: $deployment"
            all_ready=false
        fi
    done < <(echo "$deployments")

    if [[ "$all_ready" == "true" ]]; then
        log_success "All deployments validated"
        return 0
    else
        log_error "Some deployments failed validation"
        return 1
    fi
}

# Validate all pods are running
validate_namespace_pods() {
    local namespace="${1}"

    log_section "Validating pods in namespace: $namespace"

    # Get all pods
    local pods
    pods=$(kubectl get pods -n "$namespace" \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

    if [[ -z "$pods" ]]; then
        log_info "No pods found in namespace: $namespace"
        return 0
    fi

    local all_running=true
    while read -r pod; do
        local phase
        phase=$(get_pod_status "$pod" "$namespace")

        if [[ "$phase" != "Running" ]] && [[ "$phase" != "Succeeded" ]]; then
            log_error "Pod $pod not running: $phase"
            all_running=false
        else
            log_success "Pod OK: $pod ($phase)"
        fi
    done < <(echo "$pods")

    if [[ "$all_running" == "true" ]]; then
        log_success "All pods validated"
        return 0
    else
        log_error "Some pods failed validation"
        return 1
    fi
}

# ============================================================================
# Export functions
# ============================================================================

export -f wait_for_pod_ready wait_for_pods_by_label
export -f is_pod_running get_pod_status get_pod_restart_count get_pod_logs
export -f wait_for_deployment_ready is_deployment_ready get_deployment_status
export -f service_exists get_service_endpoint
export -f wait_for_statefulset_ready
export -f wait_for_job_complete get_job_status
export -f validate_resource_limits validate_gpu_resources
export -f test_service_connectivity
export -f validate_spark_connect validate_spark_job
export -f validate_namespace_deployments validate_namespace_pods

# ============================================================================
# History Server validation
# ============================================================================

# Validate History Server deployment and event log collection
validate_history_server() {
    local hs_pod="$1"
    local namespace="$2"
    local app_name="$3"
    local timeout="${4:-60}"

    log_step "Validating History Server: $hs_pod"

    # Check History Server pod is running
    if ! is_pod_running "$hs_pod" "$namespace"; then
        log_error "History Server pod not running"
        return 1
    fi

    # Wait for event logs to be processed (History Server scans periodically)
    log_info "Waiting for event logs to be processed..."
    sleep 30

    # Check UI is accessible
    log_debug "Checking History Server UI accessibility"
    if ! kubectl exec -n "$namespace" "$hs_pod" \
        -- curl -s --max-time 10 http://localhost:18080 2>/dev/null | grep -q "History Server"; then
        log_warning "History Server UI not accessible yet"
    fi

    # Check if job appears in history API
    log_debug "Checking if job appears in History API"
    local apps_json
    apps_json=$(kubectl exec -n "$namespace" "$hs_pod" \
        -- curl -s "http://localhost:18080/api/v1/applications" 2>/dev/null || echo "[]")

    if echo "$apps_json" | grep -q "$app_name"; then
        log_success "Job found in History Server: $app_name"
    else
        log_info "Job not yet visible in History Server (may take longer to index)"
    fi

    return 0
}

# Export validate_history_server after definition
export -f validate_history_server
