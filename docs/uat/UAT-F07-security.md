# UAT: F07 Security (PSS/SCC)

**Feature:** F07 - Phase 01 Security (Pod Security Standards / OpenShift SCC)  
**Review Date:** 2026-02-10

---

## Overview

F07 adds Pod Security Standards (PSS) and OpenShift SCC support: namespace-level PSS labels, `podSecurityStandards` configuration, OpenShift presets (restricted, anyuid), and security validation scripts.

---

## Prerequisites

- `helm` 3.x
- `kubectl` (required for PSS/SCC scripts)
- Access to OpenShift cluster (for SCC scripts)

---

## Quick Verification (2 minutes)

### Smoke Test

```bash
# Validate namespace with PSS labels (default)
helm template test charts/spark-4.1 | grep -A2 "pod-security.kubernetes.io"
# Expected: enforce, audit, warn labels

# OpenShift preset (restricted)
helm template test charts/spark-4.1 -f charts/spark-4.1/presets/openshift/restricted.yaml | head -25
# Expected: Namespace with PSS labels
```

### Quick Check

```bash
# Verify podSecurityStandards default in base values
grep -A1 "podSecurityStandards:" charts/spark-4.1/values.yaml
# Expected: enabled: true
```

---

## Detailed Scenarios

### Scenario 1: PSS Labels (Namespace)

```bash
helm template test charts/spark-4.1 | grep -E "pod-security|createNamespace"
# Verify: pod-security.kubernetes.io/enforce, audit, warn
```

### Scenario 2: OpenShift Restricted Preset

```bash
helm template test charts/spark-4.1 -f charts/spark-4.1/presets/openshift/restricted.yaml
# Verify: Namespace with restricted PSS labels
```

### Scenario 3: PSS Security Scripts (dry-run)

```bash
# Syntax check
for f in scripts/tests/security/*.sh; do bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"; done
# Expected: all OK
```

---

## Acceptance Criteria Summary

| WS | Deliverable | Status |
|----|-------------|--------|
| WS-022-01 | namespace.yaml, PSS labels | ✅ |
| WS-022-02 | podSecurityStandards values | ✅ |
| WS-022-03 | OpenShift presets | ✅ |
| WS-022-04 | PSS/SCC scripts | ✅ |

---

## Notes

- PSS scripts require live cluster; UAT focuses on helm template and script syntax.
- SCC scripts require OpenShift cluster.
- See `docs/security-migration.md` for migration from previous values.
