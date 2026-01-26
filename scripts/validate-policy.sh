#!/usr/bin/env bash
# Validate Helm charts against OPA policies
# Usage: scripts/validate-policy.sh [chart-path]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
POLICIES_DIR="${REPO_ROOT}/policies"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Policy Validation with Conftest ==="
echo ""

# Check if conftest is installed
if ! command -v conftest &> /dev/null; then
  echo -e "${YELLOW}⚠️  conftest not found${NC}"
  echo "Installing conftest..."
  curl -sL https://raw.githubusercontent.com/open-policy-agent/conftest/master/install.sh | bash -s
  export PATH="${PATH}:${HOME}/.local/bin"
fi

# Charts to validate
CHARTS=(
  "charts/spark-4.1"
  "charts/spark-3.5/charts/spark-connect"
  "charts/spark-3.5/charts/spark-standalone"
)

FAILED=0
PASSED=0

for chart in "${CHARTS[@]}"; do
  if [[ ! -d "${REPO_ROOT}/${chart}" ]]; then
    echo -e "${YELLOW}⊘ ${chart} - not found, skipping${NC}"
    continue
  fi

  echo -e "\n${YELLOW}Validating: ${chart}${NC}"

  # Check if chart has scenario presets
  if ls "${REPO_ROOT}/${chart}"/values-scenario-*.yaml &>/dev/null; then
    for preset in "${REPO_ROOT}/${chart}"/values-scenario-*.yaml; do
      preset_name=$(basename "${preset}")
      echo -n "  ${preset_name} ... "

      # Render Helm template and validate
      if OUTPUT=$(helm template test "${REPO_ROOT}/${chart}" -f "${preset}" 2>&1); then
        if echo "${OUTPUT}" | conftest validate -p "${POLICIES_DIR}" - 2>/dev/null; then
          echo -e "${GREEN}✓ PASS${NC}"
          ((PASSED++))
        else
          echo -e "${RED}✗ FAIL${NC}"
          ((FAILED++))
        fi
      else
        echo -e "${RED}✗ RENDER FAIL${NC}"
        ((FAILED++))
      fi
    done
  else
    echo -n "  default values ... "
    if OUTPUT=$(helm template test "${REPO_ROOT}/${chart}" 2>&1); then
      if echo "${OUTPUT}" | conftest validate -p "${POLICIES_DIR}" - 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
      else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
      fi
    else
      echo -e "${RED}✗ RENDER FAIL${NC}"
      ((FAILED++))
    fi
  fi
done

echo ""
echo "=== Summary ==="
echo -e "${GREEN}Passed: ${PASSED}${NC}"
echo -e "${RED}Failed: ${FAILED}${NC}"

if [[ ${FAILED} -gt 0 ]]; then
  exit 1
fi

exit 0
