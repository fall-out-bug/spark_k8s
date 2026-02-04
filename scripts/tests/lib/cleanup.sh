#!/bin/bash
# Cleanup management for test scripts
# Handles automatic cleanup via traps and manual cleanup operations

# Source common library first
# shellcheck source=scripts/tests/lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Source namespace library
# shellcheck source=scripts/tests/lib/namespace.sh
source "${SCRIPT_DIR}/namespace.sh"

# ============================================================================
# Global state for cleanup
# ============================================================================

# Mark initialization complete (will be set by init_cleanup_arrays)
export CLEANUP_RELEASES_INIT=no

# Associative arrays to track cleanup targets
# Using -g to make global even in subshells (bash 4.2+)
# For bash 4.x, -g may not be available, fall back to regular declare
declare -A CLEANUP_NAMESPACES=()
declare -A CLEANUP_RELEASES=()
declare -A CLEANUP_PIDS=()

# Initialize on first load
CLEANUP_RELEASES_INIT=yes

# ============================================================================
# Cleanup registration
# ============================================================================

# Register a namespace for cleanup
register_namespace_cleanup() {
    local ns_name="${1}"

    # Initialize array if not exists (for subshell calls)
    [[ "${CLEANUP_RELEASES_INIT:-}" != "yes" ]] && init_cleanup_arrays 2>/dev/null

    CLEANUP_NAMESPACES["$ns_name"]=1 2>/dev/null || true
    log_debug "Registered namespace for cleanup: $ns_name"
}

# Register a Helm release for cleanup
register_release_cleanup() {
    local release_name="${1}"
    local namespace="${2}"

    # Initialize array if not exists (for subshell calls)
    # In subshells, declare -p might show the variable but not as associative array
    [[ "${CLEANUP_RELEASES_INIT:-}" != "yes" ]] && init_cleanup_arrays 2>/dev/null

    CLEANUP_RELEASES["$release_name"]="$namespace" 2>/dev/null || true
    log_debug "Registered release for cleanup: $release_name (namespace: $namespace)"
}

# Initialize cleanup arrays (idempotent)
init_cleanup_arrays() {
    [[ "${CLEANUP_RELEASES_INIT:-}" == "yes" ]] && return 0

    declare -gA CLEANUP_NAMESPACES=() 2>/dev/null || declare -A CLEANUP_NAMESPACES=()
    declare -gA CLEANUP_RELEASES=() 2>/dev/null || declare -A CLEANUP_RELEASES=()
    declare -gA CLEANUP_PIDS=() 2>/dev/null || declare -A CLEANUP_PIDS=()

    export CLEANUP_RELEASES_INIT=yes
}

# Register a PID for cleanup (will be killed on exit)
register_pid_cleanup() {
    local pid="${1}"
    local description="${2:-process}"

    # Initialize array if not exists (for subshell calls)
    [[ "${CLEANUP_RELEASES_INIT:-}" != "yes" ]] && init_cleanup_arrays 2>/dev/null

    CLEANUP_PIDS["$pid"]="$description" 2>/dev/null || true
    log_debug "Registered PID for cleanup: $pid ($description)"
}

# Unregister from cleanup (for successful manual cleanup)
unregister_namespace_cleanup() {
    local ns_name="${1}"
    unset CLEANUP_NAMESPACES["$ns_name"] 2>/dev/null || true
    log_debug "Unregistered namespace from cleanup: $ns_name"
}

unregister_release_cleanup() {
    local release_name="${1}"
    unset CLEANUP_RELEASES["$release_name"] 2>/dev/null || true
    log_debug "Unregistered release from cleanup: $release_name"
}

# ============================================================================
# Cleanup operations
# ============================================================================

# Cleanup specific Helm release
cleanup_release() {
    local release_name="${1}"
    local namespace="${2}"
    local force="${3:-false}"

    if [[ -z "$release_name" ]] || [[ -z "$namespace" ]]; then
        log_error "Release name and namespace required"
        return 1
    fi

    log_step "Cleaning up Helm release: $release_name"

    # Check if release exists
    if ! release_exists "$release_name" "$namespace"; then
        log_debug "Release does not exist: $release_name"
        return 0
    fi

    # Try normal uninstall first
    if helm uninstall "$release_name" -n "$namespace" --ignore-not-found 2>/dev/null; then
        log_success "Release uninstalled: $release_name"
        return 0
    fi

    # Force delete resources if normal uninstall failed
    if [[ "$force" == "true" ]]; then
        log_warning "Force deleting release resources..."

        # Delete all resources owned by the release
        kubectl delete all \
            -l "app.kubernetes.io/instance=${release_name}" \
            -n "$namespace" \
            --force --grace-period=0 2>/dev/null || true

        # Delete secrets
        kubectl delete secrets \
            -l "app.kubernetes.io/instance=${release_name}" \
            -n "$namespace" 2>/dev/null || true

        # Delete configmaps
        kubectl delete configmaps \
            -l "app.kubernetes.io/instance=${release_name}" \
            -n "$namespace" 2>/dev/null || true
    fi

    return 0
}

# Force delete all pods in namespace (for stuck pods)
force_delete_pods() {
    local namespace="${1}"

    log_step "Force deleting pods in namespace: $namespace"

    kubectl delete pods \
        -n "$namespace" \
        --all \
        --force \
        --grace-period=0 2>/dev/null || true

    log_success "Pods force deleted in: $namespace"
}

# Cleanup specific namespace
cleanup_namespace() {
    local ns_name="${1}"
    local force="${2:-false}"

    if [[ -z "$ns_name" ]]; then
        log_error "Namespace name required"
        return 1
    fi

    log_step "Cleaning up namespace: $ns_name"

    delete_namespace "$ns_name" "$force"
}

# Cleanup all registered resources
cleanup_all_registered() {
    local force="${1:-false}"

    log_info "Running cleanup for all registered resources..."

    # Cleanup Helm releases first
    for release_name in "${!CLEANUP_RELEASES[@]}"; do
        local namespace="${CLEANUP_RELEASES[$release_name]}"
        cleanup_release "$release_name" "$namespace" "$force"
    done

    # Cleanup namespaces
    for ns_name in "${!CLEANUP_NAMESPACES[@]}"; do
        cleanup_namespace "$ns_name" "$force"
    done

    # Kill registered PIDs
    for pid in "${!CLEANUP_PIDS[@]}"; do
        local description="${CLEANUP_PIDS[$pid]}"
        log_step "Killing PID $pid ($description)"

        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            # Wait a bit for graceful shutdown
            sleep 2
            # Force kill if still running
            kill -9 "$pid" 2>/dev/null || true
        fi
    done

    # Clear registries
    CLEANUP_NAMESPACES=()
    CLEANUP_RELEASES=()
    CLEANUP_PIDS=()

    log_success "Cleanup completed"
}

# ============================================================================
# Trap management
# ============================================================================

# Set up automatic cleanup on script exit
setup_cleanup_trap() {
    local release_name="${1}"
    local namespace="${2}"

    # Register resources
    register_release_cleanup "$release_name" "$namespace"
    register_namespace_cleanup "$namespace"

    # Set trap for EXIT, TERM, INT
    trap 'on_exit_cleanup' EXIT TERM INT

    log_debug "Cleanup trap set for release: $release_name (namespace: $namespace)"
}

# Set up custom cleanup function
setup_custom_cleanup_trap() {
    local cleanup_function="${1}"

    # Set trap for EXIT, TERM, INT
    trap "$cleanup_function" EXIT TERM INT

    log_debug "Custom cleanup trap set: $cleanup_function"
}

# Exit handler (called by trap)
on_exit_cleanup() {
    local exit_code=$?

    # Don't cleanup on successful exit (exit code 0) unless explicitly requested
    if [[ $exit_code -eq 0 ]] && [[ "${CLEANUP_ON_SUCCESS:-false}" != "true" ]]; then
        log_info "Script completed successfully, skipping cleanup (resources preserved)"
        log_info "To cleanup manually, run: cleanup_all_registered true"
        return 0
    fi

    # Determine if force cleanup is needed
    local force="false"
    if [[ $exit_code -ne 0 ]]; then
        force="true"
    fi

    log_warning "Script exiting with code $exit_code, running cleanup..."
    cleanup_all_registered "$force"
}

# Enable cleanup on successful exit
enable_cleanup_on_success() {
    export CLEANUP_ON_SUCCESS="true"
    log_debug "Cleanup on success enabled"
}

# Disable cleanup on successful exit (default)
disable_cleanup_on_success() {
    export CLEANUP_ON_SUCCESS="false"
    log_debug "Cleanup on success disabled"
}

# ============================================================================
# Cleanup orphaned resources
# ============================================================================

# Find and cleanup orphaned test namespaces (older than specified hours)
cleanup_orphaned_namespaces() {
    local older_than_hours="${1:-24}"

    log_info "Cleaning up orphaned test namespaces (older than ${older_than_hours}h)..."

    local cutoff_time
    cutoff_time=$(date -d "${older_than_hours} hours ago" +%s 2>/dev/null || \
                  date -v-${older_than_hours}H +%s 2>/dev/null)

    if [[ -z "$cutoff_time" ]]; then
        log_error "Could not calculate cutoff time"
        return 1
    fi

    local deleted=0
    while read -r ns_name; do
        if [[ -z "$ns_name" ]]; then
            continue
        fi

        # Get namespace creation time
        local creation_time
        creation_time=$(kubectl get namespace "$ns_name" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || echo "")

        if [[ -z "$creation_time" ]]; then
            continue
        fi

        # Convert to timestamp
        local creation_ts
        creation_ts=$(date -d "$creation_time" +%s 2>/dev/null || \
                      date -j -f "%Y-%m-%dT%H:%M:%SZ" "$creation_time" +%s 2>/dev/null)

        if [[ -z "$creation_ts" ]]; then
            continue
        fi

        # Delete if older than cutoff
        if [[ $creation_ts -lt $cutoff_time ]]; then
            log_step "Deleting orphaned namespace: $ns_name (created: $creation_time)"
            delete_namespace "$ns_name" true
            ((deleted++))
        fi
    done < <(list_test_namespaces)

    log_success "Deleted $deleted orphaned namespace(s)"
}

# Find and cleanup stuck pods in test namespaces
cleanup_stuck_pods() {
    local namespace_regex="${1:-^spark-test-}"

    log_info "Cleaning up stuck pods in namespaces matching: $namespace_regex"

    while read -r ns_name; do
        if [[ -z "$ns_name" ]]; then
            continue
        fi

        # Find stuck pods (Pending, Unknown, or terminating too long)
        local stuck_pods
        stuck_pods=$(kubectl get pods -n "$ns_name" \
            -o jsonpath='{range .items[?(@.status.phase=="Pending" || @.status.phase=="Unknown")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

        if [[ -n "$stuck_pods" ]]; then
            log_step "Deleting stuck pods in namespace: $ns_name"
            echo "$stuck_pods" | while read -r pod_name; do
                kubectl delete pod "$pod_name" -n "$ns_name" --force --grace-period=0 2>/dev/null || true
            done
        fi
    done < <(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "$namespace_regex" || true)
}

# ============================================================================
# Export functions
# ============================================================================

export -f register_namespace_cleanup register_release_cleanup register_pid_cleanup
export -f unregister_namespace_cleanup unregister_release_cleanup
export -f cleanup_release cleanup_namespace force_delete_pods cleanup_all_registered
export -f setup_cleanup_trap setup_custom_cleanup_trap on_exit_cleanup
export -f enable_cleanup_on_success disable_cleanup_on_success
export -f cleanup_orphaned_namespaces cleanup_stuck_pods
