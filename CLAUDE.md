# Claude Code Integration Guide

Quick reference for working on `spark_k8s` — Helm charts for Apache Spark on Kubernetes.

> **🤖 Agents:** Read [AGENTS.md](AGENTS.md) first — entry point, navigation map, workflow. Then [specs/_constitution.md](specs/_constitution.md) for project principles.

## TL;DR

Spec-Driven Development via [OpenSpec](https://github.com/Fission-AI/OpenSpec). OpenSpec models work as **changes** — proposed deltas to specs that are proposed, implemented, verified, then archived. The main specs in `openspec/` always reflect the agreed current state; in-flight work lives under `openspec/changes/`.

```
openspec new change "Add metric X"   # Create a change (openspec/changes/<id>/)
openspec apply <id>                  # Implement the change's tasks
openspec verify <id>                 # Validate spec + implementation
openspec archive <id>                # Merge delta into main specs, archive
```

Slash commands (`/opsx:*`): `new`, `propose`, `apply`, `update`, `verify`, `archive`, `sync`, `explore`, `continue`, `ff`, `bulk-archive`.

## Available Skills

| Skill | Purpose |
|-------|---------|
| `openspec-new-change` (`/opsx:new`) | Start a new change proposal |
| `openspec-propose` (`/opsx:propose`) | Author / extend a change proposal |
| `openspec-apply-change` (`/opsx:apply`) | Implement a change's tasks |
| `openspec-update-change` (`/opsx:update`) | Update an in-flight change |
| `openspec-verify-change` (`/opsx:verify`) | Validate change consistency |
| `openspec-archive-change` (`/opsx:archive`) | Merge delta into main specs |
| `openspec-sync-specs` (`/opsx:sync`) | Sync delta specs without archiving |
| `openspec-explore` (`/opsx:explore`) | Search / read specs |
| `openspec-continue-change` (`/opsx:continue`) | Resume an in-flight change |

## Legacy `specs/`

`specs/` holds pre-OpenSpec feature specs (spec/plan/tasks) kept as **historical reference**. **New work goes through OpenSpec** (`openspec/`). Do not add new specs under `specs/`.

## Quick Reference

### Setup

OpenSpec is already initialized — `openspec/` is the spec root; the `openspec` CLI drives the workflow.

### Read core docs
- [AGENTS.md](AGENTS.md) — Agent entry point, navigation, workflow
- [specs/_constitution.md](specs/_constitution.md) — Project principles
- [.cursorrules](.cursorrules) — Principles, testing, CI (spark_k8s-specific)
- [PROJECT_CONVENTIONS.md](PROJECT_CONVENTIONS.md) — Repo conventions
- [docs/operations/demo-protection.md](docs/operations/demo-protection.md) — Demo rules, regression prevention

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

- `.claude/settings.json` — Claude Code settings
- `.claude/settings.local.json` — local permissions (gitignored)
- `openspec/` — OpenSpec spec root (current state + in-flight changes)
- `.zcode/` — OpenSpec skills + commands (agent harness)
- `specs/` — legacy spec-kit specs (reference only, not for new work)

## Resources

| Resource | Purpose |
|----------|---------|
| [AGENTS.md](AGENTS.md) | Agent entry point, navigation, workflow |
| [specs/_constitution.md](specs/_constitution.md) | Project principles |
| [.cursorrules](.cursorrules) | Principles, testing, CI (spark_k8s) |
| [PROJECT_CONVENTIONS.md](PROJECT_CONVENTIONS.md) | Repo conventions |
| [docs/operations/demo-protection.md](docs/operations/demo-protection.md) | Demo rules, regression prevention |
| [docs/archive/sdp-workstreams/](docs/archive/sdp-workstreams/) | Historical WS archive (provenance) |

---

**SDD framework:** OpenSpec · **Mode:** OpenSpec changes (`new → apply → verify → archive`)
