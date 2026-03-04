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
helm lint charts/spark-3.5
pytest tests/ -v
```

## Pull Request Process

1. Create a branch from `dev`
2. Run `helm lint` and `pytest` before submitting
3. Use conventional commits: `feat(scope): description`
4. Link related issues

## Code of Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
