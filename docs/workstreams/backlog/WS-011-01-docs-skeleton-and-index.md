## WS-011-01: Documentation skeleton (README index + docs/guides + repo map)

### 🎯 Цель (Goal)

**What should WORK after WS completion:**
- The repository has a clear documentation structure:
  - `README.md` acts as an index (EN + RU pointers)
  - detailed guides live under `docs/guides/`
- A “repo map” exists that explains what lives where and what to use for common tasks.

**Acceptance Criteria:**
- [ ] `docs/PROJECT_MAP.md` exists (high-level map of repository structure)
- [ ] `docs/guides/README.md` exists and links to all guides (EN + RU)
- [ ] `README.md` is updated to act as an index (links to guides + scripts + charts)
- [ ] All links in the index resolve to real files/paths

**WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

DevOps/DataOps users want “give me the chart”, but need fast orientation:
what charts exist, where values live, where scripts live, and which docs to read first.

This WS creates the documentation skeleton and a navigable index.

### Dependency

Independent

### Input Files

- `README.md`
- `charts/`
- `scripts/`
- `docs/` (existing SDP artifacts)

### Steps

1. Create `docs/PROJECT_MAP.md` with a short, scan-friendly repo map.
2. Create `docs/guides/README.md` as a docs index (EN/RU sections).
3. Update `README.md` to:
   - list available charts
   - link to `docs/guides/*`
   - link to smoke test scripts
4. Add a “Tested on Minikube / Prepared for OpenShift-like” note at top-level.

### Expected Result

- New files:
  - `docs/PROJECT_MAP.md`
  - `docs/guides/README.md`
- Updated `README.md` with clean navigation

### Scope Estimate

- Files: ~2 created + ~1 modified
- Lines: ~200 (SMALL)
- Tokens: ~600

### Completion Criteria

```bash
# Sanity check that files exist
test -f docs/PROJECT_MAP.md
test -f docs/guides/README.md

# No broken links (manual spot-check)
grep -n \"docs/guides\" README.md
```

