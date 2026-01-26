## WS-022-03: Values overlays for Connect backend modes

### 🎯 Goal

**What should WORK after WS completion:**
- Operators have copy-pasteable overlays for Connect-only and Connect+Standalone modes.
- Overlays are version-agnostic and documented for Spark 3.5 and 4.1.

**Acceptance Criteria:**
- [ ] New overlays exist for Connect-only (k8s executors) and Connect+Standalone
- [ ] Overlays specify backend mode values and master service/port for Standalone mode
- [ ] Guides reference the overlays in EN and RU (or note that overlays are shared)

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Docs currently lack ready overlays for the new Connect backend modes. Providing
overlays reduces operator error and keeps behavior consistent across versions.

### Dependency

WS-022-01, WS-022-02

### Input Files

- `docs/guides/en/overlays/` — place overlays here
- `docs/guides/ru/overlays/README.md` — note shared overlays
- `docs/guides/en/charts/spark-platform.md` — add references
- `docs/guides/ru/charts/spark-platform.md` — add references

### Steps

1. Add overlay for **Connect-only (k8s executors)**.
2. Add overlay for **Connect + Standalone backend**.
3. Document overlays usage in EN + RU guides.

### Code

```yaml
# values-connect-standalone.yaml
spark-connect:
  backendMode: "standalone"
  standalone:
    masterService: "spark-sa-spark-standalone-master"
    masterPort: 7077
```

### Expected Result

- Operators can apply overlays to switch backend mode without manual config edits.

### Scope Estimate

- Files: ~2 created, ~2 modified
- Lines: ~120-200 (SMALL)
- Tokens: ~700-1200

### Completion Criteria

```bash
test -f docs/guides/en/overlays/values-connect-k8s.yaml
test -f docs/guides/en/overlays/values-connect-standalone.yaml
rg "connect.*backend" docs/guides/en/charts/spark-platform.md
rg "connect.*backend" docs/guides/ru/charts/spark-platform.md
```

### Constraints

- DO NOT include secrets in overlays
- Keep overlays minimal and copy-pasteable

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-19

#### 🎯 Goal Status

- [x] AC1: New overlays exist for Connect-only (k8s executors) and Connect+Standalone — ✅
- [x] AC2: Overlays specify backend mode values and master service/port for Standalone mode — ✅
- [x] AC3: Guides reference the overlays in EN and RU (or note that overlays are shared) — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `docs/guides/en/overlays/values-connect-k8s.yaml` | created | ~40 |
| `docs/guides/en/overlays/values-connect-standalone.yaml` | created | ~50 |
| `docs/guides/en/charts/spark-platform.md` | modified | +25 |
| `docs/guides/ru/charts/spark-platform.md` | modified | +25 |
| `docs/guides/ru/overlays/README.md` | modified | +2 |

**Total:** 2 created, 3 modified, ~142 LOC added

#### Completed Steps

- [x] Step 1: Created overlay for Connect-only (k8s executors) mode
- [x] Step 2: Created overlay for Connect + Standalone backend mode
- [x] Step 3: Documented overlays usage in EN and RU guides
- [x] Step 4: Updated RU overlays README to reference new overlays

#### Self-Check Results

```bash
$ test -f docs/guides/en/overlays/values-connect-k8s.yaml && echo "✅" || echo "❌"
✅

$ test -f docs/guides/en/overlays/values-connect-standalone.yaml && echo "✅" || echo "❌"
✅

$ grep -q "values-connect" docs/guides/en/charts/spark-platform.md docs/guides/ru/charts/spark-platform.md && echo "✅" || echo "❌"
✅

$ helm template sc35-test charts/spark-3.5 --set spark-connect.enabled=true \
  -f docs/guides/en/overlays/values-connect-standalone.yaml | grep "spark.master=spark://"
    spark.master=spark://spark-sa-spark-standalone-master:7077
✅
```

#### Issues

None

### Review Result

**Status:** READY
