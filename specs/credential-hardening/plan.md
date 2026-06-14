# Implementation Plan: Harden Default Credentials

**Branch**: `029-credential-hardening` | **Date**: 2026-06-14 | **Spec**: [spec.md](./spec.md)

**Note**: Initial plan migrated from `WS-029-04`. Run `/speckit.plan` to refine.

## Summary

Strip hardcoded credentials (`minioadmin`, `hive123`) from default `values.yaml` and preset values files across `charts/spark-3.5/` and `charts/spark-4.1/`. Replace with empty strings + comments pointing operators to ExternalSecrets / `--set`. Add credential-management recipe doc.

## Technical Context

### Files Touched

| Path | Change |
|------|--------|
| `charts/spark-4.1/values.yaml` | `minioadmin`/`minioadmin` → `""`, `hive123` → `""`, add comments |
| `charts/spark-3.5/values.yaml` | Same as spark-4.1 |
| `charts/spark-4.1/values-scenario-*.yaml` (8+ files) | Hardcoded creds → `""` or `.env.example` reference |
| `charts/spark-3.5/values-scenario-*.yaml` (8+ files) | Same |
| `charts/spark-3.5/presets/*.yaml` | Same |
| `.env.example` | Expand to list ALL required secrets with placeholder format |
| `docs/recipes/security/credential-management.md` (NEW) | ExternalSecrets, SealedSecrets, Vault examples |

### Secrets Inventory (from grep)

- `global.s3.accessKey` (default: `minioadmin`)
- `global.s3.secretKey` (default: `minioadmin`)
- `hive.metastore.password` (default: `hive123`)
- Any additional secrets found during execution

### Comment Format (consistent across charts)

```yaml
# REQUIRED: set via --set global.s3.accessKey=... or ExternalSecrets.
# Do NOT commit real credentials. See docs/recipes/security/credential-management.md
accessKey: ""
```

### Recipe Doc Structure

`docs/recipes/security/credential-management.md`:

1. **Why this matters** — link to incident or CVE
2. **Pattern A: ExternalSecrets** — full YAML example + Helm values snippet
3. **Pattern B: SealedSecrets** — example for GitOps workflows
4. **Pattern C: Vault + CSI Secret Store** — example for enterprise Vault
5. **Pattern D: Manual --set** — for dev/minikube
6. **Validation** — `helm template` + grep assertions

### Test Strategy

- **Static**: `helm lint charts/spark-3.5` + `helm lint charts/spark-4.1` with empty creds
- **Grep assertion**: `grep -rE 'minioadmin|hive123' charts/` returns only docs/guides (no values files)
- **Integration**: `pytest tests/security/` passes (existing security posture tests)
- **E2E**: `./scripts/deploy-demo-minikube.sh` with explicit `--set` secrets from `.env.example` deploys successfully

### Risks

| Risk | Mitigation |
|------|------------|
| Existing deployments break | Document override path in recipe; preserve `--set` compatibility |
| Demo script relies on hardcoded creds | Update `scripts/deploy-demo-minikube.sh` to source `.env.example` |
| Preset values files large (16+) | Batch sed replace, then manual review per file |
| CI runs `helm template` with empty creds | Confirm templates use `{{- if .Values.global.s3.accessKey }}` guards |

## Dependencies

- `charts/spark-3.5/` (F01, F06 — completed)
- `charts/spark-4.1/` (F04 — completed)
- Existing security tests in `tests/security/`
- `.env.example` (exists, to be expanded)

## Open Questions (resolve via `/speckit.clarify`)

1. Should empty creds render optional fields, or should we add a `credentials.required` gate that fails fast?
2. For preset files that target demos (`values-scenario-demo-full.yaml`), keep `minioadmin` as demo-mode exception with explicit warning, or enforce empty everywhere?
3. Should `.env.example` get a schema annotation (which fields are REQUIRED vs OPTIONAL)?
