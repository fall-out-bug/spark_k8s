#!/bin/bash
# Security validation library
#
# Provides functions for validating Pod Security Standards (PSS) compliance
# and OpenShift Security Context Constraints (SCC) assignment.
#
# Usage:
#   source scripts/tests/lib/security-validation.sh
#   validate_pss_restricted <pod-name> <namespace>
#   validate_scc_restricted <pod-name> <namespace>

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Validate PSS restricted compliance
#
# Checks:
# - runAsNonRoot: true
# - seccompProfile.type: RuntimeDefault
# - allowPrivilegeEscalation: false
# - capabilities.drop: ALL
#
# Args:
#   $1 - pod name
#   $2 - namespace (default: default)
#
# Returns:
#   0 if all checks pass, 1 otherwise
validate_pss_restricted() {
    local pod_name=$1
    local namespace=${2:-default}

    log_info "Validating PSS restricted for pod: $pod_name in namespace: $namespace"

    local all_checks_passed=true
    local containers=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)

    # Check 1: runAsNonRoot at pod level OR runAsUser at container level
    # PSS restricted requires: runAsNonRoot=true OR runAsUser>0 at container level
    log_info "  Checking runAsNonRoot at pod level OR runAsUser at container level..."
    local run_as_non_root=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.securityContext.runAsNonRoot}' 2>/dev/null || echo "")
    local has_container_run_as_user=false

    # Check if any container has runAsUser set
    for container in $containers; do
        local run_as_user=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath="{.spec.containers[?(@.name==\"$container\")].securityContext.runAsUser}" 2>/dev/null || echo "")
        if [[ -n "$run_as_user" && "$run_as_user" != "0" ]]; then
            has_container_run_as_user=true
            break
        fi
    done

    if [[ "$run_as_non_root" == "true" ]] || [[ "$has_container_run_as_user" == "true" ]]; then
        log_info "  PASS: runAsNonRoot=$run_as_non_root or container runAsUser is set (non-zero)"
    else
        log_error "  FAIL: Neither runAsNonRoot=true nor container runAsUser>0 is set"
        all_checks_passed=false
    fi

    # Check 2: seccompProfile at pod level
    log_info "  Checking seccompProfile.type at pod level..."
    local seccomp_type=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.securityContext.seccompProfile.type}' 2>/dev/null || echo "")
    if [[ "$seccomp_type" != "RuntimeDefault" ]]; then
        log_error "  FAIL: seccompProfile.type is not RuntimeDefault (got: '$seccomp_type')"
        all_checks_passed=false
    else
        log_info "  PASS: seccompProfile.type is RuntimeDefault"
    fi

    # Check 3: allowPrivilegeEscalation at container level
    log_info "  Checking allowPrivilegeEscalation at container level..."
    for container in $containers; do
        local allow_priv_esc=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath="{.spec.containers[?(@.name==\"$container\")].securityContext.allowPrivilegeEscalation}" 2>/dev/null || echo "")
        if [[ "$allow_priv_esc" != "false" ]]; then
            log_error "  FAIL: allowPrivilegeEscalation is not false for container '$container' (got: '$allow_priv_esc')"
            all_checks_passed=false
        else
            log_info "  PASS: allowPrivilegeEscalation is false for container '$container'"
        fi
    done

    # Check 4: capabilities.drop includes ALL at container level
    log_info "  Checking capabilities.drop at container level..."
    for container in $containers; do
        local caps_drop=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath="{.spec.containers[?(@.name==\"$container\")].securityContext.capabilities.drop}" 2>/dev/null || echo "")
        if [[ "$caps_drop" != *"ALL"* ]]; then
            log_error "  FAIL: capabilities.drop does not include ALL for container '$container' (got: '$caps_drop')"
            all_checks_passed=false
        else
            log_info "  PASS: capabilities.drop includes ALL for container '$container'"
        fi
    done

    if [[ "$all_checks_passed" == "true" ]]; then
        log_info "PSS restricted validation PASSED for pod: $pod_name"
        return 0
    else
        log_error "PSS restricted validation FAILED for pod: $pod_name"
        return 1
    fi
}

# Validate PSS baseline compliance
#
# Checks (less strict than restricted):
# - runAsNonRoot: true
# - seccompProfile.type: RuntimeDefault or undefined
#
# Args:
#   $1 - pod name
#   $2 - namespace (default: default)
#
# Returns:
#   0 if all checks pass, 1 otherwise
validate_pss_baseline() {
    local pod_name=$1
    local namespace=${2:-default}

    log_info "Validating PSS baseline for pod: $pod_name in namespace: $namespace"

    local all_checks_passed=true

    # Check 1: runAsNonRoot at pod level
    log_info "  Checking runAsNonRoot at pod level..."
    local run_as_non_root=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.securityContext.runAsNonRoot}' 2>/dev/null || echo "")
    if [[ "$run_as_non_root" != "true" ]]; then
        log_error "  FAIL: runAsNonRoot is not true (got: '$run_as_non_root')"
        all_checks_passed=false
    else
        log_info "  PASS: runAsNonRoot is true"
    fi

    # Check 2: seccompProfile at pod level (optional for baseline)
    log_info "  Checking seccompProfile.type at pod level (optional for baseline)..."
    local seccomp_type=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.securityContext.seccompProfile.type}' 2>/dev/null || echo "")
    if [[ -n "$seccomp_type" && "$seccomp_type" != "RuntimeDefault" && "$seccomp_type" != "undefined" ]]; then
        log_warn "  WARN: seccompProfile.type is '$seccomp_type' (RuntimeDefault recommended)"
    else
        log_info "  PASS: seccompProfile.type is acceptable"
    fi

    if [[ "$all_checks_passed" == "true" ]]; then
        log_info "PSS baseline validation PASSED for pod: $pod_name"
        return 0
    else
        log_error "PSS baseline validation FAILED for pod: $pod_name"
        return 1
    fi
}

# Validate SCC restricted assignment (OpenShift)
#
# Checks:
# - Pod has openshift.io/scc annotation
# - SCC is restricted (or contains restricted)
#
# Args:
#   $1 - pod name
#   $2 - namespace (default: default)
#
# Returns:
#   0 if checks pass, 1 otherwise
validate_scc_restricted() {
    local pod_name=$1
    local namespace=${2:-default}

    log_info "Validating SCC restricted for pod: $pod_name in namespace: $namespace"

    # Check SCC assignment via annotations
    local scc_name=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.metadata.annotations.openshift\.io/scc}' 2>/dev/null || echo "")

    if [[ -z "$scc_name" ]]; then
        log_warn "  WARN: No SCC annotation found (may not be OpenShift cluster)"
        return 0
    fi

    if [[ "$scc_name" == *"restricted"* ]]; then
        log_info "  PASS: Pod assigned to SCC: $scc_name"
        return 0
    else
        log_error "  FAIL: Pod not assigned to restricted SCC (got: '$scc_name')"
        return 1
    fi
}

# Validate SCC anyuid assignment (OpenShift)
#
# Checks:
# - Pod has openshift.io/scc annotation
# - SCC is anyuid
#
# Args:
#   $1 - pod name
#   $2 - namespace (default: default)
#
# Returns:
#   0 if checks pass, 1 otherwise
validate_scc_anyuid() {
    local pod_name=$1
    local namespace=${2:-default}

    log_info "Validating SCC anyuid for pod: $pod_name in namespace: $namespace"

    # Check SCC assignment via annotations
    local scc_name=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.metadata.annotations.openshift\.io/scc}' 2>/dev/null || echo "")

    if [[ -z "$scc_name" ]]; then
        log_warn "  WARN: No SCC annotation found (may not be OpenShift cluster)"
        return 0
    fi

    if [[ "$scc_name" == "anyuid" ]]; then
        log_info "  PASS: Pod assigned to SCC: $scc_name"
        return 0
    else
        log_error "  FAIL: Pod not assigned to anyuid SCC (got: '$scc_name')"
        return 1
    fi
}

# Validate PSS namespace labels
#
# Checks:
# - Namespace has pod-security.kubernetes.io/enforce label
# - Label matches expected profile
#
# Args:
#   $1 - namespace name
#   $2 - expected profile (restricted/baseline/privileged)
#
# Returns:
#   0 if checks pass, 1 otherwise
validate_pss_namespace_labels() {
    local namespace=$1
    local expected_profile=${2:-restricted}

    log_info "Validating PSS namespace labels for namespace: $namespace"

    local enforce_label=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")

    if [[ -z "$enforce_label" ]]; then
        log_error "  FAIL: No pod-security.kubernetes.io/enforce label found"
        return 1
    fi

    if [[ "$enforce_label" == "$expected_profile" ]]; then
        log_info "  PASS: PSS enforce label is '$enforce_label'"
        return 0
    else
        log_error "  FAIL: Expected PSS profile '$expected_profile', got '$enforce_label'"
        return 1
    fi
}

# Get pod name by label selector
#
# Args:
#   $1 - label selector (e.g., "app.kubernetes.io/component=connect")
#   $2 - namespace (default: default)
#   $3 - timeout in seconds (default: 60)
#
# Returns:
#   Pod name if found, empty string otherwise
get_pod_by_label() {
    local label_selector=$1
    local namespace=${2:-default}
    local timeout=${3:-60}
    local elapsed=0

    log_info "Waiting for pod with label '$label_selector' in namespace '$namespace'..."

    while [[ $elapsed -lt $timeout ]]; do
        local pod_name=$(kubectl get pods -n "$namespace" -l "$label_selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

        if [[ -n "$pod_name" ]]; then
            log_info "Found pod: $pod_name"
            echo "$pod_name"
            return 0
        fi

        sleep 2
        elapsed=$((elapsed + 2))
    done

    log_error "Timeout waiting for pod with label '$label_selector'"
    return 1
}

# Wait for pod to be ready
#
# Args:
#   $1 - pod name
#   $2 - namespace (default: default)
#   $3 - timeout in seconds (default: 120)
#
# Returns:
#   0 if pod becomes ready, 1 otherwise
wait_for_pod_ready() {
    local pod_name=$1
    local namespace=${2:-default}
    local timeout=${3:-120}

    log_info "Waiting for pod '$pod_name' to be ready..."

    if kubectl wait --for=condition=ready pod "$pod_name" -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
        log_info "Pod '$pod_name' is ready"
        return 0
    else
        log_error "Timeout waiting for pod '$pod_name' to be ready"
        return 1
    fi
}
