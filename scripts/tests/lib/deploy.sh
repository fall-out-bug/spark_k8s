#!/bin/bash
# Deploy level: helm install + kubectl wait for Ready
# Usage: deploy.sh RELEASE CHART NAMESPACE [--set k=v]...
# Env: DEPLOY_TIMEOUT (default 300), HELM_TIMEOUT (default 10m)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/helm.sh"

DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-300}"
HELM_TIMEOUT="${HELM_TIMEOUT:-10m}"

deploy_matrix_scenario() {
    local release="${1:?release required}"
    local chart="${2:?chart required}"
    local namespace="${3:?namespace required}"
    shift 3
    local set_args=("$@")

    log_step "Deploy: helm install $release $chart -n $namespace"
    kubectl create namespace "$namespace" 2>/dev/null || true

    local helm_cmd=(helm install "$release" "$chart" -n "$namespace" --create-namespace --timeout "$HELM_TIMEOUT" --wait)
    helm_cmd+=("${set_args[@]}")

    if ! "${helm_cmd[@]}"; then
        log_error "Helm install failed"
        helm uninstall "$release" -n "$namespace" 2>/dev/null || true
        kubectl delete namespace "$namespace" --timeout=60s 2>/dev/null || true
        return 1
    fi

    log_step "Waiting for connect pod Ready (timeout ${DEPLOY_TIMEOUT}s)"
    if ! kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/component=connect \
        -n "$namespace" \
        --timeout="${DEPLOY_TIMEOUT}s" 2>/dev/null; then
        log_error "kubectl wait timeout"
        helm uninstall "$release" -n "$namespace" 2>/dev/null || true
        kubectl delete namespace "$namespace" --timeout=60s 2>/dev/null || true
        return 1
    fi

    log_success "Deploy complete: $release"
    return 0
}

# When run as script (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 4 ]]; then
        echo "Usage: $0 RELEASE CHART NAMESPACE [--set k=v]..."
        exit 1
    fi
    release=$1
    chart=$2
    namespace=$3
    shift 3
    deploy_matrix_scenario "$release" "$chart" "$namespace" "$@"
    exit $?
fi
