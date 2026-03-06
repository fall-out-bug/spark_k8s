# ADR-0008: Pod Security Standards (PSS) as Default

## Status

Accepted (F07)

## Context

Helm charts initially used `security.podSecurityStandards: false` for compatibility with older clusters and dev workflows. As security posture improved (F07 Phase 01), we needed to enforce PSS by default while allowing opt-out for dev.

## Decision

- **Default:** `security.podSecurityStandards: true`
- **Namespace labels:** enforce/audit/warn applied when PSS enabled
- **Pod securityContext:** runAsNonRoot, readOnlyRootFilesystem, etc. when PSS enabled
- **Dev override:** Scenario presets (e.g. `jupyter-connect-standalone-4.1.1.yaml`) may set `podSecurityStandards: false` for dev
- **OpenShift:** Use `presets/openshift/restricted.yaml` (PSS) or `anyuid.yaml` (PSS false)

## Migration

If previously using `podSecurityStandards: false`:
- **Prod:** Remove override → use default (true)
- **Dev:** Keep false in scenario presets if needed
- **Rollback:** `security.podSecurityStandards: false` in values

## Consequences

- **Pros:** PSS compliance by default, better security posture
- **Cons:** Existing deployments with custom securityContext may need adjustment

## References

- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- F07: Phase 01 Security (PSS/SCC)
