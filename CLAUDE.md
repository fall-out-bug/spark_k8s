# Claude Code Integration Guide

Quick reference for working on `spark_k8s` — Helm charts for Apache Spark on Kubernetes.

> **🤖 Agents:** Read [AGENTS.md](AGENTS.md) first — entry point, navigation map, workflow. Then [specs/_constitution.md](specs/_constitution.md) for project principles.

## TL;DR

Spec-Driven Development via [GitHub spec-kit](https://github.com/github/spec-kit). Workflow:

```
/speckit.constitution                 # Establish/update project principles (already done)
/speckit.specify "Add metric X"       # Create spec in specs/<feature>/
/speckit.plan                         # Technical plan
/speckit.tasks                        # Actionable tasks list
/speckit.implement                    # Execute tasks
/speckit.analyze                      # Cross-artifact consistency check
```

Optional: `/speckit.clarify` (before plan), `/speckit.checklist` (after plan), `/speckit.taskstoissues` (publish to GitHub Issues).

## Available Skills (after `specify init`)

| Skill | Purpose |
|-------|---------|
| `/speckit.constitution` | Establish project-wide principles |
| `/speckit.specify` | Define what to build (requirements, user stories) |
| `/speckit.plan` | Technical implementation plan |
| `/speckit.tasks` | Actionable task list |
| `/speckit.implement` | Execute tasks |
| `/speckit.analyze` | Cross-artifact consistency report |
| `/speckit.clarify` | Clarify ambiguous areas (pre-plan) |
| `/speckit.checklist` | Quality checklist (post-plan) |
| `/speckit.taskstoissues` | Convert tasks to GitHub Issues |

## Quick Reference

### First Time Setup

1. **Install spec-kit** (requires [uv](https://docs.astral.sh/uv/)):
   ```bash
   uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
   ```

2. **Initialize in this repo** (already done):
   ```bash
   specify init --here --integration claude --ignore-agent-tools --script sh --force
   ```

3. **Read core docs:**
   - [AGENTS.md](AGENTS.md) — Agent entry point, navigation, workflow
   - [specs/_constitution.md](specs/_constitution.md) — Project principles (spec-kit constitution)
   - [.cursorrules](.cursorrules) — Principles, testing, CI (spark_k8s-specific)
   - [PROJECT_CONVENTIONS.md](PROJECT_CONVENTIONS.md) — Repo conventions
   - [docs/operations/demo-protection.md](docs/operations/demo-protection.md) — Demo rules, regression prevention

### Typical Workflow

```bash
# 1. Define spec
/speckit.specify "Add Spark Connect GPU profiling dashboard"
# Result: specs/spark-connect-gpu-dashboard/spec.md

# 2. Plan
/speckit.plan
# Result: specs/spark-connect-gpu-dashboard/plan.md

# 3. Tasks
/speckit.tasks
# Result: specs/spark-connect-gpu-dashboard/tasks.md

# 4. Implement (executes all tasks)
/speckit.implement

# 5. Analyze (cross-artifact consistency)
/speckit.analyze
```

### Quality Gates (Enforced)

| Gate | Requirement |
|------|-------------|
| **AI-Readiness** | Files < 200 LOC, CC < 10, type hints |
| **Error Handling** | No `except: pass` |
| **No TODOs** | All tasks completed |

**spark_k8s:** helm lint, helm template, security assertions — see [.cursorrules](.cursorrules). Coverage is not a metric for Helm chart repos.

### Regression Prevention (NON-NEGOTIABLE)

**Critical paths (demo, deploy, smoke) must not regress.**

Before ANY helm/kubectl touching spark-infra or observability:
1. Run `./scripts/check-demo-health.sh` — if fails → `./scripts/restore-demo.sh` first
2. Read [docs/operations/demo-protection.md](docs/operations/demo-protection.md)

Canonical scripts only — never raw helm/kubectl for demo:
- `scripts/deploy-demo-minikube.sh` — fresh deploy
- `scripts/restore-demo.sh` — recover from failure
- `scripts/check-demo-health.sh` — verify (exit 0 = OK)

## Forbidden Patterns

- `except: pass` or bare exceptions
- Time-based estimates
- Files > 200 LOC
- `--cov=tests` (spark_k8s: self-coverage forbidden)
- `|| true` in CI test/lint steps
- `continue-on-error: true` on blocking CI steps
- pytest tests that only check `Path.exists()`

## Required Patterns

- Type hints everywhere
- Explicit error handling
- Clean architecture boundaries
- Conventional commits: `feat(chart):`, `fix(chart):`, `docs:`, `test:`, `chore:`

## Configuration

- `.claude/settings.json` — Claude Code settings (projectType, specKit integrations)
- `.claude/settings.local.json` — local permissions (gitignored)
- `.specify/` — spec-kit core (templates, scripts, workflows, extensions)
- `specs/` — feature specs (spec/plan/tasks/constitution)

## Resources

| Resource | Purpose |
|----------|---------|
| [AGENTS.md](AGENTS.md) | Agent entry point, navigation, workflow |
| [specs/_constitution.md](specs/_constitution.md) | Project principles (spec-kit) |
| [.cursorrules](.cursorrules) | Principles, testing, CI (spark_k8s) |
| [PROJECT_CONVENTIONS.md](PROJECT_CONVENTIONS.md) | Repo conventions |
| [docs/operations/demo-protection.md](docs/operations/demo-protection.md) | Demo rules, regression prevention |
| [docs/archive/sdp-workstreams/](docs/archive/sdp-workstreams/) | Historical WS archive (provenance) |

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->

---

**Spec-Kit Version:** 0.10.3
**Mode:** spec-kit SDD (specify → plan → tasks → implement)
