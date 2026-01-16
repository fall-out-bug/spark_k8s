## WS-011-03: Operator guides (RU) for all charts + values overlays

### 🎯 Цель (Goal)

**What should WORK after WS completion:**
- A Russian operator guide exists for:
  - `charts/spark-platform`
  - `charts/spark-standalone`
- Russian overlays and examples match the English ones (no drift).

**Acceptance Criteria:**
- [ ] `docs/guides/ru/charts/spark-platform.md` exists
- [ ] `docs/guides/ru/charts/spark-standalone.md` exists
- [ ] `docs/guides/ru/overlays/` contains the same overlays as EN (or references EN overlays)
- [ ] RU docs preserve the same “tested vs prepared” claims as EN

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

Audience is DevOps/DataOps. We need a Russian version to reduce friction, but content must stay aligned with EN.

### Dependency

WS-011-02

### Input Files

- `docs/guides/en/...` (source-of-truth for structure)
- `charts/*`
- `scripts/*`

### Steps

1. Translate chart guides to RU (keeping commands identical).
2. Provide RU overlays either:
   - as copies of EN overlays, or
   - as thin wrappers referencing EN overlays (prefer no duplication if possible).
3. Add cross-links between EN and RU docs.

### Expected Result

- RU guides under `docs/guides/ru/...`

### Scope Estimate

- Files: ~4 created
- Lines: ~400-600 (MEDIUM)
- Tokens: ~1500-2500

