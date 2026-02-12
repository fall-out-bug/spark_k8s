# Python Code Validation Guide

This guide describes the Python code validation process used in CI/CD pipelines.

## Tools

### Black

Black is the uncompromising Python code formatter.

**Installation:**
```bash
pip install black
```

**Usage:**
```bash
# Check formatting
black --check --config configs/codestyle/pyproject.toml <path>

# Auto-format
black --config configs/codestyle/pyproject.toml <path>
```

**Configuration** (`configs/codestyle/pyproject.toml`):
```toml
[tool.black]
line-length = 100
target-version = ['py38', 'py39', 'py310', 'py311']
```

### isort

isort imports Python imports.

**Installation:**
```bash
pip install isort
```

**Usage:**
```bash
# Check import order
isort --check-only --settings-path configs/codestyle/pyproject.toml <path>

# Sort imports
isort --settings-path configs/codestyle/pyproject.toml <path>
```

### flake8

flake8 checks for style guide enforcement.

**Installation:**
```bash
pip install flake8
```

**Usage:**
```bash
flake8 --config=configs/codestyle/.flake8 <path>
```

**Configuration** (`configs/codestyle/.flake8`):
```ini
[flake8]
max-line-length = 100
ignore = E203, W503
max-complexity = 10
```

### mypy

mypy is a static type checker for Python.

**Installation:**
```bash
pip install mypy
```

**Usage:**
```bash
mypy --strict <path>
```

**Type hints are required** for all new Python code.

### bandit

bandit finds common security issues in Python code.

**Installation:**
```bash
pip install bandit
```

**Usage:**
```bash
bandit -r <path> -f txt
```

## CI/CD Integration

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
./scripts/cicd/lint-python.sh --dir scripts/ --fix
./scripts/cicd/lint-python.sh --dir tests/
```

### Pipeline Check

The CI/CD pipeline runs:

```bash
./scripts/cicd/lint-python.sh --dir <module>
```

## Quality Gates

| Gate | Requirement |
|------|-------------|
| Black | No formatting changes needed |
| isort | Imports properly sorted |
| flake8 | No errors |
| mypy | No type errors (--strict) |
| bandit | No high/critical issues |

## Common Issues

### E203: Whitespace before ':'
Ignored - conflicts with Black.

### W503: Line break before binary operator
Ignored - conflicts with Black.

### F401: Import unused but required
Use `# noqa` comment:

```python
from module import something  # noqa: F401
```

## Reference

- [Black documentation](https://black.readthedocs.io/)
- [isort documentation](https://pycqa.github.io/isort/)
- [flake8 documentation](https://flake8.pycqa.org/)
- [mypy documentation](https://mypy.readthedocs.io/)
- [bandit documentation](https://bandit.readthedocs.io/)
