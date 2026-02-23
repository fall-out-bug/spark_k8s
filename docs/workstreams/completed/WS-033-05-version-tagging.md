---
ws_id: 033-05
feature: F24
status: completed
size: SMALL
project_id: 00
github_issue: spark_k8s-ds8.5
assignee: null
depends_on: []
---

## WS-033-05: Version Tagging Strategy

### 🎯 Goal

**What must WORK after completing this WS:**
- Image versioning strategy defined and documented
- Sync with Spark versions (3.5.7, 4.1.0)

**Acceptance Criteria:**
- [ ] AC1: Tag format documented (e.g. 4.1.0, 3.5.7)
- [ ] AC2: Semantic versioning for patches (4.1.0-1 if needed)
- [ ] AC3: `latest` tag policy (or explicit no-latest)
- [ ] AC4: Deprecation policy for old versions
- [ ] AC5: README section on image versions

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

Independent (no dependencies).

### Input

- README.md
- docs/plans/

### Scope

~60 LOC (docs). See docs/workstreams/INDEX.md Feature F24. Priority: P2.
