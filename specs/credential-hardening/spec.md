# Feature Specification: Harden Default Credentials in Values Files

**Feature Branch**: `029-credential-hardening`

**Created**: 2026-06-14 (migrated from WS-029-04)

**Status**: Draft

**Source**: Migrated from legacy `WS-029-04` (archived at `docs/archive/sdp-workstreams/backlog/WS-029-04.md`)

## User Scenarios & Testing

### User Story 1 - No Default Production-Like Credentials (Priority: P1)

As a platform engineer deploying to production, I want the chart's `values.yaml` to ship with empty credentials rather than `minioadmin/minioadmin` or `hive123`, so that accidental production deploys don't expose weak defaults.

**Why this priority**: Security baseline. Without this US, the chart is unsafe for production.

**Test scenarios**:
- AC1: `charts/spark-4.1/values.yaml` has empty `minioadmin`/`minioadmin` replaced with `""` + comment "REQUIRED: set via --set or ExternalSecrets"
- AC2: `charts/spark-3.5/values.yaml` same treatment
- AC3: `charts/spark-4.1/values.yaml` has empty `hive123` replaced with `""` + comment
- AC4: All preset values files (8+ per chart) replace hardcoded creds with `""` or `.env.example` reference
- AC7: `helm template` with empty credentials still renders (optional cred fields)
- AC8: `helm template --set global.s3.accessKey=test --set global.s3.secretKey=test` works as before

### User Story 2 - Documented Credential Setup (Priority: P2)

As a new operator onboarding to spark_k8s, I want clear documentation on credential setup (ExternalSecrets, SealedSecrets, Vault patterns), so I can wire production secrets without guessing.

**Why this priority**: Removes guesswork, prevents P1 incidents.

**Test scenarios**:
- AC5: `.env.example` updated with all required secrets documented (placeholder format, comments per secret)
- AC6: `docs/recipes/security/credential-management.md` created with ExternalSecrets, SealedSecrets, Vault examples

## Requirements

### Functional

- **FR1**: All `values.yaml` (root + scenario presets) have empty defaults for credentials
- **FR2**: Comments next to each emptied field explain how to inject the secret (`--set`, ExternalSecrets, Vault)
- **FR3**: Helm template renders with empty credentials (no required-field errors)
- **FR4**: Helm template renders with explicit `--set` credentials (existing behavior preserved)

### Non-Functional

- **NFR1**: No breaking change for existing `helm install` invocations that pass `--set`
- **NFR2**: Backward compatibility: existing deployments with hardcoded values files still work after migration (override mechanism documented)

### Constraints

- Scope: `charts/spark-3.5/`, `charts/spark-4.1/` only (spark-base has no secrets)
- Secrets touched: `global.s3.accessKey`, `global.s3.secretKey`, `hive.metastore.password` (any others found via grep)
- Preset files: `values-scenario-*.yaml` (8+ per chart)

## E2E Test Plan (Acceptance)

### Acceptance Criteria

- [ ] AC1: `charts/spark-4.1/values.yaml`: `minioadmin` → `""` + comment "REQUIRED: set via --set or ExternalSecrets"
- [ ] AC2: `charts/spark-3.5/values.yaml`: same treatment
- [ ] AC3: `charts/spark-4.1/values.yaml`: `hive123` → `""` + comment
- [ ] AC4: All preset values files: hardcoded creds → `""` or `.env.example` reference
- [ ] AC5: `.env.example` updated with all required secrets documented
- [ ] AC6: `docs/recipes/security/credential-management.md` created
- [ ] AC7: `helm template` with empty credentials still renders
- [ ] AC8: `helm template --set global.s3.accessKey=test --set global.s3.secretKey=test` works as before

### Test Strategy

- Static: `helm lint` + `helm template` for each modified chart (empty creds and explicit creds)
- Grep assertion: no occurrence of `minioadmin`, `hive123`, or other default creds in `values*.yaml`
- Integration: existing security tests in `tests/security/` pass
- E2E: demo deploy works end-to-end (with explicit `--set` secrets from `.env.example`)

## Out of Scope

- Vault / ExternalSecrets Operator installation (documented in recipe only, not deployed)
- Spark 4.1.1-specific changes (this WS targets 3.5.x and 4.1.0)
- Refactoring chart structure (only credentials touched)
