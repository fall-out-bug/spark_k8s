## WS-011-02: Operator guides (EN) for all charts + values overlays

### 🎯 Цель (Goal)

**What should WORK after WS completion:**
- An English operator guide exists for:
  - `charts/spark-platform`
  - `charts/spark-standalone`
- Copy-pasteable values overlays exist for:
  - “any Kubernetes” baseline
  - “SA prod-like” (based on tested Minikube profile)

**Acceptance Criteria:**
- [ ] `docs/guides/en/charts/spark-platform.md` exists
- [ ] `docs/guides/en/charts/spark-standalone.md` exists
- [ ] `docs/guides/en/overlays/` contains copy-pasteable YAML overlays (at least 2)
- [ ] Guides include “quickstart” commands and reference existing `values*.yaml` files
- [ ] Guides explicitly state: tested on Minikube; prepared for OpenShift-like constraints

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

Docs must be minimal and actionable: which chart to choose, how to install it, and which values to start from.

### Dependency

WS-011-01

### Input Files

- `charts/spark-platform/values.yaml`
- `charts/spark-standalone/values.yaml`
- `charts/spark-standalone/values-prod-like.yaml`
- `charts/values-common.yaml`
- `scripts/test-*.sh`

### Steps

1. Add EN chart guides for both charts:
   - what it deploys
   - key values knobs (first 10)
   - install/upgrade examples
2. Add overlays under `docs/guides/en/overlays/`:
   - `values-anyk8s.yaml` (generic defaults + placeholders)
   - `values-sa-prodlike.yaml` (references tested `values-prod-like.yaml` and key toggles)
3. Reference smoke scripts and expected “green” outcomes.

### Expected Result

- New guides in `docs/guides/en/...`
- Overlays usable via `helm -f ...`

### Scope Estimate

- Files: ~4 created
- Lines: ~400-600 (MEDIUM)
- Tokens: ~1500-2500

### Completion Criteria

```bash
# Lint stays green
helm lint charts/spark-platform
helm lint charts/spark-standalone
```

