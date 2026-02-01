#!/bin/bash
# Generate Markdown documentation from YAML frontmatter in test scripts
# Parses @meta/@endmeta blocks and creates formatted documentation

# Source common library first
# shellcheck source=scripts/tests/lib/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Disable exit on error for this script (common.sh sets set -e)
set +e

# ============================================================================
# Configuration
# ============================================================================

TESTS_DIR="${SCRIPT_DIR}"
DOCS_DIR="${TESTS_DIR}/docs"
PROJECT_ROOT="$(get_project_root)"

# Create docs directory if it doesn't exist
mkdir -p "$DOCS_DIR"

# ============================================================================
# YAML parsing functions
# ============================================================================

# Extract YAML frontmatter from script
extract_yaml_frontmatter() {
    local script_file="${1}"

    if [[ ! -f "$script_file" ]]; then
        log_error "Script file not found: $script_file"
        return 1
    fi

    # Extract content between @meta and @endmeta
    sed -n '/^# @meta/,/^# @endmeta/p' "$script_file"
}

# Parse specific key from YAML frontmatter
parse_yaml_key() {
    local yaml_content="${1}"
    local key="${2}"

    # Match both "# key: value" and "key: value" formats
    echo "$yaml_content" | grep -E "(^# )?${key}:" | sed -E "s/(^# )?${key}: //" | tr -d '"'
}

# Parse array key from YAML frontmatter (e.g., tags, depends_on)
parse_yaml_array() {
    local yaml_content="${1}"
    local key="${2}"

    local value
    value=$(echo "$yaml_content" | grep -E "(^# )?${key}:" | sed -E "s/(^# )?${key}: //" | tr -d '"')

    # Handle array format: [item1, item2]
    if [[ "$value" =~ \[(.*)\] ]]; then
        echo "${BASH_REMATCH[1]}" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
    else
        echo "$value"
    fi
}

# ============================================================================
# Documentation generation
# ============================================================================

# Generate documentation for a single test script
generate_test_doc() {
    local script_file="${1}"
    local doc_file="${2}"

    log_info "Generating documentation for: $(basename "$script_file")"

    # Extract YAML frontmatter
    local yaml
    yaml=$(extract_yaml_frontmatter "$script_file")

    if [[ -z "$yaml" ]]; then
        log_warning "No YAML frontmatter found in: $script_file"
        return 1
    fi

    # Parse YAML fields
    local name
    local type
    local description
    local version
    local component
    local mode
    local features
    local chart
    local preset
    local estimated_time
    local depends_on
    local tags

    name=$(parse_yaml_key "$yaml" "name")
    type=$(parse_yaml_key "$yaml" "type")
    description=$(parse_yaml_key "$yaml" "description")
    version=$(parse_yaml_key "$yaml" "version")
    component=$(parse_yaml_key "$yaml" "component")
    mode=$(parse_yaml_key "$yaml" "mode")
    features=$(parse_yaml_key "$yaml" "features")
    chart=$(parse_yaml_key "$yaml" "chart")
    preset=$(parse_yaml_key "$yaml" "preset")
    estimated_time=$(parse_yaml_key "$yaml" "estimated_time")
    depends_on=$(parse_yaml_array "$yaml" "depends_on")
    tags=$(parse_yaml_array "$yaml" "tags")

    # Generate Markdown
    cat > "$doc_file" << EOF
# $name

> **Type:** \`$type\` | **Estimated Time:** \`$estimated_time\`

## Description

$description

## Configuration

| Parameter | Value |
|-----------|-------|
| **Spark Version** | \`$version\` |
| **Component** | \`$component\` |
| **Mode** | \`$mode\` |
| **Features** | \`$features\` |
| **Chart** | \`$chart\` |
| **Preset** | \`$preset\` |

## Tags

EOF

    # Add tags
    echo "$tags" | while read -r tag; do
        if [[ -n "$tag" ]]; then
            echo "- \`${tag}\`" >> "$doc_file"
        fi
    done

    # Add dependencies if present
    if [[ -n "$depends_on" ]] && [[ "$depends_on" != "[]" ]]; then
        cat >> "$doc_file" << EOF

## Dependencies

EOF
        echo "$depends_on" | while read -r dep; do
            if [[ -n "$dep" ]] && [[ "$dep" != "[]" ]]; then
                echo "- $dep" >> "$doc_file"
            fi
        done
    fi

    # Add usage section
    cat >> "$doc_file" << EOF

## Usage

\`\`\`bash
# Run the test
$script_file

# Or with parameters
$script_file --version=$version --component=$component
\`\`\`

## Prerequisites

- Kubernetes cluster with \`kubectl\` configured
- Helm 3.x installed
- Sufficient cluster resources (CPU, memory)
EOF

    # Add GPU prerequisite if applicable
    if [[ "$features" == *"gpu"* ]] || [[ "$features" == *"gpu-iceberg"* ]]; then
        cat >> "$doc_file" << EOF
- GPU nodes available in cluster (for GPU tests)
EOF
    fi

    # Add storage prerequisite if applicable
    if [[ "$features" == *"iceberg"* ]] || [[ "$features" == *"gpu-iceberg"* ]]; then
        cat >> "$doc_file" << EOF
- S3-compatible storage (MinIO, AWS S3, etc.) for Iceberg
EOF
    fi

    # Add what is tested section
    cat >> "$doc_file" << EOF

## What Is Tested

EOF

    case "$type" in
        smoke)
            cat >> "$doc_file" << EOF
- ✅ Basic deployment of Spark components
- ✅ Pods reach Ready state
- ✅ Services are accessible
- ✅ Simple Spark job execution
EOF
            ;;
        e2e)
            cat >> "$doc_file" << EOF
- ✅ Full deployment with all configured components
- ✅ Integration between components
- ✅ Real-world workload execution
- ✅ Resource allocation and limits
EOF
            ;;
        load)
            cat >> "$doc_file" << EOF
- ✅ Performance under sustained load
- ✅ Resource utilization patterns
- ✅ Autoscaling behavior (if configured)
- ✅ Stability over extended periods
EOF
            ;;
        *)
            cat >> "$doc_file" << EOF
- Test-specific validation criteria
EOF
            ;;
    esac

    # Add success criteria section
    cat >> "$doc_file" << EOF

## Success Criteria

1. All pods reach Ready state
2. All services respond to requests
3. Test jobs complete without errors
4. Resource limits respected
5. No unexpected pod restarts

## Cleanup

The test automatically cleans up resources on failure. On success, resources are preserved for inspection.

To manually clean up:

\`\`\`bash
# List test namespaces
kubectl get namespaces | grep spark-test

# Delete specific namespace
kubectl delete namespace <namespace-name>
\`\`\`

## Troubleshooting

### Check pod status
\`\`\`bash
kubectl get pods -n <namespace>
\`\`\`

### View pod logs
\`\`\`bash
kubectl logs -n <namespace> <pod-name>
\`\`\`

### Describe pod for events
\`\`\`bash
kubectl describe pod -n <namespace> <pod-name>
\`\`\`

---

*Generated: $(date +%Y-%m-%d\ %H:%M:%S)*
EOF

    log_success "Documentation generated: $doc_file"
}

# Generate index file for all tests
generate_test_index() {
    local index_file="${DOCS_DIR}/INDEX.md"

    log_info "Generating test documentation index: $index_file"

    cat > "$index_file" << EOF
# Test Documentation Index

This directory contains auto-generated documentation for all test scripts.

## Test Categories

EOF

    # Group by type
    for type in smoke e2e load unit integration; do
        echo "### $type Tests" >> "$index_file"
        echo "" >> "$index_file"

        # Find all markdown files for this type
        find "$DOCS_DIR" -name "*${type}*.md" -o -name "test-${type}*.md" | while read -r doc_file; do
            local test_name
            test_name=$(basename "$doc_file" .md)
            echo "- [$test_name]($test_name.md)" >> "$index_file"
        done

        echo "" >> "$index_file"
    done

    cat >> "$index_file" << EOF
---

## Legend

- **smoke**: Quick validation tests (5-10 min)
- **e2e**: Full end-to-end tests (15-30 min)
- **load**: Performance and load tests (30+ min)
- **unit**: Unit tests for specific components
- **integration**: Integration tests for multiple components

---

*Last updated: $(date +%Y-%m-%d\ %H:%M:%S)*
EOF

    log_success "Index generated: $index_file"
}

# ============================================================================
# Main execution
# ============================================================================

# Generate docs for all test scripts
generate_all_docs() {
    local category="${1:-all}"

    log_section "Generating test documentation"

    local total=0
    local updated=0
    local skipped=0

    # Find all test scripts and process them
    local find_pattern
    local find_dir

    case "$category" in
        smoke|e2e|load)
            find_dir="${TESTS_DIR}/${category}"
            find_pattern="*.sh"
            ;;
        all)
            find_dir="${TESTS_DIR}"
            find_pattern="*.sh"
            ;;
        *)
            find_dir="${TESTS_DIR}"
            find_pattern="*${category}*.sh"
            ;;
    esac

    local find_cmd="find \"$find_dir\" -name \"$find_pattern\" -not -name \"run-*.sh\""

    if [[ "$category" == "all" ]]; then
        find_cmd="$find_cmd -not -name \"generate-docs.sh\""
    fi

    while IFS= read -r script_file; do
        if [[ ! -f "$script_file" ]]; then
            continue
        fi

        ((total++))

        # Determine output file name
        local script_name
        script_name=$(basename "$script_file" .sh)
        local doc_file="${DOCS_DIR}/${script_name}.md"

        # Check if documentation needs updating
        if [[ -f "$doc_file" ]]; then
            local script_mtime
            local doc_mtime
            script_mtime=$(stat -c %Y "$script_file" 2>/dev/null || stat -f %m "$script_file")
            doc_mtime=$(stat -c %Y "$doc_file" 2>/dev/null || stat -f %m "$doc_file")

            if [[ $script_mtime -le $doc_mtime ]]; then
                log_debug "Skipping (up to date): $script_name"
                ((skipped++))
                continue
            fi
        fi

        # Generate documentation
        if generate_test_doc "$script_file" "$doc_file"; then
            ((updated++))
        fi
    done < <(eval "$find_cmd" 2>/dev/null)

    # Generate index
    generate_test_index

    log_section "Documentation generation complete"
    log_info "Total scripts: $total"
    log_info "Updated: $updated"
    log_info "Skipped: $skipped"
}

# ============================================================================
# Script entry point
# ============================================================================

main() {
    local category="${1:-all}"

    # Check if yq is available for better YAML parsing
    if command -v yq &>/dev/null; then
        log_debug "yq found, using for YAML parsing"
    else
        log_debug "yq not found, using basic parsing"
    fi

    generate_all_docs "$category"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
