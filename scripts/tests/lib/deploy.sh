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

dump_namespace_diagnostics() {
    local namespace="${1:?namespace required}"
    kubectl get pods -n "$namespace" -o wide 2>/dev/null || true
    kubectl get events -n "$namespace" --sort-by=.lastTimestamp 2>/dev/null || true
    local pod
    while read -r pod; do
        [[ -z "$pod" ]] && continue
        kubectl logs -n "$namespace" "$pod" --all-containers=true --tail=120 2>/dev/null || true
    done < <(kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
}

deploy_matrix_scenario() {
    local release="${1:?release required}"
    local chart="${2:?chart required}"
    local namespace="${3:?namespace required}"
    shift 3
    local set_args=("$@")

    log_step "Deploy: helm install $release $chart -n $namespace"
    kubectl create namespace "$namespace" 2>/dev/null || true

    if helm status "$release" -n "$namespace" >/dev/null 2>&1; then
        log_warning "Release $release already exists in $namespace; uninstalling stale release"
        if ! helm uninstall "$release" -n "$namespace" --wait >/dev/null 2>&1; then
            log_error "Failed to uninstall existing release $release"
            return 1
        fi
    fi

    kubectl delete secret,configmap \
        -n "$namespace" \
        -l "owner=helm,name=$release" \
        --ignore-not-found=true >/dev/null 2>&1 || true

    local helm_cmd=(helm install "$release" "$chart" -n "$namespace" --create-namespace --timeout "$HELM_TIMEOUT" --wait)
    helm_cmd+=("${set_args[@]}")

    if ! "${helm_cmd[@]}"; then
        log_error "Helm install failed"
        dump_namespace_diagnostics "$namespace"
        helm uninstall "$release" -n "$namespace" 2>/dev/null || true
        kubectl delete namespace "$namespace" --timeout=60s 2>/dev/null || true
        return 1
    fi

    local deploy_mode="${DEPLOY_MODE:-connect}"
    local label=""
    case "$deploy_mode" in
        connect) label="app.kubernetes.io/component=connect" ;;
        k8s-native) label="app.kubernetes.io/component=k8s-native-submitter" ;;
        standalone) label="app.kubernetes.io/component=standalone-master" ;;
        *) label="app.kubernetes.io/component=connect" ;;
    esac
    log_step "Waiting for $deploy_mode pod Ready (timeout ${DEPLOY_TIMEOUT}s)"
    if ! kubectl wait --for=condition=ready pod \
        -l "$label" \
        -n "$namespace" \
        --timeout="${DEPLOY_TIMEOUT}s" 2>/dev/null; then
        log_error "kubectl wait timeout"
        dump_namespace_diagnostics "$namespace"
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
