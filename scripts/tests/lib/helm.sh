#!/bin/bash
# Helm operations library for test scripts
# Provides wrapper functions for Helm install, upgrade, uninstall, status

# Source common library first
# shellcheck source=scripts/tests/lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# Constants
# ============================================================================

HELM_TIMEOUT="${HELM_TIMEOUT:-10m}"  # Default Helm timeout
HELM_WAIT="${HELM_WAIT:-true}"        # Wait for resources to be ready
HELM_DEBUG="${HELM_DEBUG:-false}"     # Enable Helm debug output

# ============================================================================
# Helm install operations
# ============================================================================

# Install Helm chart with values
helm_install() {
    local release_name="${1}"
    local chart_path="${2}"
    local namespace="${3}"
    shift 3
    local values_files=("$@")

    log_step "Installing Helm release: $release_name"
    log_debug "Chart: $chart_path"
    log_debug "Namespace: $namespace"

    # Build Helm command
    local cmd="helm install $release_name $chart_path --namespace $namespace"

    # Add timeout
    cmd="$cmd --timeout $HELM_TIMEOUT"

    # Add wait flag
    if [[ "$HELM_WAIT" == "true" ]]; then
        cmd="$cmd --wait"
    fi

    # Add values files
    for values_file in "${values_files[@]}"; do
        if [[ -n "$values_file" ]]; then
            cmd="$cmd --values $values_file"
        fi
    done

    # Add debug flag if enabled
    if [[ "$HELM_DEBUG" == "true" ]]; then
        cmd="$cmd --debug"
    fi

    log_debug "Helm command: $cmd"

    # Run Helm install
    if eval "$cmd"; then
        log_success "Helm release installed: $release_name"
        return 0
    else
        log_error "Helm install failed: $release_name"
        return 1
    fi
}

# Install Helm chart with inline values
helm_install_with_values() {
    local release_name="${1}"
    local chart_path="${2}"
    local namespace="${3}"
    local inline_values="${4}"

    log_step "Installing Helm release with inline values: $release_name"

    # Build Helm command
    local cmd="helm install $release_name $chart_path --namespace $namespace"
    cmd="$cmd --timeout $HELM_TIMEOUT"

    if [[ "$HELM_WAIT" == "true" ]]; then
        cmd="$cmd --wait"
    fi

    # Add inline values
    if [[ -n "$inline_values" ]]; then
        cmd="$cmd --set $inline_values"
    fi

    log_debug "Helm command: $cmd"

    if eval "$cmd"; then
        log_success "Helm release installed: $release_name"
        return 0
    else
        log_error "Helm install failed: $release_name"
        return 1
    fi
}

# ============================================================================
# Helm upgrade operations
# ============================================================================

# Upgrade existing Helm release
helm_upgrade() {
    local release_name="${1}"
    local chart_path="${2}"
    local namespace="${3}"
    shift 3
    local values_files=("$@")

    log_step "Upgrading Helm release: $release_name"

    local cmd="helm upgrade $release_name $chart_path --namespace $namespace"
    cmd="$cmd --timeout $HELM_TIMEOUT"

    if [[ "$HELM_WAIT" == "true" ]]; then
        cmd="$cmd --wait"
    fi

    for values_file in "${values_files[@]}"; do
        if [[ -n "$values_file" ]]; then
            cmd="$cmd --values $values_file"
        fi
    done

    log_debug "Helm command: $cmd"

    if eval "$cmd"; then
        log_success "Helm release upgraded: $release_name"
        return 0
    else
        log_error "Helm upgrade failed: $release_name"
        return 1
    fi
}

# ============================================================================
# Helm uninstall operations
# ============================================================================

# Uninstall Helm release
helm_uninstall() {
    local release_name="${1}"
    local namespace="${2}"
    local wait="${3:-false}"

    log_step "Uninstalling Helm release: $release_name"

    local cmd="helm uninstall $release_name --namespace $namespace"

    if [[ "$wait" == "true" ]]; then
        cmd="$cmd --wait"
    fi

    # Ignore errors if release doesn't exist
    cmd="$cmd --ignore-not-found"

    if eval "$cmd"; then
        log_success "Helm release uninstalled: $release_name"
        return 0
    else
        log_error "Helm uninstall failed: $release_name"
        return 1
    fi
}

# ============================================================================
# Helm status operations
# ============================================================================

# Get Helm release status
helm_status() {
    local release_name="${1}"
    local namespace="${2}"

    helm status "$release_name" -n "$namespace" 2>/dev/null
}

# Check if Helm release is deployed
helm_is_deployed() {
    local release_name="${1}"
    local namespace="${2}"

    local status
    status=$(helm status "$release_name" -n "$namespace" -o json 2>/dev/null | \
              jq -r '.info.status' 2>/dev/null || echo "unknown")

    [[ "$status" == "deployed" ]]
}

# Wait for Helm release to be deployed
helm_wait_for_deployed() {
    local release_name="${1}"
    local namespace="${2}"
    local timeout="${3:-300}"
    local interval="${4:-5}"

    log_step "Waiting for Helm release to be deployed: $release_name"

    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if helm_is_deployed "$release_name" "$namespace"; then
            log_success "Helm release deployed: $release_name"
            return 0
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    log_error "Timeout waiting for Helm release deployment: $release_name"
    return 1
}

# Get Helm release manifest
helm_get_manifest() {
    local release_name="${1}"
    local namespace="${2}"

    helm get manifest "$release_name" -n "$namespace" 2>/dev/null
}

# Get Helm release values
helm_get_values() {
    local release_name="${1}"
    local namespace="${2}"
    local all_values="${3:-false}"

    if [[ "$all_values" == "true" ]]; then
        helm get values "$release_name" -n "$namespace" -a 2>/dev/null
    else
        helm get values "$release_name" -n "$namespace" 2>/dev/null
    fi
}

# List Helm releases in namespace
helm_list_releases() {
    local namespace="${1}"
    local filter="${2:-}"

    local cmd="helm list -n $namespace -o json"

    if [[ -n "$filter" ]]; then
        cmd="$cmd --filter $filter"
    fi

    local releases
    releases=$(eval "$cmd" 2>/dev/null)

    if [[ -n "$releases" ]]; then
        echo "$releases" | jq -r '.[] | .name' 2>/dev/null || \
        echo "$releases" | awk 'NR>1 {print $1}'
    fi
}

# ============================================================================
# Helm template operations
# ============================================================================

# Render Helm template (for testing/validation)
helm_template_render() {
    local chart_path="${1}"
    local namespace="${2}"
    shift 2
    local values_files=("$@")

    log_debug "Rendering Helm template for chart: $chart_path"

    local cmd="helm template test-release $chart_path --namespace $namespace"

    for values_file in "${values_files[@]}"; do
        if [[ -n "$values_file" ]]; then
            cmd="$cmd --values $values_file"
        fi
    done

    if eval "$cmd"; then
        return 0
    else
        log_error "Helm template render failed"
        return 1
    fi
}

# Validate Helm chart (template validation)
helm_validate_chart() {
    local chart_path="${1}"
    local namespace="${2:-default}"
    shift 2
    local values_files=("$@")

    log_step "Validating Helm chart: $chart_path"

    if helm_template_render "$chart_path" "$namespace" "${values_files[@]}" > /dev/null; then
        log_success "Helm chart validation passed: $chart_path"
        return 0
    else
        log_error "Helm chart validation failed: $chart_path"
        return 1
    fi
}

# ============================================================================
# Helm repository operations
# ============================================================================

# Add Helm repository
helm_repo_add() {
    local repo_name="${1}"
    local repo_url="${2}"

    log_step "Adding Helm repository: $repo_name"

    if helm repo add "$repo_name" "$repo_url" 2>/dev/null; then
        log_success "Helm repository added: $repo_name"
        return 0
    else
        log_error "Failed to add Helm repository: $repo_name"
        return 1
    fi
}

# Update Helm repositories
helm_repo_update() {
    log_step "Updating Helm repositories..."

    if helm repo update 2>/dev/null; then
        log_success "Helm repositories updated"
        return 0
    else
        log_error "Failed to update Helm repositories"
        return 1
    fi
}

# ============================================================================
# Utility functions
# ============================================================================

# Get Helm version
helm_version() {
    helm version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown"
}

# Check if Helm is installed and minimum version
helm_check_version() {
    local min_version="${1:-3.0.0}"

    local current_version
    current_version=$(helm_version)

    if [[ "$current_version" == "unknown" ]]; then
        log_error "Helm is not installed"
        return 1
    fi

    log_info "Helm version: $current_version"

    # Simple version comparison (assumes semantic versioning)
    if [[ "$(echo -e "$min_version\n$current_version" | sort -V | head -n1)" == "$min_version" ]]; then
        return 0
    else
        log_error "Helm version $current_version is less than minimum required $min_version"
        return 1
    fi
}

# Parse Helm chart values file
helm_parse_values() {
    local values_file="${1}"
    local key="${2}"

    if [[ ! -f "$values_file" ]]; then
        log_error "Values file not found: $values_file"
        return 1
    fi

    yq eval "$key" "$values_file" 2>/dev/null || \
    python3 -c "import yaml, sys; print(yaml.safe_load(open('$values_file')).$key)" 2>/dev/null || \
    echo ""
}

# ============================================================================
# Export functions
# ============================================================================

export -f helm_install helm_install_with_values
export -f helm_upgrade
export -f helm_uninstall
export -f helm_status helm_is_deployed helm_wait_for_deployed
export -f helm_get_manifest helm_get_values helm_list_releases
export -f helm_template_render helm_validate_chart
export -f helm_repo_add helm_repo_update
export -f helm_version helm_check_version helm_parse_values
