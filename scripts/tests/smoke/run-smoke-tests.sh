#!/bin/bash
# Main script for running smoke tests
# Supports parameterization for running individual tests or full matrix

# @meta
name: "smoke-tests"
type: "smoke"
description: "Smoke test runner for Spark K8s deployments"
version: "multiple"
component: "all"
mode: "all"
features: []
chart: "charts/spark-3.5,charts/spark-4.1"
preset: "multiple"
estimated_time: "5-15 min"
depends_on: []
tags: [smoke, matrix, validation]
# @endmeta

set -e

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source libraries
# shellcheck source=scripts/tests/lib/common.sh
source "${PROJECT_ROOT}/scripts/tests/lib/common.sh"
# shellcheck source=scripts/tests/lib/namespace.sh
source "${PROJECT_ROOT}/scripts/tests/lib/namespace.sh"
# shellcheck source=scripts/tests/lib/cleanup.sh
source "${PROJECT_ROOT}/scripts/tests/lib/cleanup.sh"
# shellcheck source=scripts/tests/lib/helm.sh
source "${PROJECT_ROOT}/scripts/tests/lib/helm.sh"
# shellcheck source=scripts/tests/lib/validation.sh
source "${PROJECT_ROOT}/scripts/tests/lib/validation.sh"
# shellcheck source=scripts/tests/lib/parallel.sh
source "${PROJECT_ROOT}/scripts/tests/lib/parallel.sh"

# Default configuration
SCENARIOS_DIR="${SCRIPT_DIR}/scenarios"
PARALLEL="${PARALLEL:-false}"
CLEANUP_ON_SUCCESS="${CLEANUP_ON_SUCCESS:-false}"
DATASET_SIZE="${DATASET_SIZE:-small}"  # small, medium, large
MAX_PARALLEL="${MAX_PARALLEL:-5}"  # Max concurrent parallel jobs
RETRY_FAILED="${RETRY_FAILED:-false}"  # Retry failed scenarios
MAX_RETRIES="${MAX_RETRIES:-3}"  # Max retry attempts
AGGREGATE_LOGS="${AGGREGATE_LOGS:-true}"  # Aggregate parallel logs

# Test matrix (14 scenarios as in current smoke tests)
SPARK_VERSIONS=("3.5.7" "3.5.8" "4.1.0" "4.1.1")
COMPONENTS=("jupyter")
MODES_35=("k8s-submit")
MODES_41=("connect-k8s" "connect-standalone")

# ============================================================================
# Argument parsing
# ============================================================================

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run smoke tests for Spark K8s deployments.

OPTIONS:
    --scenario <name>        Run specific scenario (e.g., jupyter-k8s-410)
    --version <version>      Filter by Spark version (3.5.7, 3.5.8, 4.1.0, 4.1.1)
    --component <comp>       Filter by component (jupyter)
    --mode <mode>            Filter by mode (connect-k8s, connect-standalone, k8s-submit)
    --all                    Run all smoke tests (default)
    --parallel               Run tests in parallel with resource-aware scheduling
    --max-parallel <n>       Maximum parallel jobs (default: 5)
    --retry                  Retry failed scenarios (up to 3 attempts)
    --max-retries <n>        Maximum retry attempts (default: 3)
    --no-aggregate-logs      Don't aggregate parallel logs (default: aggregate)
    --cleanup-on-success     Cleanup resources even on success
    --dataset <size>         Dataset size: small, medium, large (default: small)
    --list                   List all available scenarios
    --help                   Show this help message

EXAMPLES:
    # Run all smoke tests
    $(basename "$0") --all

    # Run specific version
    $(basename "$0") --version 4.1.0

    # Run specific scenario
    $(basename "$0") --scenario jupyter-connect-k8s-410

    # Run in parallel (experimental)
    $(basename "$0") --all --parallel

SCENARIO NAMING CONVENTION:
    <component>-<mode>-<version>
    Example: jupyter-connect-k8s-410

AVAILABLE COMPONENTS:
    jupyter       - JupyterLab with Spark integration

AVAILABLE MODES:
    connect-k8s        - Spark Connect with K8s backend (Spark 4.1 only)
    connect-standalone - Spark Connect with Standalone backend (Spark 4.1 only)
    k8s-submit         - Direct K8s submission (Spark 3.5 only)

EOF
}

parse_arguments() {
    local filter_scenario=""
    local filter_version=""
    local filter_component=""
    local filter_mode=""
    local run_all=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scenario)
                filter_scenario="$2"
                run_all=false
                shift 2
                ;;
            --version)
                filter_version="$2"
                shift 2
                ;;
            --component)
                filter_component="$2"
                shift 2
                ;;
            --mode)
                filter_mode="$2"
                shift 2
                ;;
            --all)
                run_all=true
                shift
                ;;
            --parallel)
                PARALLEL=true
                shift
                ;;
            --max-parallel)
                MAX_PARALLEL="$2"
                shift 2
                ;;
            --retry)
                RETRY_FAILED=true
                shift
                ;;
            --max-retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --no-aggregate-logs)
                AGGREGATE_LOGS=false
                shift
                ;;
            --cleanup-on-success)
                CLEANUP_ON_SUCCESS=true
                export CLEANUP_ON_SUCCESS
                shift
                ;;
            --dataset)
                DATASET_SIZE="$2"
                shift 2
                ;;
            --list)
                list_scenarios
                exit 0
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Export filters
    export FILTER_SCENARIO="$filter_scenario"
    export FILTER_VERSION="$filter_version"
    export FILTER_COMPONENT="$filter_component"
    export FILTER_MODE="$filter_mode"
    export RUN_ALL="$run_all"
    export MAX_PARALLEL="$MAX_PARALLEL"
    export RETRY_FAILED="$RETRY_FAILED"
    export MAX_RETRIES="$MAX_RETRIES"
    export AGGREGATE_LOGS="$AGGREGATE_LOGS"
}

# ============================================================================
# Scenario listing
# ============================================================================

list_scenarios() {
    echo "Available smoke test scenarios:"
    echo ""

    # List scenario files
    for scenario_file in "${SCENARIOS_DIR}"/*.sh; do
        if [[ ! -f "$scenario_file" ]]; then
            continue
        fi

        # Parse scenario name from file
        local scenario_name
        scenario_name=$(parse_yaml_frontmatter "$scenario_file" "name")

        local description
        description=$(parse_yaml_frontmatter "$scenario_file" "description")

        local version
        version=$(parse_yaml_frontmatter "$scenario_file" "version")

        local estimated_time
        estimated_time=$(parse_yaml_frontmatter "$scenario_file" "estimated_time")

        printf "  %-35s %-10s %-10s\n" "$scenario_name" "v:$version" "$estimated_time"
        printf "    %s\n\n" "$description"
    done
}

# ============================================================================
# Scenario execution
# ============================================================================

# Check if scenario matches filters
scenario_matches_filters() {
    local scenario_file="${1}"

    # Parse scenario metadata
    local name
    local version
    local component
    local mode

    name=$(parse_yaml_frontmatter "$scenario_file" "name")
    version=$(parse_yaml_frontmatter "$scenario_file" "version")
    component=$(parse_yaml_frontmatter "$scenario_file" "component")
    mode=$(parse_yaml_frontmatter "$scenario_file" "mode")

    # Apply filters
    if [[ -n "$FILTER_SCENARIO" ]]; then
        if [[ "$name" != "$FILTER_SCENARIO" ]]; then
            return 1
        fi
    fi

    if [[ -n "$FILTER_VERSION" ]]; then
        if [[ "$version" != "$FILTER_VERSION" ]]; then
            return 1
        fi
    fi

    if [[ -n "$FILTER_COMPONENT" ]]; then
        if [[ "$component" != "$FILTER_COMPONENT" ]]; then
            return 1
        fi
    fi

    if [[ -n "$FILTER_MODE" ]]; then
        if [[ "$mode" != "$FILTER_MODE" ]]; then
            return 1
        fi
    fi

    return 0
}

# Run a single scenario
run_scenario() {
    local scenario_file="${1}"
    local scenario_name
    scenario_name=$(parse_yaml_frontmatter "$scenario_file" "name")

    log_section "Running scenario: $scenario_name"

    # Execute scenario script
    if bash "$scenario_file"; then
        log_success "Scenario passed: $scenario_name"
        return 0
    else
        local exit_code=$?
        log_error "Scenario failed: $scenario_name (exit code: $exit_code)"
        return $exit_code
    fi
}

# Run scenarios in parallel
run_scenarios_parallel() {
    local scenario_files=("$@")
    local pids=()
    local results=()

    log_section "Running scenarios in parallel (${#scenario_files[@]} scenarios, max $MAX_PARALLEL concurrent)"

    # Detect available resources for intelligent skipping
    local resources
    mapfile -t resources < <(detect_cluster_resources)
    log_info "Available resources: GPU=$(get_resource_value resources "gpu"), Iceberg=$(get_resource_value resources "iceberg"), Standalone=$(get_resource_value resources "standalone")"

    # Filter and run scenarios
    local running=0
    declare -a skip_list=()
    declare -a scenario_list=()

    for scenario_file in "${scenario_files[@]}"; do
        local skip_reason
        skip_reason=$(should_skip_scenario "$scenario_file")

        if [[ -n "$skip_reason" ]]; then
            local name
            name=$(basename "$scenario_file")
            log_warning "Skipping $name (no $skip_reason available)"
            skip_list+=("$scenario_file")
            continue
        fi

        scenario_list+=("$scenario_file")

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
            local scenario_name
            scenario_name=$(parse_yaml_frontmatter "$scenario_file" "name")
            local log_file="/tmp/smoke-test-${scenario_name}-$$.log"

            if bash "$scenario_file" 2>&1 | tee "$log_file"; then
                echo "0" > "/tmp/smoke-test-${scenario_name}-$$.result"
            else
                echo "$?" > "/tmp/smoke-test-${scenario_name}-$$.result"
            fi
        ) &

        pids+=($!)
        ((running++))

        local name
        name=$(basename "$scenario_file")
        log_debug "Started: $name (PID: ${pids[-1]}, running: $running/$MAX_PARALLEL)"
    done

    # Wait for all background processes
    local failed=0
    declare -a failed_list=()

    for i in "${!pids[@]}"; do
        if ! wait "${pids[$i]}" 2>/dev/null; then
            ((failed++))
        fi
    done

    # Check results and collect failed scenarios
    for scenario_file in "${scenario_list[@]}"; do
        local scenario_name
        scenario_name=$(parse_yaml_frontmatter "$scenario_file" "name")
        local result_file="/tmp/smoke-test-${scenario_name}-$$.result"

        if [[ -f "$result_file" ]]; then
            local result
            result=$(cat "$result_file")

            if [[ "$result" != "0" ]]; then
                log_error "Scenario failed: $scenario_name"
                failed_list+=("$scenario_file")
            fi

            # Cleanup result files
            rm -f "$result_file"
            rm -f "/tmp/smoke-test-${scenario_name}-$$.log"
        fi
    done

    # Aggregate logs if requested
    if [[ "$AGGREGATE_LOGS" == "true" ]]; then
        aggregate_parallel_logs "/tmp" "/tmp/parallel-aggregated-$$.log"
    fi

    # Retry failed scenarios if enabled
    if [[ "$RETRY_FAILED" == "true" && ${#failed_list[@]} -gt 0 ]]; then
        log_section "Retrying ${#failed_list[@]} failed scenarios"

        if retry_failed_scenarios "${failed_list[@]}"; then
            log_success "All scenarios passed after retry"
            return 0
        else
            log_error "Some scenarios failed after retry"
            return 1
        fi
    elif [[ ${#failed_list[@]} -gt 0 ]]; then
        log_error "Failed scenarios: ${#failed_list[@]}"
        for scenario in "${failed_list[@]}"; do
            log_error "  - $(basename "$scenario")"
        done
        return 1
    fi

    log_success "All ${#scenario_list[@]} scenarios passed"
    return 0
}

# Helper function to get resource value from array
get_resource_value() {
    local resources=("$@")
    for resource in "${resources[@]}"; do
        local key="${resource%%:*}"
        local value="${resource##*:}"
        [[ "$key" == "$2" ]] && echo "$value"
    done
    echo "false"
}

# ============================================================================
# Main execution
# ============================================================================

main() {
    parse_arguments "$@"

    log_section "Spark K8s Smoke Tests"

    # Find all scenario files
    local scenario_files=()

    for scenario_file in "${SCENARIOS_DIR}"/*.sh; do
        if [[ ! -f "$scenario_file" ]]; then
            log_warning "No scenario files found in: $SCENARIOS_DIR"
            break
        fi

        # Check if scenario matches filters
        if scenario_matches_filters "$scenario_file"; then
            scenario_files+=("$scenario_file")
        fi
    done

    if [[ ${#scenario_files[@]} -eq 0 ]]; then
        log_error "No scenarios match the specified filters"
        list_scenarios
        exit 1
    fi

    log_info "Found ${#scenario_files[@]} scenario(s) to run"

    # Run scenarios
    local start_time
    start_time=$(date +%s)

    local exit_code=0

    if [[ "$PARALLEL" == "true" ]]; then
        run_scenarios_parallel "${scenario_files[@]}"
        exit_code=$?
    else
        for scenario_file in "${scenario_files[@]}"; do
            if ! run_scenario "$scenario_file"; then
                exit_code=1
            fi
        done
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Print summary
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        log_section "✅ All smoke tests passed! (Duration: ${duration}s)"
    else
        log_section "❌ Some smoke tests failed (Duration: ${duration}s)"
    fi

    return $exit_code
}

# ============================================================================
# Parallel execution with retry
# ============================================================================

# Run scenarios in parallel with resource awareness and retry
run_parallel_with_retry() {
    local scenario_files=("$@")

    log_section "Parallel execution with retry (max $MAX_PARALLEL concurrent)"

    if [[ "$AGGREGATE_LOGS" == "true" ]]; then
        local log_dir="/tmp/parallel-logs-$$"
        mkdir -p "$log_dir"
    fi

    declare -a failed_scenarios=()

    # First pass: run scenarios in parallel
    for scenario_file in "${scenario_files[@]}"; do
        if [[ "$PARALLEL" == "true" ]]; then
            # Run in background
            (
                bash "$scenario_file" 2>&1 | tee -a "${log_dir:-/tmp}/parallel-$$-$$.log"
            ) &
            local pid=$!

            # Track PID and scenario file
            echo "$pid:$scenario_file" >> "/tmp/parallel-pids-$$"

            # Wait if max parallel reached
            local running
            running=$(jobs | wc -l)
            while [[ $running -ge $MAX_PARALLEL ]]; do
                sleep 1
                running=$(jobs | wc -l)
            done
        else
            # Run sequentially
            if ! bash "$scenario_file"; then
                failed_scenarios+=("$scenario_file")
            fi
        fi
    done

    # Wait for all background jobs
    if [[ "$PARALLEL" == "true" ]]; then
        wait

        # Check exit codes from background jobs
        while IFS=: read -r pid_entry; do
            local pid="${pid_entry%%:*}"
            local scenario_file="${pid_entry##*:}"

            # Check if scenario failed
            if ! grep -q "Smoke test passed" "${log_dir:-/tmp}/parallel-$$-$pid.log" 2>/dev/null; then
                failed_scenarios+=("$scenario_file")
            fi
        done < "/tmp/parallel-pids-$$"

        rm -f "/tmp/parallel-pids-$$"
    fi

    # Aggregate logs if requested
    if [[ "$AGGREGATE_LOGS" == "true" && -d "${log_dir:-/tmp/parallel-logs-$$}" ]]; then
        aggregate_parallel_logs "${log_dir:-/tmp/parallel-logs-$$}" "/tmp/parallel-aggregated-$$.log"
        log_info "Aggregated logs: /tmp/parallel-aggregated-$$.log"
    fi

    # Retry failed scenarios if enabled
    if [[ "$RETRY_FAILED" == "true" && ${#failed_scenarios[@]} -gt 0 ]]; then
        log_section "Retrying ${#failed_scenarios[@]} failed scenarios"

        local attempt=1
        declare -a still_failing=()

        while [[ $attempt -le $MAX_RETRIES && ${#still_failing[@]} -ge 0 ]]; do
            log_info "Retry attempt $attempt/$MAX_RETRIES"

            still_failing=()

            for scenario_file in "${failed_scenarios[@]}"; do
                if bash "$scenario_file"; then
                    log_success "Retry succeeded: $(basename "$scenario_file")"
                else
                    log_error "Retry failed: $(basename "$scenario_file")"
                    still_failing+=("$scenario_file")
                fi
            done

            failed_scenarios=("${still_failing[@]}")
            ((attempt++))
        done
    fi

    # Report results
    local total=${#scenario_files[@]}
    local passed=$((total - ${#failed_scenarios[@]}))

    echo ""
    log_section "Parallel Execution Summary"
    echo "Total: $total, Passed: $passed, Failed: ${#failed_scenarios[@]}"

    if [[ ${#failed_scenarios[@]} -gt 0 ]]; then
        log_error "Failed scenarios:"
        for scenario in "${failed_scenarios[@]}"; do
            echo "  - $(basename "$scenario")"
        done
        return 1
    fi

    return 0
}

# ============================================================================
# Retry helper function
# ============================================================================

retry_failed_scenarios() {
    local scenario_files=("$@")
    local max_attempts="${MAX_RETRIES:-3}"
    declare -a failed_list=("${scenario_files[@]}")

    log_section "Retrying ${#failed_list[@]} scenarios (max $max_attempts attempts)"

    local attempt=1
    while [[ $attempt -le $max_attempts && ${#failed_list[@]} -gt 0 ]]; do
        log_info "Retry attempt $attempt/$max_attempts"

        declare -a still_failing=()

        for scenario_file in "${failed_list[@]}"; do
            if bash "$scenario_file"; then
                log_success "Retry succeeded: $(basename "$scenario_file")"
            else
                log_error "Retry failed: $(basename "$scenario_file")"
                still_failing+=("$scenario_file")
            fi
        done

        failed_list=("${still_failing[@]}")
        ((attempt++))
        sleep 5  # Brief pause between retries
    done

    if [[ ${#failed_list[@]} -gt 0 ]]; then
        log_error "Failed after $max_attempts retries: ${#failed_list[@]} scenarios"
        return 1
    fi

    log_success "All scenarios passed after retry"
    return 0
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Set up error handling
    setup_error_trap

    # Run main
    main "$@"
fi
