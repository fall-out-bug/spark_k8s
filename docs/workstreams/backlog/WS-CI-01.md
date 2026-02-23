# WS-CI-01: Consolidate CI Workflows

## Summary
Consolidate 22 workflow files into layered architecture (fast/medium/slow) to eliminate duplication and speed up feedback loop.

## Scope
- Merge pr-validation.yml + code-validation.yml into ci-fast.yml
- Merge smoke-tests.yml + smoke-tests-parallel.yml into ci-medium.yml
- Create ci-slow.yml for E2E/load tests
- Add path filters to prevent unnecessary runs

## Acceptance Criteria
- [ ] ci-fast.yml created (lint + unit tests, <5 min)
- [ ] ci-medium.yml created (smoke tests + integration, <20 min)
- [ ] ci-slow.yml created (E2E + load, scheduled)
- [ ] Path filters added for docs/**, **.md
- [ ] Duplicate workflows archived (not deleted)
- [ ] All tests pass in new structure
- [ ] CI minutes reduced by 30%+

## Technical Design

### Before (22 files)
```
pr-validation.yml      # Duplicates: lint, unit tests
code-validation.yml    # Duplicates: lint, security
smoke-tests.yml        # Duplicates: lint, unit tests
smoke-tests-parallel.yml
e2e-tests.yml
load-tests.yml
...
```

### After (4 files)
```
ci-fast.yml      # Layer 1: <5 min, PR blocking
ci-medium.yml    # Layer 2: <20 min, merge
ci-slow.yml      # Layer 3: scheduled
deploy.yml       # Unified deploy
```

### ci-fast.yml Structure
```yaml
name: CI Fast

on:
  pull_request:
    branches: [main, dev]
    paths-ignore:
      - '**.md'
      - 'docs/**'

jobs:
  lint:
    strategy:
      matrix:
        tool: [black, flake8, ruff]
    runs-on: ubuntu-latest
    timeout-minutes: 5

  unit-tests:
    needs: lint
    runs-on: ubuntu-latest
    timeout-minutes: 10

  helm-lint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
```

## Definition of Done
- Code reviewed and merged
- All tests passing
- Old workflows moved to _archived/
- Documentation updated

## Estimated Effort
Medium (significant refactoring, careful testing)

## Blocked By
None

## Blocks
- WS-CI-02 (Composite Actions)
