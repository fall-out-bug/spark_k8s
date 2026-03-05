# WS-CI-02: Create Composite Actions

## Summary
Extract common CI patterns into reusable composite actions to reduce code duplication.

## Scope
- setup-spark-env action (Python, Helm, kubectl)
- run-kind-cluster action (kind setup with cleanup)
- smoke-test-scenario action (unified scenario runner)

## Acceptance Criteria
- [ ] .github/actions/setup-spark-env/action.yml created
- [ ] .github/actions/run-kind-cluster/action.yml created
- [ ] Actions tested in ci-fast.yml and ci-medium.yml
- [ ] Version pinning for all tools (Python 3.11, Helm 3.14, etc.)
- [ ] Documentation in each action.yml

## Technical Design

### setup-spark-env/action.yml
```yaml
name: 'Setup Spark Environment'
description: 'Install Python, Helm, kubectl for Spark K8s CI'

inputs:
  python-version:
    description: 'Python version'
    required: false
    default: '3.11'
  helm-version:
    description: 'Helm version'
    required: false
    default: 'v3.14.0'
  kubectl-version:
    description: 'kubectl version'
    required: false
    default: 'v1.28.0'

runs:
  using: 'composite'
  steps:
    - uses: actions/setup-python@v5
      with:
        python-version: ${{ inputs.python-version }}
        cache: 'pip'

    - uses: azure/setup-helm@v4
      with:
        version: ${{ inputs.helm-version }}

    - uses: azure/setup-kubectl@v4
      with:
        version: ${{ inputs.kubectl-version }}

    - name: Install Python dependencies
      shell: bash
      run: |
        pip install -r requirements-test.txt
```

### run-kind-cluster/action.yml
```yaml
name: 'Run Kind Cluster'
description: 'Create kind cluster with Spark operator'

inputs:
  cluster-name:
    description: 'Kind cluster name'
    required: false
    default: 'spark-test'

runs:
  using: 'composite'
  steps:
    - uses: helm/kind-action@v1.8.0
      with:
        cluster_name: ${{ inputs.cluster-name }}
        version: v0.20.0

    - name: Install Spark Operator
      shell: bash
      run: |
        helm repo add spark-operator https://kubeflow.github.io/spark-operator
        helm install spark-operator spark-operator/spark-operator \
          --namespace spark-operator --create-namespace --wait
```

## File Structure
```
.github/actions/
├── setup-spark-env/
│   └── action.yml
├── run-kind-cluster/
│   └── action.yml
└── README.md
```

## Definition of Done
- All actions created and tested
- Used in at least 2 workflows
- Documentation complete

## Estimated Effort
Small (well-defined scope)

## Blocked By
- WS-CI-01 (Consolidate Workflows)

## Blocks
None
