# Composite Actions

Reusable GitHub Actions composite actions for Spark K8s CI/CD.

## Available Actions

### setup-spark-env

Install Python, Helm, and kubectl for Spark K8s CI.

```yaml
- uses: ./.github/actions/setup-spark-env
  with:
    python-version: '3.11'
    helm-version: 'v3.14.0'
    kubectl-version: 'v1.28.0'
    install-deps: 'true'
```

### run-kind-cluster

Create a kind cluster with optional Spark operator and MinIO.

```yaml
- uses: ./.github/actions/run-kind-cluster
  with:
    cluster-name: 'spark-test'
    kind-version: 'v0.20.0'
    k8s-version: 'v1.28.0'
    install-spark-operator: 'true'
    install-minio: 'false'
```

## Usage in Workflows

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup environment
        uses: ./.github/actions/setup-spark-env

      - name: Create cluster
        uses: ./.github/actions/run-kind-cluster
        with:
          cluster-name: 'test-cluster'
```

## Version Pinning

All actions use pinned versions:
- Python: 3.11
- Helm: v3.14.0
- kubectl: v1.28.0
- Kind: v0.20.0

Update versions in action.yml inputs as needed.
