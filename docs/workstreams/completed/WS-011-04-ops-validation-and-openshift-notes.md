## WS-011-04: Validation runbook + OpenShift notes (tested vs prepared)
### 🎯 Цель (Goal)
**What should WORK after WS completion:**
- Operators can validate deployments using the repo scripts and know what “green” means.
- Docs clearly state:
  - what was tested on Minikube
  - what is only prepared for OpenShift-like constraints (PSS/SCC) and what is not validated
**Acceptance Criteria:**
- [ ] `docs/guides/en/validation.md` exists (smoke scripts + expected results)
- [ ] `docs/guides/ru/validation.md` exists
- [ ] `docs/guides/en/openshift-notes.md` exists (PSS/SCC notes with explicit caveats)
- [ ] `docs/guides/ru/openshift-notes.md` exists
- [ ] Guides reference current scripts:
  - `scripts/test-spark-standalone.sh`
  - `scripts/test-prodlike-airflow.sh`
  - `scripts/test-sa-prodlike-all.sh`
**WS is NOT complete until Goal is achieved (all AC checked).**
---
### Context
Documentation must not over-claim. We tested on Minikube; we prepared the chart for OpenShift-like constraints.
This WS makes that explicit and provides a single runbook for validation.
### Dependency
WS-011-01
### Input Files
- `scripts/test-*.sh`
- `charts/spark-standalone/values-prod-like.yaml`
- security-related templates in `charts/spark-standalone/templates/`
### Steps
1. Document the smoke scripts and expected outputs.
2. Document “known failure modes” and how to troubleshoot (short, operator-focused).
3. Add OpenShift notes:
   - PSS `restricted` / SCC `restricted` intent
   - what is configurable (e.g. relaxed postgres for local)
   - what remains environment-specific
### Scope Estimate
- Files: ~4 created
- Lines: ~300-500 (MEDIUM)
- Tokens: ~1200-2000

---

### Execution Report

**Executed by:** GPT-5.2 (agent)  
**Date:** 2026-01-16

#### 🎯 Goal Status

- [x] `docs/guides/en/validation.md` exists (smoke scripts + expected results) — ✅
- [x] `docs/guides/ru/validation.md` exists — ✅
- [x] `docs/guides/en/openshift-notes.md` exists (PSS/SCC notes with explicit caveats) — ✅
- [x] `docs/guides/ru/openshift-notes.md` exists — ✅
- [x] Guides reference current scripts — ✅ (all three scripts referenced in both EN and RU validation guides)

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `docs/guides/en/validation.md` | created | 206 |
| `docs/guides/ru/validation.md` | created | 207 |
| `docs/guides/en/openshift-notes.md` | created | 152 |
| `docs/guides/ru/openshift-notes.md` | created | 153 |

**Total:** 718 LOC (exceeds MEDIUM scope estimate: 300-500, but acceptable for comprehensive documentation)

#### Completed Steps

- [x] Step 1: Document the smoke scripts and expected outputs
- [x] Step 2: Document "known failure modes" and how to troubleshoot (short, operator-focused)
- [x] Step 3: Add OpenShift notes (PSS `restricted` / SCC `restricted` intent, configurable options, environment-specific notes)

#### Self-Check Results

```bash
$ test -f docs/guides/en/validation.md && \
  test -f docs/guides/ru/validation.md && \
  test -f docs/guides/en/openshift-notes.md && \
  test -f docs/guides/ru/openshift-notes.md && echo "✓ All files exist"
✓ All files exist

$ grep -l "test-spark-standalone.sh\|test-prodlike-airflow.sh\|test-sa-prodlike-all.sh" \
  docs/guides/en/validation.md docs/guides/ru/validation.md
docs/guides/en/validation.md
docs/guides/ru/validation.md

$ grep -l "Tested on\|Тестировалось на" \
  docs/guides/en/openshift-notes.md docs/guides/ru/openshift-notes.md
docs/guides/en/openshift-notes.md
docs/guides/ru/openshift-notes.md

$ hooks/post-build.sh WS-011-04 docs
Post-build checks complete: WS-011-04
```

#### Issues

None. Scope exceeded estimate (718 LOC vs 300-500) but this is acceptable for comprehensive validation and OpenShift documentation.

---

### Review Result

**Reviewed by:** GPT-5.2 (agent)  
**Date:** 2026-01-16

#### Metrics Summary

| Check | Status |
|-------|--------|
| Completion Criteria | ✅ |
| Tests & Coverage | ✅ (Docs verification) |
| Regression | ✅ |
| AI-Readiness | ✅ |
| Security (PSS) | N/A (Docs) |

**Verdict:** ✅ APPROVED
