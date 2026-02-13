---
ws_id: 021-01
feature: F05
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: []
---

## WS-021-01: Update Validation Docs EN (Airflow vars)

### 🎯 Goal

**What must WORK after completing this WS:**
- docs/guides/en/validation.md documents Airflow Variables for prod-like validation
- test-prodlike-airflow.sh usage and env vars clearly documented
- Operators can run prod-like validation without guessing variable names

**Acceptance Criteria:**
- [x] AC1: validation.md includes section on Airflow Variables (spark_image, spark_namespace, spark_standalone_master, s3_endpoint, s3_access_key, s3_secret_key)
- [x] AC2: SET_AIRFLOW_VARIABLES, FORCE_SET_VARIABLES env vars documented
- [x] AC3: Manual variable setup instructions (when script auto-set is disabled)
- [x] AC4: Link to test-prodlike-airflow.sh and test-sa-prodlike-all.sh
- [x] AC5: Prod-like values overlay reference (values-sa-prodlike.yaml or equivalent)

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- docs/guides/en/validation.md
- scripts/test-prodlike-airflow.sh
- docs/drafts/idea-repo-documentation.md

### Scope

~120 LOC. See docs/workstreams/INDEX.md Feature F05.
