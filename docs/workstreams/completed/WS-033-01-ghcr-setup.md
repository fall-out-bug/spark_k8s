---
ws_id: 033-01
feature: F24
status: completed
size: SMALL
project_id: 00
github_issue: spark_k8s-ds8.1
assignee: null
depends_on: []
---

## WS-033-01: GHCR Registry Setup

### 🎯 Goal

**What must WORK after completing this WS:**
- GitHub Container Registry configured for spark_k8s images
- Pull instructions documented
- CI/CD token-based auth ready

**Acceptance Criteria:**
- [ ] AC1: GHCR package `ghcr.io/fall-out-bug/spark-k8s` (or org) created/configured
- [ ] AC2: Repository permissions documented (public read)
- [ ] AC3: Pull instructions in README (docker pull, helm image override)
- [ ] AC4: GITHUB_TOKEN or PAT for CI push documented
- [ ] AC5: Package visibility (public) set

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- GitHub repo settings
- .github/workflows/ (for CI auth)

### Scope

~80 LOC (docs + config). See docs/workstreams/INDEX.md Feature F24.
