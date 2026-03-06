# Agent Instructions

## Agent Identity

You are an AI agent working in **spark_k8s** — Helm charts for Apache Spark on Kubernetes.

**Your role:** Execute tasks following project principles. Do not guess — use the navigation below.

**First actions:**
1. Read this file
2. Before touching `spark-infra` or `observability`: read [docs/operations/demo-protection.md](docs/operations/demo-protection.md)
3. For project state (features, gaps, drift): read [docs/workstreams/MEMORIES.md](docs/workstreams/MEMORIES.md)

---

## Where to Find What (Navigation Map)

| I need to... | Look here |
|--------------|-----------|
| **Understand principles & rules** | [.cursorrules](.cursorrules) — Core Principles, Testing, CI, Git |
| **Work with demo / spark-infra / observability** | [docs/operations/demo-protection.md](docs/operations/demo-protection.md) — full rules |
| **Find feature status, gaps, backlog, drift** | [docs/workstreams/MEMORIES.md](docs/workstreams/MEMORIES.md) — meta-library |
| **Provenance, evidence, trace** | [MEMORIES.md](docs/workstreams/MEMORIES.md) — Key Concepts |
| **Understand repo structure** | [.cursorrules](.cursorrules) — Repository Structure |
| **Run tests, matrix, quality gates** | `scripts/run-matrix-96.sh`, `tests/`, `pyproject.toml` |
| **Use SDP / workstreams / skills** | [CLAUDE.md](CLAUDE.md) — skills, @build, @review |
| **SDP CLI (status, drift, memory, verify)** | [MEMORIES.md](docs/workstreams/MEMORIES.md) — SDP CLI Reference |
| **Track issues (beads)** | `bd ready`, `bd show`, `bd close` — run `bd onboard` first |
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
- Principles: [.cursorrules](.cursorrules)
- Project state: [MEMORIES.md](docs/workstreams/MEMORIES.md)

### End of session (Landing the Plane)
1. File issues for remaining work
2. Run quality gates (if code changed)
3. Update issue status
4. **PUSH TO REMOTE** (MANDATORY):
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. Clean up, verify, hand off

**Work is NOT complete until `git push` succeeds.** Never stop before pushing.

---

## Quick Reference

### Beads (issue tracking)
```bash
bd onboard              # First-time setup
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --status in_progress   # Claim work
bd close <id>           # Complete work
bd sync                 # Sync with git
```

### SDP hooks (after submodule update)
```bash
sh .sdp/hooks/install-git-hooks.sh   # Symlinks pre-commit, pre-push, commit-msg
```

### SDP CLI (when sdp in PATH)
```bash
sdp status --text       # Project state (WS open/completed)
sdp drift detect [ws]  # Code↔docs drift
sdp memory search "X"  # Search indexed artifacts
sdp verify <ws-id>     # Verify WS completion
sdp log show           # Evidence log
sdp guard activate <ws-id>  # Before @build
```

### Canonical scripts (demo)
| Script | Purpose |
|--------|---------|
| `scripts/check-demo-health.sh` | Verify demo (run before/after changes) |
| `scripts/restore-demo.sh` | Recover from any failure |
| `scripts/deploy-demo-minikube.sh` | Fresh demo deploy |
| `scripts/tests/minikube/deploy-observability.sh` | Observability stack |
