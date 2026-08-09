# Contributing to Spark K8s

Thank you for your interest in contributing.

## Quick Ways to Contribute

- **Report bugs** — Use [Bug Report](.github/ISSUE_TEMPLATE/bug_report.yml) template
- **Suggest features** — Use [Feature Request](.github/ISSUE_TEMPLATE/feature_request.yml) template
- **Fix documentation** — PRs welcome for typos, clarity, examples
- **Good first issues** — Look for `good first issue` label

## Development Setup

```bash
git clone https://github.com/fall-out-bug/spark_k8s.git
cd spark_k8s

# OpenSpec (optional, for AI-assisted spec-driven workflows) — already initialized
# See openspec/ and https://github.com/Fission-AI/OpenSpec

# Validate Helm charts
helm lint charts/spark-3.5 charts/spark-4.1 charts/spark-base
helm template charts/spark-3.5 | head -50

# Run tests
pytest tests/integration/ tests/security/ -v
```

See [specs/_constitution.md](specs/_constitution.md) for project principles and
[AGENTS.md](AGENTS.md) for the agent workflow.

## Spec-Driven Development Workflow

This repo uses [OpenSpec](https://github.com/Fission-AI/OpenSpec) for spec-driven
feature development. Work is modeled as **changes** (proposed deltas):

```
openspec new change "Add feature X"           # create change in openspec/changes/
openspec apply <id>                           # implement
openspec verify <id>                          # validate consistency
openspec archive <id>                         # merge delta into main specs
```

Slash commands: `/opsx:new`, `/opsx:apply`, `/opsx:verify`, `/opsx:archive`.
Legacy specs live under `specs/` (reference only).

## Pull Request Process

1. Create a branch from `dev` (the working branch)
2. Run quality gates before submitting:
   ```bash
   pre-commit run --all-files
   helm lint charts/spark-3.5 charts/spark-4.1 charts/spark-base
   pytest tests/integration/ tests/security/ -q
   ./scripts/check-demo-health.sh  # if touching demo / observability
   ```
3. Use conventional commits: `feat(scope): description`, `fix(scope): description`,
   `docs:`, `test:`, `refactor:`, `chore:`, `perf:`, `ci:`, `build:`, `revert:`
4. Link related issues
5. Smoke matrix scenarios affected by your change must be marked in the PR description

## Regression Prevention

Critical paths (demo, deploy, smoke tests) must not regress. Before merging:

- If you touched `charts/spark-3.5/` or `charts/observability-demo/`: `./scripts/check-demo-health.sh` MUST pass
- If you added a new Spark version: update `scripts/tests/smoke/matrix/smoke-matrix.yaml` + image pyramid
- If you added a new feature (gpu/iceberg/etc.): extend smoke-matrix.yaml dimensions

## Code of Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
