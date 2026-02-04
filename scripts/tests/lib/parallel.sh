#!/bin/bash
# Parallel execution library for smoke tests
# Provides resource-aware parallel execution with aggregated logging

# Source common library first
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ============================================================================
# Resource Detection
# ============================================================================

# Check if GPU nodes are available
check_gpu_nodes() {
    local gpu_count
    gpu_count=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}' 2>/dev/null | tr ' ' '\n' | grep -v "^$" | wc -l)
    [[ $gpu_count -gt 0 ]] && echo "true" || echo "false"
}

# Check if Hive Metastore is available
check_hive_metastore() {
    local namespace="${1:-default}"
    local hive_pods
    hive_pods=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/component=hive-metastore --no-headers 2>/dev/null | wc -l)
    [[ $hive_pods -gt 0 ]] && echo "true" || echo "false"
}

# Check if standalone Spark is available
check_standalone_available() {
    # Check for Spark Master pods
    local master_pods
    master_pods=$(kubectl get pods -A -l app.kubernetes.io/component=master --no-headers 2>/dev/null | wc -l)
    [[ $master_pods -gt 0 ]] && echo "true" || echo "false"
}

# Detect all cluster resources
detect_cluster_resources() {
    local resources=()

    local has_gpu
    has_gpu=$(check_gpu_nodes)
    resources+=("gpu:$has_gpu")

    local has_iceberg
    has_iceberg=$(check_hive_metastore)
    resources+=("iceberg:$has_iceberg")

    local has_standalone
    has_standalone=$(check_standalone_available)
    resources+=("standalone:$has_standalone")

    echo "${resources[@]}"
}

# ============================================================================
# Scenario Parsing
# ============================================================================

# Parse YAML frontmatter from scenario file
parse_yaml_frontmatter() {
    local file="$1"
    local field="$2"

    # Extract value between @meta and @endmeta
    sed -n '/^# @meta$/,/^# @endmeta$/p' "$file" | \
        grep "^# $field:" | \
        sed 's/^# '"$field"': *//' | \
        tr -d '\r'
}

# Get scenario features from frontmatter
get_scenario_features() {
    local file="$1"
    parse_yaml_frontmatter "$file" "features"
}

# Get scenario tags from frontmatter
get_scenario_tags() {
    local file="$1"
    parse_yaml_frontmatter "$file" "tags"
}

# Check if scenario requires GPU
scenario_requires_gpu() {
    local file="$1"
    local features
    features=$(get_scenario_features "$file")
    [[ "$features" =~ "gpu" ]]
}

# Check if scenario requires Iceberg
scenario_requires_iceberg() {
    local file="$1"
    local features
    features=$(get_scenario_features "$file")
    [[ "$features" =~ "iceberg" ]]
}

# Check if scenario should skip based on resources
should_skip_scenario() {
    local file="$1"
    local reason=""

    if scenario_requires_gpu "$file"; then
        local has_gpu
        has_gpu=$(check_gpu_nodes)
        if [[ "$has_gpu" != "true" ]]; then
            echo "gpu"
            return 0
        fi
    fi

    if scenario_requires_iceberg "$file"; then
        local has_iceberg
        has_iceberg=$(check_hive_metastore)
        if [[ "$has_iceberg" != "true" ]]; then
            echo "iceberg"
            return 0
        fi
    fi

    echo "" # No skip
    return 0
}

# ============================================================================
# Parallel Execution
# ============================================================================

# Maximum parallel jobs
MAX_PARALLEL="${MAX_PARALLEL:-5}"

# Run scenarios in parallel with resource awareness
run_scenarios_parallel() {
    local scenario_files=("$@")
    declare -a pids=()
    declare -a skip_list=()

    log_section "Running ${#scenario_files[@]} scenarios in parallel (max $MAX_PARALLEL concurrent)"

    # Detect available resources
    local resources
    mapfile -t resources < <(detect_cluster_resources)
    log_info "Available resources: ${resources[*]}"

    # Filter scenarios that should skip
    for scenario_file in "${scenario_files[@]}"; do
        local skip_reason
        skip_reason=$(should_skip_scenario "$scenario_file")

        if [[ -n "$skip_reason" ]]; then
            local name
            name=$(basename "$scenario_file")
            log_warning "Skipping $name (no $skip_reason available)"
            skip_list+=("$scenario_file")
        fi
    done

    # Run non-skipped scenarios in parallel
    local running=0
    for scenario_file in "${scenario_files_files[@]}"; do
        # Skip if in skip list
        if [[ " ${skip_list[@]} " =~ " $scenario_file " ]]; then
            continue
        fi

        # Wait if max parallel reached
        while [[ $running -ge $MAX_PARALLEL ]]; do
            sleep 1
            running=0
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    ((running++))
                fi
            done
        done

        # Run scenario in background
        (
            bash "$scenario_file" 2>&1 | tee -a "/tmp/parallel-$$.log"
        ) &
        pids+=($!)
        ((running++))

        local name
        name=$(basename "$scenario_file")
        log_debug "Started: $name (PID: ${pids[-1]})"
    done

    # Wait for all background jobs
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
        fi
    done

    log_success "Parallel execution complete. Failed: $failed/${#pids[@]}"
    return $failed
}

# Aggregate logs from parallel runs
aggregate_parallel_logs() {
    local log_dir="${1:-/tmp/parallel-logs}"
    local output_file="${2:-/tmp/parallel-aggregated.log}"

    mkdir -p "$log_dir"

    echo "# Parallel Execution Aggregated Log - $(date)" > "$output_file"
    echo "" >> "$output_file"

    for log_file in "$log_dir"/parallel-*.log; do
        if [[ -f "$log_file" ]]; then
            echo "=== $(basename "$log_file") ===" >> "$output_file"
            cat "$log_file" >> "$output_file"
            echo "" >> "$output_file"
        fi
    done

    log_success "Aggregated logs to: $output_file"
}

# Retry failed scenarios
retry_failed_scenarios() {
    local failed_list="$1"
    local max_attempts="${2:-3}"

    if [[ -z "$failed_list" ]]; then
        log_info "No failed scenarios to retry"
        return 0
    fi

    log_section "Retrying failed scenarios (max $max_attempts attempts)"

    local attempt=1
    local remaining=($failed_list)

    while [[ $attempt -le $max_attempts && ${#remaining[@]} -gt 0 ]]; do
        log_info "Retry attempt $attempt/$max_attempts (${#remaining[@]} scenarios)"

        declare -a still_failing=()

        for scenario_file in "${remaining[@]}"; do
            if bash "$scenario_file"; then
                log_success "Retry succeeded: $(basename "$scenario_file")"
            else
                log_error "Retry failed: $(basename "$scenario_file")"
                still_failing+=("$scenario_file")
            fi
        done

        remaining=("${still_failing[@]}")
        ((attempt++))
    done

    if [[ ${#remaining[@]} -gt 0 ]]; then
        log_error "Failed after $max_attempts retries: ${#remaining[@]} scenarios"
        return 1
    else
        log_success "All scenarios passed after retry"
        return 0
    fi
}

# ============================================================================
# Export functions
# ============================================================================

export -f check_gpu_nodes check_hive_metastore check_standalone_available
export -f detect_cluster_resources
export -f parse_yaml_frontmatter get_scenario_features get_scenario_tags
export -f scenario_requires_gpu scenario_requires_iceberg should_skip_scenario
export -f run_scenarios_parallel aggregate_parallel_logs retry_failed_scenarios
