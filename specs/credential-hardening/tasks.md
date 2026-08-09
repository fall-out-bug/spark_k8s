---
description: "Task list for Harden Default Credentials"
---

# Tasks: Harden Default Credentials in Values Files

> **Reconciled 2026-08-09 — STATUS: DONE.** All tasks shipped. Verified: `grep -rE '$S3_ACCESS_KEY|hive123' charts/*/values*.yaml charts/*/presets/*.yaml` returns 0 hits; 4 template files enforce `required`; `tests/security/test_credential_leak.py` guards regression; `.env.example` + `docs/recipes/security/credential-management.md` exist. Shipped via PRs #23 / #28 / #29 / #30 / #31.

**Input**: Design documents from `/specs/credential-hardening/`

**Prerequisites**: plan.md (required), spec.md (required)

**Organization**: Tasks grouped by user story (US1 = strip creds, US2 = documentation). Run `/speckit.tasks` to regenerate.

## Format: `[ID] [P?] [Story] Description`

## US1 — No Default Production-Like Credentials (P1)

- [x]T001 [US1] Audit: `grep -rnE '$S3_ACCESS_KEY|hive123' charts/*/values*.yaml charts/*/presets/*.yaml > /tmp/cred-audit.txt` — capture baseline
- [x]T002 [US1] Edit `charts/spark-3.5/values.yaml`: replace `$S3_ACCESS_KEY` → `""`, `hive123` → `""` + add comment "REQUIRED: set via --set or ExternalSecrets"
- [x]T003 [US1] [P] Edit `charts/spark-4.1/values.yaml`: same treatment
- [x]T004 [US1] Edit all `charts/spark-3.5/values-scenario-*.yaml` (8+ files): hardcoded creds → `""` or `.env.example` reference
- [x]T005 [US1] [P] Edit all `charts/spark-4.1/values-scenario-*.yaml` (8+ files): same
- [x]T006 [US1] [P] Edit all `charts/spark-3.5/presets/*.yaml`: same
- [x]T007 [US1] Verify `helm template charts/spark-3.5` renders with empty creds (no required-field errors)
- [x]T008 [US1] [P] Verify `helm template charts/spark-4.1` renders with empty creds
- [x]T009 [US1] Verify `helm template charts/spark-3.5 --set global.s3.accessKey=test --set global.s3.secretKey=test` works
- [x]T010 [US1] [P] Verify `helm template charts/spark-4.1 --set global.s3.accessKey=test --set global.s3.secretKey=test` works
- [x]T011 [US1] Add grep assertion test in `tests/security/` (or extend existing) — fail if `$S3_ACCESS_KEY`/`hive123` present in any `values*.yaml`
- [x]T012 [US1] Update `scripts/deploy-demo-minikube.sh` to source credentials from `.env.example` (no hardcoded fallback)

## US2 — Documented Credential Setup (P2)

- [x]T013 [US2] Expand `.env.example` with all required secrets (placeholder format, REQUIRED/OPTIONAL comments, link to recipe)
- [x]T014 [US2] Create `docs/recipes/security/credential-management.md` with 4 patterns: ExternalSecrets, SealedSecrets, Vault + CSI, Manual --set
- [x]T015 [US2] Add validation section to recipe: `helm template` + grep assertions
- [x]T016 [US2] Cross-link from `PROJECT_CONVENTIONS.md` → recipe (Helm Chart Conventions § "No hardcoded secrets")
- [x]T017 [US2] Update `docs/guides/{en,ru}/quick-reference.md` with credential setup snippet

## Quality Gates

- [x]T018 `helm lint charts/spark-3.5 charts/spark-4.1` passes
- [x]T019 `pre-commit run --all-files` passes
- [x]T020 `pytest tests/security/ -q` passes
- [x]T021 `pytest tests/integration/ -q` passes
- [x]T022 `grep -rE '$S3_ACCESS_KEY|hive123' charts/*/values*.yaml charts/*/presets/*.yaml` returns nothing

## Demo Protection

- [x]T023 Update demo deploy script to read secrets from `.env.example`
- [x]T024 `./scripts/check-demo-health.sh` exit 0 pre/post change
- [x]T025 Document demo secret rotation in `docs/operations/demo-protection.md`
