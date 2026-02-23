# Security Migration Guide

Migration from `podSecurityStandards: false` to `podSecurityStandards: true` (default).

---

## Overview

As of F07 (Phase 01 Security), Helm charts default to `security.podSecurityStandards: true`. This enables Pod Security Standards (PSS) labels on namespaces and PSS-compliant pod specs.

---

## Behavior Change

| Setting | Before | After (default) |
|---------|--------|-----------------|
| `podSecurityStandards` | false | true |
| Namespace PSS labels | none | enforce/audit/warn |
| Pod securityContext | optional | runAsNonRoot, readOnlyRootFilesystem, etc. |

---

## Migration Steps

### 1. Existing Deployments (Prod)

If your deployment already uses secure defaults:

- No change required. `podSecurityStandards: true` is the new default.
- Verify namespace labels: `kubectl get ns <ns> -o yaml | grep pod-security`

### 2. Dev / Scenario Presets

Scenario presets (e.g. `jupyter-connect-standalone-4.1.1.yaml`) explicitly set `podSecurityStandards: false` for dev environments. No migration needed.

### 3. Custom Values Override

If you previously set `podSecurityStandards: false` in your values:

- **Option A:** Remove override — use new default (true).
- **Option B:** Keep `podSecurityStandards: false` — dev/test only. Prod should use true.

### 4. OpenShift

Use presets:

- `charts/spark-3.5/presets/openshift/restricted.yaml` — PSS restricted
- `charts/spark-3.5/presets/openshift/anyuid.yaml` — anyuid SCC (PSS false)

---

## Rollback

To revert to previous behavior:

```yaml
security:
  podSecurityStandards: false
```

---

## References

- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- Feature F07: Phase 01 Security (PSS/SCC)
