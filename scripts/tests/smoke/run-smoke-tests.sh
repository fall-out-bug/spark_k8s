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

# Default configuration
SCENARIOS_DIR="${SCRIPT_DIR}/scenarios"
PARALLEL="${PARALLEL:-false}"
CLEANUP_ON_SUCCESS="${CLEANUP_ON_SUCCESS:-false}"
DATASET_SIZE="${DATASET_SIZE:-small}"  # small, medium, large

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
    --parallel               Run tests in parallel (experimental)
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

    log_section "Running scenarios in parallel (${#scenario_files[@]} scenarios)"

    for scenario_file in "${scenario_files[@]}"; do
        # Run in background
        (
            local scenario_name
            scenario_name=$(parse_yaml_frontmatter "$scenario_file" "name")

            # Create unique log file
            local log_file="/tmp/smoke-test-${scenario_name}.log"

            if run_scenario "$scenario_file" 2>&1 | tee "$log_file"; then
                echo "0" > "/tmp/smoke-test-${scenario_name}.result"
            else
                echo "$?" > "/tmp/smoke-test-${scenario_name}.result"
            fi
        ) &

        pids+=($!)
    done

    # Wait for all background processes
    local failed=0
    for i in "${!pids[@]}"; do
        wait "${pids[$i]}" || ((failed++))
    done

    # Check results
    for scenario_file in "${scenario_files[@]}"; do
        local scenario_name
        scenario_name=$(parse_yaml_frontmatter "$scenario_file" "name")
        local result_file="/tmp/smoke-test-${scenario_name}.result"

        if [[ -f "$result_file" ]]; then
            local result
            result=$(cat "$result_file")

            if [[ "$result" != "0" ]]; then
                log_error "Scenario failed: $scenario_name"
                ((failed++))
            fi

            # Cleanup result files
            rm -f "$result_file"
            rm -f "/tmp/smoke-test-${scenario_name}.log"
        fi
    done

    return $failed
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

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Set up error handling
    setup_error_trap

    # Run main
    main "$@"
fi
