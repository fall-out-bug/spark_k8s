# Job CI/CD Pipeline

## Overview

This procedure defines the CI/CD pipeline for Spark jobs, covering validation, testing, promotion, and deployment automation.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Spark Job CI/CD Pipeline                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Developer Push                                                        │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                1. Lint & Style Checks                           │   │
│  │  - Python: black, flake8, pylint                               │   │
│  │  - Scala: scalafmt, scalastyle                                 │   │
│  │  - SQL: spark-sql-validator                                    │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                2. Security Scanning                            │   │
│  │  - Dependency vulnerabilities                                  │   │
│  │  - Code security (bandit, security-scan)                       │   │
│  │  - Secret detection (gitleaks)                                 │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                3. Unit Tests                                  │   │
│  │  - Python: pytest                                             │   │
│  │  - Scala: scalatest                                            │   │
│  │  - Java: JUnit                                                 │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                4. SQL Validation                              │   │
│  │  - Syntax checking                                             │   │
│  │  - Schema validation (against Hive Metastore)                  │   │
│  │  - Query plan analysis (detect anti-patterns)                  │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                5. Dry-Run Validation                           │   │
│  │  - Helm template rendering                                     │   │
│  │  - Kubernetes manifest validation                               │   │
│  │  - Resource limit checking                                     │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                6. Build & Push Artifact                        │   │
│  │  - Build Docker image                                           │   │
│  │  - Push to registry                                             │   │
│  │  - Tag with commit SHA and version                             │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                7. Deploy to Dev (Auto)                         │   │
│  │  - Apply Kubernetes manifests                                  │   │
│  │  - Verify deployment                                           │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                8. Smoke Tests (Dev)                             │   │
│  │  - Run test data through pipeline                             │   │
│  │  - Verify output quality                                      │   │
│  │  - Check performance metrics                                  │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                9. Promote to Staging (Manual)                 │   │
│  │  - Requires:                                                  │   │
│  │    - All tests passing                                        │   │
│  │    - Manual approval (via GitHub UI)                          │   │
│  │    - No critical findings                                      │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                10. Integration Tests (Staging)                │   │
│  │  - Full pipeline test                                         │   │
│  │  - Data quality checks                                        │   │
│  │  - Performance validation                                     │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                11. Promote to Production (Manual)             │   │
│  │  - Requires:                                                  │   │
│  │    - Staging tests passing                                    │   │
│  │    - Production readiness review                              │   │
│  │    - Scheduled maintenance window (optional)                  │   │
│  │    - Management approval                                      │   │
│  └────────────────────────────────────────────────────────────────┘   │
│       │                                                                │
│       ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                12. Production Smoke Tests                     │   │
│  │  - Verify deployment successful                                │   │
│  │  - Monitor for 30 minutes                                      │   │
│  │  - Rollback on failure                                        │   │
│  └────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Environment Configuration

### Environments

| Environment | Purpose | Auto-Deploy | Approval Required | Data |
|-------------|---------|-------------|-------------------|------|
| Dev | Development and testing | Yes | No | Synthetic |
| Staging | Pre-production validation | Manual | Yes (Tech Lead) | Anonymized |
| Production | Live data processing | Manual | Yes (Manager) | Real |

### Environment Promotion Criteria

**Dev → Staging**:
- All CI checks pass
- Unit tests pass
- Smoke tests pass
- No critical security vulnerabilities
- Code review approved

**Staging → Production**:
- All integration tests pass
- Data quality checks pass
- Performance meets SLA
- Production readiness checklist complete
- Change management approved

## CI Pipeline Configuration

### GitHub Actions Workflow: `.github/workflows/spark-job-ci.yml`

```yaml
name: Spark Job CI

on:
  push:
    branches: [ main, dev ]
  pull_request:
    branches: [ main ]

env:
  PYTHON_VERSION: "3.11"
  SCALA_VERSION: "2.12"
  SPARK_VERSION: "3.5.0"

jobs:
  lint:
    name: Lint & Style Checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Install Python linting tools
        run: |
          pip install black flake8 pylint mypy

      - name: Run Black (Python formatter check)
        run: |
          black --check --diff .

      - name: Run Flake8 (Python linter)
        run: |
          flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
          flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics

      - name: Run Pylint
        run: |
          pylint **/*.py --exit-zero --output-format=colorized

  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run Bandit (Python security)
        run: |
          pip install bandit[toml]
          bandit -r . -f json -o bandit-report.json || true

      - name: Run Gitleaks (secret detection)
        uses: gitleaks/gitleaks-action@v2

      - name: Run Safety (dependency vulnerabilities)
        run: |
          pip install safety
          safety check --json > safety-report.json || true

      - name: Upload security reports
        uses: actions/upload-artifact@v3
        with:
          name: security-reports
          path: |
            bandit-report.json
            safety-report.json

  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov pytest-mock

      - name: Run tests with coverage
        run: |
          pytest --cov=. --cov-report=xml --cov-report=html --cov-report=term

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3

  sql-validation:
    name: SQL Validation
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4

      - name: Run SQL validation
        run: |
          scripts/cicd/validate-sql.sh

      - name: Analyze SQL query plans
        run: |
          scripts/cicd/analyze-sql-plan.sh

  dry-run:
    name: Dry-Run Validation
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Helm
        uses: azure/setup-helm@v3

      - name: Helm dry-run
        run: |
          helm template spark-job ./charts/spark-job \
            --set job.image.tag=${{ github.sha }} \
            --dry-run \
            --debug

      - name: Validate manifests
        run: |
          kubectl apply --dry-run=server -f charts/spark-job/templates/

  build:
    name: Build & Push
    needs: [lint, security-scan, unit-tests, sql-validation, dry-run]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to registry
        uses: docker/login-action@v2
        with:
          registry: ${{ secrets.REGISTRY_URL }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            ${{ secrets.REGISTRY_URL }}/spark-job:${{ github.sha }}
            ${{ secrets.REGISTRY_URL }}/spark-job:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy-dev:
    name: Deploy to Dev
    needs: build
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - uses: actions/checkout@v3

      - name: Set up kubectl
        uses: azure/setup-kubectl@v3

      - name: Deploy to dev cluster
        run: |
          scripts/cicd/promote-job.sh \
            --environment dev \
            --image ${{ secrets.REGISTRY_URL }}/spark-job:${{ github.sha }} \
            --version ${{ github.sha }}

      - name: Verify deployment
        run: |
          kubectl wait --for=condition=ready pod -l app=spark-job,version=${{ github.sha }} -n spark-dev --timeout=5m

  smoke-tests:
    name: Smoke Tests
    needs: deploy-dev
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run smoke tests
        run: |
          scripts/cicd/smoke-test-job.sh --environment dev
```

### GitHub Actions Workflow: `.github/workflows/spark-job-deploy.yml`

```yaml
name: Spark Job Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - staging
          - production
      version:
        description: 'Image version (git SHA)'
        required: true
      approval:
        description: 'Manager approval required for production'
        required: false
        type: boolean
        default: true

env:
  REGISTRY: ghcr.io

jobs:
  promote-staging:
    name: Promote to Staging
    if: inputs.environment == 'staging'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v3

      - name: Set up kubectl
        uses: azure/setup-kubectl@v3

      - name: Deploy to staging
        run: |
          scripts/cicd/promote-job.sh \
            --environment staging \
            --image ${{ env.REGISTRY }}/spark-job:${{ inputs.version }} \
            --version ${{ inputs.version }}

      - name: Run integration tests
        run: |
          scripts/tests/integration/run-integration-tests.sh --environment staging

  promote-production:
    name: Promote to Production
    if: inputs.environment == 'production'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v3

      - name: Set up kubectl
        uses: azure/setup-kubectl@v3

      - name: Deploy to production
        run: |
          scripts/cicd/promote-job.sh \
            --environment production \
            --image ${{ env.REGISTRY }}/spark-job:${{ inputs.version }} \
            --version ${{ inputs.version }}

      - name: Wait for deployment
        run: |
          kubectl wait --for=condition=ready pod -l app=spark-job,version=${{ inputs.version }} -n spark-production --timeout=10m

      - name: Run production smoke tests
        run: |
          scripts/cicd/smoke-test-job.sh --environment production

      - name: Monitor for 30 minutes
        run: |
          scripts/cicd/monitor-deployment.sh --duration 30m
```

## Validation Scripts

### SQL Validation

```bash
#!/bin/bash
# scripts/cicd/validate-sql.sh

set -euo pipefail

# Find all SQL files
SQL_FILES=$(find . -name "*.sql" -not -path "./.venv/*" -not -path "./venv/*")

for sql_file in $SQL_FILES; do
    echo "Validating $sql_file..."

    # Syntax check using spark-sql
    spark-sql --driver-memory 1g -e "EXPLAIN $(cat $sql_file)" 2>&1 | grep -i "error" && exit 1

    # Schema validation (if connected to Hive Metastore)
    scripts/cicd/validate-sql-schema.sh --file "$sql_file"

    echo "$sql_file: OK"
done
```

### Dry-Run Validation

```bash
#!/bin/bash
# scripts/cicd/dry-run-spark-job.sh

set -euo pipefail

JOB_NAME="${1:-test-job}"
IMAGE="${2:-spark-job:latest}"

echo "Dry-run validation for $JOB_NAME..."

# Helm template validation
helm template spark-job ./charts/spark-job \
    --set job.image.tag="$IMAGE" \
    --dry-run \
    --debug > /tmp/job-manifest.yaml

# kubectl validation
kubectl apply --dry-run=server -f /tmp/job-manifest.yaml

# Resource limit validation
python scripts/cicd/validate-resource-limits.py --manifest /tmp/job-manifest.yaml

echo "Dry-run validation passed!"
```

### Smoke Tests

```bash
#!/bin/bash
# scripts/cicd/smoke-test-job.sh

set -euo pipefail

ENVIRONMENT="${1:-dev}"

echo "Running smoke tests in $ENVIRONMENT..."

# Submit test job
kubectl apply -f tests/smoke/test-spark-job.yaml

# Wait for completion
kubectl wait --for=condition=complete sparkapp/test-job -n "spark-$ENVIRONMENT" --timeout=10m

# Verify output
python tests/smoke/verify-output.py

# Check metrics
python tests/smoke/verify-metrics.py

echo "Smoke tests passed!"
```

## Promotion Procedure

### Step 1: Pre-Promotion Checklist

- [ ] All CI checks pass
- [ ] Code review approved
- [ ] Security scan clean (or exceptions documented)
- [ ] Unit tests pass with > 80% coverage
- [ ] Integration tests pass
- [ ] Performance meets SLA
- [ ] Documentation updated
- [ ] Runbook created/updated if needed

### Step 2: Deploy to Staging

```bash
# Using promotion script
scripts/cicd/promote-job.sh \
    --environment staging \
    --version abc123 \
    --wait
```

### Step 3: Staging Validation

```bash
# Run integration tests
scripts/tests/integration/run-all.sh --environment staging

# Verify data quality
scripts/cicd/run-data-quality-checks.sh --environment staging

# Check performance
scripts/cicd/verify-performance-sla.sh --environment staging
```

### Step 4: Production Deployment Request

Create GitHub issue with:
- Version to deploy
- Changes included
- Test results
- Risk assessment
- Rollback plan

Get approval from:
- Tech Lead (for P1 changes)
- Engineering Manager (for P0 changes)

### Step 5: Deploy to Production

```bash
# Schedule deployment
scripts/cicd/schedule-deployment.sh \
    --environment production \
    --version abc123 \
    --window "2026-02-12 02:00"

# Monitor deployment
scripts/cicd/monitor-deployment.sh \
    --environment production \
    --version abc123
```

### Step 6: Post-Deployment

```bash
# Run smoke tests
scripts/cicd/smoke-test-job.sh --environment production

# Monitor for 30 minutes
scripts/cicd/monitor-deployment.sh --duration 30m

# Generate deployment report
scripts/cicd/generate-deployment-report.sh \
    --environment production \
    --version abc123
```

## Rollback Procedure

### Immediate Rollback

```bash
# Rollback to previous version
scripts/cicd/rollback-job.sh \
    --environment production \
    --to-version previous

# Or specific version
scripts/cicd/rollback-job.sh \
    --environment production \
    --to-version def456
```

### Rollback Validation

```bash
# Verify rollback successful
kubectl get pods -n spark-production -l app=spark-job

# Run smoke tests
scripts/cicd/smoke-test-job.sh --environment production

# Check metrics
kubectl top pods -n spark-production
```

## Related Procedures

- [SQL Validation](./sql-validation.md)
- [Data Quality Gates](./data-quality-gates.md)
- [Blue-Green Deployment](./blue-green-deployment.md)
- [A/B Testing](./ab-testing.md)

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
