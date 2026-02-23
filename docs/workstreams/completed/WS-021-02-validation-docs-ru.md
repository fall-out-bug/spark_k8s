---
ws_id: 021-02
feature: F05
status: completed
size: SMALL
project_id: 00
github_issue: null
assignee: null
depends_on: ["021-01"]
---

## WS-021-02: Update Validation Docs RU (Airflow vars)

### 🎯 Goal

**What must WORK after completing this WS:**
- docs/guides/ru/validation.md documents Airflow Variables for prod-like validation (Russian)
- Parity with EN version; same structure and content
- Bilingual validation runbook complete

**Acceptance Criteria:**
- [x] AC1: validation.md (RU) includes section on Airflow Variables
- [x] AC2: SET_AIRFLOW_VARIABLES, FORCE_SET_VARIABLES env vars documented (RU)
- [x] AC3: Manual variable setup instructions (RU)
- [x] AC4: Link to test-prodlike-airflow.sh and test-sa-prodlike-all.sh
- [x] AC5: Prod-like values overlay reference (RU)
- [x] AC6: Content matches EN version structurally

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-021-01 (Update validation docs EN).

### Input

- docs/guides/ru/validation.md
- docs/guides/en/validation.md (source for translation)
- scripts/test-prodlike-airflow.sh

### Scope

~120 LOC. See docs/workstreams/INDEX.md Feature F05.
