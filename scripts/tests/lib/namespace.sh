#!/bin/bash
# Namespace and release name management for test isolation
# Each test gets unique namespace and release name to enable parallel execution

# Source common library first
# shellcheck source=scripts/tests/lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# Constants
# ============================================================================

NAMESPACE_PREFIX="spark-test"
RELEASE_PREFIX="test"

# ============================================================================
# ID generation
# ============================================================================

# Generate unique test ID with timestamp and random number
# Format: YYYYMMDD-HHMMSS-RANDOM
generate_test_id() {
    echo "$(date +%Y%m%d-%H%M%S)-${RANDOM}"
}

# Generate short test ID (for shorter names)
# Format: RANDOM-TIMESTAMP (last 6 digits)
generate_short_test_id() {
    echo "${RANDOM}-$(date +%s | tail -c 6)"
}

# ============================================================================
# Namespace management
# ============================================================================

# Create unique namespace for test
create_namespace() {
    local suffix="${1:-$(generate_test_id)}"
    local ns_name="${NAMESPACE_PREFIX}-${suffix}"

    log_step "Creating namespace: $ns_name"

    # Try to create namespace
    if kubectl create namespace "$ns_name" 2>/dev/null; then
        log_success "Namespace created: $ns_name"
        echo "$ns_name"
        return 0
    fi

    # If already exists, generate new one
    if kubectl get namespace "$ns_name" &>/dev/null; then
        log_warning "Namespace already exists, generating new name..."
        create_namespace "$(generate_test_id)"
        return $?
    fi

    # Other error
    log_error "Failed to create namespace: $ns_name"
    return 1
}

# Delete namespace (with force option)
delete_namespace() {
    local ns_name="${1}"
    local force="${2:-false}"

    if [[ -z "$ns_name" ]]; then
        log_error "Namespace name required"
        return 1
    fi

    # Check if namespace exists
    if ! kubectl get namespace "$ns_name" &>/dev/null; then
        log_debug "Namespace does not exist: $ns_name"
        return 0
    fi

    log_step "Deleting namespace: $ns_name"

    local cmd="kubectl delete namespace $ns_name"

    if [[ "$force" == "true" ]]; then
        cmd="$cmd --force --grace-period=0"
    fi

    if $cmd &>/dev/null; then
        log_success "Namespace deleted: $ns_name"
        return 0
    fi

    # Force delete if normal delete failed
    if [[ "$force" != "true" ]]; then
        log_warning "Normal delete failed, trying force delete..."
        delete_namespace "$ns_name" true
        return $?
    fi

    log_error "Failed to delete namespace: $ns_name"
    return 1
}

# Wait for namespace to be deleted
wait_namespace_deleted() {
    local ns_name="${1}"
    local timeout="${2:-120}"

    log_step "Waiting for namespace deletion: $ns_name"

    wait_for "! kubectl get namespace $ns_name &>/dev/null" "$timeout"
}

# Get namespace status
get_namespace_status() {
    local ns_name="${1}"

    kubectl get namespace "$ns_name" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound"
}

# List all test namespaces
list_test_namespaces() {
    kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | \
        grep "^${NAMESPACE_PREFIX}-" || true
}

# ============================================================================
# Release name management
# ============================================================================

# Create unique Helm release name
create_release_name() {
    local base="${1:-spark}"
    local suffix="${2:-$(generate_short_test_id)}"

    echo "${RELEASE_PREFIX}-${base}-${suffix}"
}

# Check if Helm release exists
release_exists() {
    local release_name="${1}"
    local namespace="${2}"

    helm status "$release_name" -n "$namespace" &>/dev/null
}

# List Helm releases in namespace
list_releases() {
    local namespace="${1}"

    helm list -n "$namespace" -o json | \
        jq -r '.[] | .name' 2>/dev/null || \
        helm list -n "$namespace" -q 2>/dev/null || true
}

# ============================================================================
# Combined namespace + release operations
# ============================================================================

# Create both namespace and release name for a test
setup_test_environment() {
    local component="${1:-spark}"
    local test_id="${2:-$(generate_test_id)}"

    # Create unique namespace
    local ns_name
    ns_name="$(create_namespace "$test_id")"

    # Create unique release name
    local release_name
    release_name="$(create_release_name "$component" "$(generate_short_test_id)")"

    # Return as space-separated values
    echo "$ns_name $release_name"
}

# Cleanup both namespace and release
cleanup_test_environment() {
    local release_name="${1}"
    local namespace="${2}"
    local force="${3:-false}"

    if [[ -z "$namespace" ]]; then
        log_error "Namespace required for cleanup"
        return 1
    fi

    # Uninstall Helm release if specified
    if [[ -n "$release_name" ]]; then
        if release_exists "$release_name" "$namespace"; then
            log_step "Uninstalling Helm release: $release_name"
            helm uninstall "$release_name" -n "$namespace" --ignore-not-found || true
        fi
    fi

    # Delete namespace
    delete_namespace "$namespace" "$force"

    # Wait for deletion to complete
    wait_namespace_deleted "$namespace"
}

# ============================================================================
# Namespace pool management (for limited parallel execution)
# ============================================================================

# Get available namespace from pool
get_namespace_from_pool() {
    local pool_size="${1:-10}"
    local pool_base="${2:-spark-test-pool}"

    # Find available namespace number
    for i in $(seq 1 "$pool_size"); do
        local ns_name="${pool_base}-${i}"

        # Check if namespace exists and is available
        if ! kubectl get namespace "$ns_name" &>/dev/null; then
            # Create namespace
            kubectl create namespace "$ns_name" 2>/dev/null && echo "$ns_name" && return 0
        else
            # Check if namespace has no active deployments
            local deployment_count
            deployment_count=$(kubectl get deployments -n "$ns_name" -o json 2>/dev/null | \
                jq '.items | length' 2>/dev/null || echo "0")

            if [[ "$deployment_count" -eq 0 ]]; then
                echo "$ns_name"
                return 0
            fi
        fi
    done

    log_error "No available namespace in pool (size: $pool_size)"
    return 1
}

# Return namespace to pool (cleanup)
return_namespace_to_pool() {
    local ns_name="${1}"
    local force="${2:-false}"

    # Full cleanup of namespace
    cleanup_test_environment "" "$ns_name" "$force"
}

# ============================================================================
# Export functions
# ============================================================================

export -f generate_test_id generate_short_test_id
export -f create_namespace delete_namespace wait_namespace_deleted
export -f get_namespace_status list_test_namespaces
export -f create_release_name release_exists list_releases
export -f setup_test_environment cleanup_test_environment
export -f get_namespace_from_pool return_namespace_to_pool
