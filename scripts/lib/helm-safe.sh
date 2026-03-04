#!/usr/bin/env bash
# Safe helm wrapper. Source this in scripts that deploy to protected namespaces.
# Usage:
#   source scripts/lib/helm-safe.sh
#   helm_safe_install spark-infra charts/spark-3.5 spark-infra -f values.yaml
#   helm_safe_uninstall spark-infra spark-infra   # blocked for protected NS

PROTECTED_NAMESPACES=("spark-infra" "observability")
PROTECTED_RELEASES=("spark-infra")

_is_protected_ns() {
  local ns="$1"
  for protected in "${PROTECTED_NAMESPACES[@]}"; do
    [[ "$ns" == "$protected" ]] && return 0
  done
  return 1
}

_get_release_chart() {
  local release="$1" namespace="$2"
  helm list -n "$namespace" -f "^${release}$" -o json 2>/dev/null \
    | python3 -c "import json,sys; r=json.load(sys.stdin); print(r[0]['chart'] if r else '')" 2>/dev/null || echo ""
}

_get_chart_name() {
  local chart_path="$1"
  if [[ -f "$chart_path/Chart.yaml" ]]; then
    grep '^name:' "$chart_path/Chart.yaml" | awk '{print $2}'
  else
    basename "$chart_path"
  fi
}

helm_safe_install() {
  local release="$1" chart_path="$2" namespace="$3"
  shift 3

  # Guard 1: In protected NS, only the canonical release is allowed
  if _is_protected_ns "$namespace"; then
    local allowed=false
    for pr in "${PROTECTED_RELEASES[@]}"; do
      [[ "$release" == "$pr" ]] && allowed=true
    done
    if [[ "$allowed" == "false" ]]; then
      echo "BLOCKED: Cannot create release '$release' in protected namespace '$namespace'."
      echo "Only these releases are allowed: ${PROTECTED_RELEASES[*]}"
      return 1
    fi
  fi

  # Guard 2: No chart swap on existing release
  local existing_chart
  existing_chart=$(_get_release_chart "$release" "$namespace")
  if [[ -n "$existing_chart" ]]; then
    local new_chart_name
    new_chart_name=$(_get_chart_name "$chart_path")
    if [[ -n "$new_chart_name" && "$existing_chart" != "${new_chart_name}-"* ]]; then
      echo "BLOCKED: Release '$release' uses chart '$existing_chart'."
      echo "You are trying to install chart '$new_chart_name'."
      echo "This would destroy existing resources. Aborting."
      echo ""
      echo "If intentional, first run: helm uninstall $release -n $namespace"
      return 1
    fi
  fi

  # Guard 3: No second release in protected NS
  if _is_protected_ns "$namespace"; then
    local release_count
    release_count=$(helm list -n "$namespace" -o json 2>/dev/null \
      | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    if [[ "$release_count" -gt 0 ]]; then
      local existing_name
      existing_name=$(helm list -n "$namespace" -o json 2>/dev/null \
        | python3 -c "import json,sys; r=json.load(sys.stdin); print(r[0]['name'] if r else '')" 2>/dev/null || echo "")
      if [[ -n "$existing_name" && "$existing_name" != "$release" ]]; then
        echo "BLOCKED: Protected namespace '$namespace' already has release '$existing_name'."
        echo "Cannot create a second release '$release'."
        return 1
      fi
    fi
  fi

  helm upgrade --install "$release" "$chart_path" -n "$namespace" "$@"
}

helm_safe_uninstall() {
  local release="$1" namespace="$2"
  shift 2

  if _is_protected_ns "$namespace"; then
    echo "BLOCKED: Cannot uninstall release '$release' from protected namespace '$namespace'."
    echo "Use ./scripts/restore-demo.sh to fix issues instead."
    return 1
  fi

  helm uninstall "$release" -n "$namespace" "$@"
}
