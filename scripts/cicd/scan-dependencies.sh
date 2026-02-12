#!/bin/bash
# Scan dependencies for security vulnerabilities and outdated packages
#
# Usage:
#   ./scan-dependencies.sh --project-dir <path> [--language scala|python|all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../operations/common.sh"

# Configuration
PROJECT_DIR=""
LANGUAGE="all"
REPORT_DIR="/tmp/dependency-scan-reports"
SEVERITY_THRESHOLD="HIGH"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --severity)
            SEVERITY_THRESHOLD="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$PROJECT_DIR" ]]; then
    log_error "Usage: $0 --project-dir <path> [--language scala|python|all]"
    exit 1
fi

log_info "=== Dependency Scanning ==="
log_info "Project: ${PROJECT_DIR}"
log_info "Language: ${LANGUAGE}"
log_info "Severity threshold: ${SEVERITY_THRESHOLD}"

mkdir -p "$REPORT_DIR"
declare -i CRITICAL_COUNT=0
declare -i HIGH_COUNT=0
declare -i MEDIUM_COUNT=0

# Python dependency scanning
if [[ "$LANGUAGE" == "python" || "$LANGUAGE" == "all" ]]; then
    log_info "=== Scanning Python Dependencies ==="

    # Check for requirements.txt or pyproject.toml
    if [[ -f "$PROJECT_DIR/requirements.txt" || -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/setup.py" ]]; then
        # Use pip-audit if available
        if command -v pip-audit &> /dev/null; then
            log_info "Running pip-audit..."
            pip-audit --desc --format json --output "$REPORT_DIR/pip-audit.json" "$PROJECT_DIR" 2>/dev/null || true

            if [[ -f "$REPORT_DIR/pip-audit.json" ]]; then
                # Count vulnerabilities by severity
                CRITICAL=$(grep -o '"severity":"CRITICAL"' "$REPORT_DIR/pip-audit.json" 2>/dev/null | wc -l || echo "0")
                HIGH=$(grep -o '"severity":"HIGH"' "$REPORT_DIR/pip-audit.json" 2>/dev/null | wc -l || echo "0")
                MEDIUM=$(grep -o '"severity":"MEDIUM"' "$REPORT_DIR/pip-audit.json" 2>/dev/null | wc -l || echo "0")

                CRITICAL_COUNT=$((CRITICAL_COUNT + CRITICAL))
                HIGH_COUNT=$((HIGH_COUNT + HIGH))
                MEDIUM_COUNT=$((MEDIUM_COUNT + MEDIUM))

                log_info "Python vulnerabilities: ${CRITICAL} critical, ${HIGH} high, ${MEDIUM} medium"
            fi
        else
            log_warn "pip-audit not found, skipping Python vulnerability scan"
        fi

        # Check for outdated packages
        if command -v pip-outdated &> /dev/null; then
            log_info "Checking for outdated packages..."
            pip-outdated "$PROJECT_DIR" > "$REPORT_DIR/outdated.txt" 2>/dev/null || true
        fi
    else
        log_info "No Python dependency files found"
    fi
fi

# Scala/Java dependency scanning
if [[ "$LANGUAGE" == "scala" || "$LANGUAGE" == "all" ]]; then
    log_info "=== Scanning Scala/Java Dependencies ==="

    # Check for build.sbt or pom.xml
    if [[ -f "$PROJECT_DIR/build.sbt" || -f "$PROJECT_DIR/pom.xml" ]]; then
        # Use OWASP Dependency-Check if available
        if command -v dependency-check &> /dev/null; then
            log_info "Running OWASP Dependency-Check..."
            dependency-check --scan "$PROJECT_DIR" --out "$REPORT_DIR" --format JSON 2>/dev/null || true

            # Parse results
            if [[ -f "$REPORT_DIR/dependency-check-report.json" ]]; then
                CRITICAL=$(grep -o '"severity":"CRITICAL"' "$REPORT_DIR/dependency-check-report.json" 2>/dev/null | wc -l || echo "0")
                HIGH=$(grep -o '"severity":"HIGH"' "$REPORT_DIR/dependency-check-report.json" 2>/dev/null | wc -l || echo "0")
                MEDIUM=$(grep -o '"severity":"MEDIUM"' "$REPORT_DIR/dependency-check-report.json" 2>/dev/null | wc -l || echo "0")

                CRITICAL_COUNT=$((CRITICAL_COUNT + CRITICAL))
                HIGH_COUNT=$((HIGH_COUNT + HIGH))
                MEDIUM_COUNT=$((MEDIUM_COUNT + MEDIUM))

                log_info "Scala vulnerabilities: ${CRITICAL} critical, ${HIGH} high, ${MEDIUM} medium"
            fi
        else
            log_warn "OWASP Dependency-Check not found, skipping Scala vulnerability scan"
        fi

        # Use SBT plugin if available
        if [[ -f "$PROJECT_DIR/build.sbt" ]] && command -v sbt &> /dev/null; then
            log_info "Running SBT dependency updates check..."
            cd "$PROJECT_DIR"
            sbt dependencyUpdates 2>/dev/null > "$REPORT_DIR/sbt-updates.txt" || true
        fi
    else
        log_info "No Scala/Java dependency files found"
    fi
fi

# Check for common vulnerable dependencies
log_info "=== Checking for Known Vulnerable Dependencies ==="

# Log4j vulnerability (CVE-2021-44228)
if find "$PROJECT_DIR" -name "*.jar" -o -name "pom.xml" -o -name "build.sbt" 2>/dev/null | xargs grep -l "log4j.*2\.[0-9]\.[0-9]" 2>/dev/null; then
    log_error "Potential Log4Shell vulnerability (CVE-2021-44228) detected!"
    ((HIGH_COUNT++))
fi

# Generate summary
log_info "=== Scan Summary ==="
log_info "Critical vulnerabilities: $CRITICAL_COUNT"
log_info "High vulnerabilities: $HIGH_COUNT"
log_info "Medium vulnerabilities: $MEDIUM_COUNT"

# Exit with error if threshold exceeded
if [[ $CRITICAL_COUNT -gt 0 ]]; then
    log_error "Critical vulnerabilities found!"
    exit 1
elif [[ $SEVERITY_THRESHOLD == "HIGH" && $HIGH_COUNT -gt 0 ]]; then
    log_error "High vulnerabilities found!"
    exit 1
elif [[ $SEVERITY_THRESHOLD == "MEDIUM" && $MEDIUM_COUNT -gt 0 ]]; then
    log_error "Medium vulnerabilities found!"
    exit 1
else
    log_info "✓ No vulnerabilities above threshold"
    exit 0
fi
