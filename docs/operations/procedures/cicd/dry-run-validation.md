# Dry-Run Validation

> **Last Updated:** 2026-02-13
> **Owner:** Platform Team
> **Related:** [Job CI/CD Pipeline](./job-cicd-pipeline.md), [SQL Validation](./sql-validation.md)

## Overview

Dry-run validation ensures that Spark job configurations are valid before deployment. This prevents deployment failures by catching configuration errors early in the CI/CD pipeline.

## Validation Steps

### 1. Helm Template Validation

Validate that Helm templates render correctly:

```bash
scripts/cicd/dry-run-spark-job.sh \
  --chart charts/spark-4.1 \
  --values values/job/my-spark-job.yaml
```

**Checks performed:**
- Chart exists and is valid
- Values file is valid YAML
- Templates render without errors
- Kubernetes manifests are valid
- Required resources are defined

### 2. Kubernetes Manifest Validation

Validate rendered manifests against Kubernetes API:

```bash
helm template my-job charts/spark-4.1 --values values/job/my-spark-job.yaml | \
  kubectl apply --dry-run=client -f -
```

**Common issues detected:**
- Invalid API versions
- Missing required fields
- Incorrect resource requests/limits
- Invalid selectors or labels

### 3. Spark Configuration Validation

Validate Spark-specific configuration:

**Required settings:**
- `spark.executor.memory`: Must be specified
- `spark.executor.cores`: Must be specified
- `spark.executor.instances`: Recommended for static allocation
- `spark.dynamicAllocation.enabled`: For dynamic scaling

**Common configuration errors:**
- Memory too small for cores allocated
- Missing shuffle configuration
- Invalid shuffle service settings

## Automated Validation in CI

### GitHub Actions Workflow

```yaml
name: Spark Job Validation

on:
  pull_request:
    paths:
      - 'charts/spark-*/**'
      - 'values/jobs/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Helm
        uses: azure/setup-helm@v3

      - name: Install kubectl
        uses: azure/setup-kubectl@v3

      - name: Validate job configurations
        run: |
          for values_file in values/jobs/*.yaml; do
            ./scripts/cicd/dry-run-spark-job.sh \
              --chart charts/spark-4.1 \
              --values "$values_file"
          done
```

## Validation Criteria

### Must Pass

- Helm template renders successfully
- Kubernetes manifests are valid
- Driver and executor resources specified
- No syntax errors in configuration

### Should Pass

- Resource limits within cluster quotas
- Shuffle configuration appropriate for workload
- Dynamic allocation configured for variable workloads

### Warnings

- Using default values (not explicit)
- Resource requests significantly higher than needed
- Missing observability configuration

## Troubleshooting

### Template Rendering Errors

**Error:** `template: spark-driver: no matching key`

**Cause:** Missing required value in values.yaml

**Resolution:** Add missing value to values.yaml

### Kubernetes API Errors

**Error:** `could not find mapping for kind: CustomResourceDefinition`

**Cause:** CRD not installed in cluster

**Resolution:** Install required CRDs or remove custom resource from chart

### Resource Validation Errors

**Error:** `failed to calculate resource limits`

**Cause:** Invalid resource specification

**Resolution:** Ensure CPU/memory values use valid units (m, Mi, Gi)

## Best Practices

1. **Always dry-run before deploy:** Catch errors before deployment
2. **Validate in CI:** Run dry-run as part of pull request checks
3. **Use explicit values:** Avoid relying on chart defaults
4. **Review warnings:** Warnings often indicate potential issues
5. **Test in staging:** Always test in staging before production

## References

- [Job CI/CD Pipeline](./job-cicd-pipeline.md)
- [SQL Validation](./sql-validation.md)
- [Data Quality Gates](./data-quality-gates.md)
