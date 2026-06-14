# Agent Instructions

## Agent Identity

You are an AI agent working in **spark_k8s** — Helm charts for Apache Spark on Kubernetes.

**Your role:** Execute tasks following project principles. Do not guess — use the navigation below.

**First actions:**
1. Read this file
2. Before touching `spark-infra` or `observability`: read [docs/operations/demo-protection.md](docs/operations/demo-protection.md)
3. For project principles: read [specs/_constitution.md](specs/_constitution.md)
4. For historical project state: read [docs/archive/sdp-workstreams/MEMORIES.md](docs/archive/sdp-workstreams/MEMORIES.md) (read-only provenance archive)

---

## Where to Find What (Navigation Map)

| I need to... | Look here |
|--------------|-----------|
| **Understand principles & rules** | [.cursorrules](.cursorrules) + [specs/_constitution.md](specs/_constitution.md) |
| **Work with demo / spark-infra / observability** | [docs/operations/demo-protection.md](docs/operations/demo-protection.md) — full rules |
| **Find project state (legacy archive)** | [docs/archive/sdp-workstreams/MEMORIES.md](docs/archive/sdp-workstreams/MEMORIES.md) — historical meta-library |
| **Understand repo structure** | [.cursorrules](.cursorrules) — Repository Structure |
| **Run tests, matrix, quality gates** | `scripts/run-matrix-96.sh`, `tests/`, `pyproject.toml` |
| **Use spec-kit workflow** | [CLAUDE.md](CLAUDE.md) — `/speckit.*` slash commands |
| **Track issues (GitHub)** | `/speckit.taskstoissues` — converts tasks to GitHub Issues |
| **Beads (DEPRECATED, read-only)** | `.beads/` archive — do NOT create new issues here |
| **End session** | Landing the Plane (below) |

---

## Regression Prevention (NON-NEGOTIABLE)

**Principle:** Critical paths (demo, deploy, smoke) must not regress. Use guards, tests, canonical scripts.

**Before ANY helm/kubectl touching spark-infra or observability:**
1. Run `./scripts/check-demo-health.sh` — if fails → `./scripts/restore-demo.sh` first
2. Read full rules: [docs/operations/demo-protection.md](docs/operations/demo-protection.md)

**Canonical scripts only** — never raw helm/kubectl for demo:
- `scripts/deploy-demo-minikube.sh` — fresh deploy
- `scripts/restore-demo.sh` — recover from failure
- `scripts/check-demo-health.sh` — verify (exit 0 = OK)

---

## Workflow

### Start of session
- Read AGENTS.md (this file)
- If task touches demo: read demo-protection.md, run check-demo-health.sh

### During work
- Principles: [.cursorrules](.cursorrules) + [specs/_constitution.md](specs/_constitution.md)
- Spec-Driven: use spec-kit slash commands (`/speckit.*`)
- Project state: [docs/archive/sdp-workstreams/MEMORIES.md](docs/archive/sdp-workstreams/MEMORIES.md) (legacy)

### End of session (Landing the Plane)
1. File issues for remaining work via `/speckit.taskstoissues` or GitHub Issues UI
2. Run quality gates (if code changed): `pre-commit run --all-files`, `helm lint charts/spark-3.5`, `helm lint charts/spark-4.1`
3. Verify demo: `./scripts/check-demo-health.sh`
4. **PUSH TO REMOTE** (MANDATORY):
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. Clean up, verify, hand off

**Work is NOT complete until `git push` succeeds.** Never stop before pushing.

---

## Quick Reference

### Spec-Kit workflow
```
/speckit.constitution                          # Establish/update project principles
/speckit.specify "Add metric X"                # Create spec in specs/<feature>/
/speckit.plan                                  # Technical plan
/speckit.tasks                                 # Actionable tasks list
/speckit.implement                             # Execute tasks
/speckit.analyze                               # Cross-artifact consistency check
```

Optional: `/speckit.clarify` (before plan), `/speckit.checklist` (after plan), `/speckit.taskstoissues` (publish to GitHub Issues).

### Pre-commit hooks (replaces SDP hooks)
```bash
pre-commit install -t pre-commit -t commit-msg
pre-commit run --all-files
```

Conventional Commits enforced via `conventional-pre-commit` hook.

### Beads (DEPRECATED — read-only)
Beads tracker (`.beads/`, `bd` CLI) is **frozen**. Do NOT create new issues here. Existing issues can still be queried for historical context, but new work goes through spec-kit tasks → GitHub Issues via `/speckit.taskstoissues`.

### Canonical scripts (demo)
| Script | Purpose |
|--------|---------|
| `scripts/check-demo-health.sh` | Verify demo (run before/after changes) |
| `scripts/restore-demo.sh` | Recover from any failure |
| `scripts/deploy-demo-minikube.sh` | Fresh demo deploy |
| `scripts/tests/minikube/deploy-observability.sh` | Observability stack |

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->
