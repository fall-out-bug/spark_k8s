#!/bin/bash
# Common library for test scripts
# Provides logging, colors, error handling, and utility functions

# Mark as loaded (idempotent)
export _TEST_LIB_COMMON_LOADED=yes

# Exit on error by default (can be disabled in specific scripts)
set -e

# ============================================================================
# Colors and formatting
# ============================================================================

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    # Terminal supports colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'  # No Color
else
    # No colors (redirects, CI, etc.)
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    BOLD=''
    NC=''
fi

# ============================================================================
# Logging functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $*" >&2
    fi
}

log_section() {
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}$*${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""
}

log_step() {
    echo -e "${YELLOW}→${NC} $*"
}

# ============================================================================
# Error handling
# ============================================================================

# Enable/disable strict error handling
set_strict_mode() {
    local enabled="${1:-true}"

    if [[ "$enabled" == "true" ]]; then
        set -eEuo pipefail
        log_debug "Strict mode enabled"
    else
        set +eEuo pipefail
        log_debug "Strict mode disabled"
    fi
}

# Error handler
error_handler() {
    local line_no="${1}"
    local bash_lineno="${2}"
    local exit_code="${3}"

    log_error "Script failed at line ${line_no} (exit code: ${exit_code})"

    # Call cleanup if defined
    if declare -f on_error_cleanup &>/dev/null; then
        log_debug "Running on_error_cleanup..."
        on_error_cleanup
    fi

    exit "${exit_code}"
}

# Set up error trap
setup_error_trap() {
    trap 'error_handler ${LINENO} ${BASH_LINENO} $?' ERR
}

# ============================================================================
# Utility functions
# ============================================================================

# Retry command with exponential backoff
retry() {
    local max_attempts="${1}"
    local delay="${2}"
    shift 2
    local command=("$@")

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt/$max_attempts: ${command[*]}"

        if "${command[@]}"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            local wait_time=$((delay * 2 ** (attempt - 1)))
            log_warning "Command failed, retrying in ${wait_time}s..."
            sleep "$wait_time"
        fi

        ((attempt++))
    done

    log_error "Command failed after $max_attempts attempts: ${command[*]}"
    return 1
}

# Wait for condition with timeout
wait_for() {
    local condition="${1}"
    local timeout="${2:-300}"
    local interval="${3:-5}"

    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if eval "$condition"; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    log_error "Timeout waiting for condition: $condition"
    return 1
}

# Check required commands
check_required_commands() {
    local missing=()

    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Required commands not found: ${missing[*]}"
        return 1
    fi

    log_debug "All required commands available: $*"
    return 0
}

# Parse YAML frontmatter from script
parse_yaml_frontmatter() {
    local script_file="${1}"
    local key="${2}"

    # Extract value between @meta and @endmeta
    sed -n '/^# @meta/,/^# @endmeta/p' "$script_file" | \
        grep "^# ${key}:" | \
        sed "s/^# ${key}: //" | \
        tr -d '"'
}

# Get script directory
get_script_dir() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    echo "$script_dir"
}

# Get project root directory
get_project_root() {
    local script_dir
    script_dir="$(get_script_dir)"

    # Navigate up until we find .git or marker file
    while [[ "$script_dir" != "/" ]]; do
        if [[ -d "${script_dir}/.git" ]] || [[ -f "${script_dir}/CLAUDE.md" ]]; then
            echo "$script_dir"
            return 0
        fi
        script_dir="$(dirname "$script_dir")"
    done

    log_error "Could not find project root"
    return 1
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error log_debug log_section log_step
export -f set_strict_mode error_handler setup_error_trap
export -f retry wait_for check_required_commands
export -f parse_yaml_frontmatter get_script_dir get_project_root
