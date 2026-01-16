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

