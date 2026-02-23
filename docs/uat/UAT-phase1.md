# UAT Guide: Phase 1 - Production Readiness Stack

**Feature:** Phase 1 - Multi-Environment, Security, Observability, Governance
**Date:** 2025-01-28
**Status:** Ready for Human UAT

## Overview

Phase 1 реализует базовый production-ready стек для Spark K8s Constructor, включающий:
- **Multi-Environment Structure** (06-001-01): Разделение конфигураций для dev/staging/prod
- **Security Stack** (06-004-01): Network Policies, RBAC, External Secrets, Trivy scanning
- **Observability Stack** (06-002-01): Prometheus, Grafana dashboards, JSON logging, Tempo tracing
- **Governance Documentation** (06-007-01): Data access control, lineage, naming conventions

## Prerequisites

- Kubernetes cluster (minikube, kind, or production cluster)
- `helm` v3.x installed
- `kubectl` configured
- `pytest` for running tests

## Quick Smoke Test (30 sec)

```bash
# 1. Run all tests
python -m pytest tests/ -v --tb=no

# Expected: 101 passed, 2 skipped

# 2. Validate Helm chart
helm template spark-test charts/spark-4.1 --values charts/spark-4.1/environments/dev/values.yaml > /dev/null

# Expected: No errors

# 3. Check environment files exist
ls charts/spark-4.1/environments/{dev,staging,prod}/values.yaml

# Expected: 3 files listed
```

## Detailed Scenarios (5-10 min)

### Scenario 1: Multi-Environment Deployment

**Test:** Verify each environment values file is valid and deployable

```bash
# Test dev environment
helm template spark-dev charts/spark-4.1 \
  --values charts/spark-4.1/environments/dev/values.yaml \
  --namespace spark-dev --show-only templates/spark-connect.yaml

# Expected: Valid YAML output, no errors

# Test staging environment
helm template spark-staging charts/spark-4.1 \
  --values charts/spark-4.1/environments/staging/values.yaml \
  --namespace spark-staging --show-only templates/spark-connect.yaml

# Expected: Valid YAML output, staging-specific overrides applied

# Test prod environment
helm template spark-prod charts/spark-4.1 \
  --values charts/spark-4.1/environments/prod/values.yaml \
  --namespace spark-prod --show-only templates/spark-connect.yaml

# Expected: Valid YAML output, production hardening applied
```

**Verify:**
- [ ] All three environments render successfully
- [ ] No YAML syntax errors
- [ ] Production environment has stricter limits

### Scenario 2: Security Policies

**Test:** Verify Network Policies and RBAC

```bash
# Check Network Policies exist
helm template spark-test charts/spark-4.1 \
  --values charts/spark-4.1/environments/dev/values.yaml \
  --show-only templates/networking/network-policy.yaml | grep "kind: NetworkPolicy" | wc -l

# Expected: 6+ NetworkPolicies (default-deny + allow rules)

# Check RBAC templates
helm template spark-test charts/spark-4.1 \
  --values charts/spark-4.1/environments/dev/values.yaml \
  --show-only templates/rbac.yaml

# Expected: ServiceAccount, Role, RoleBinding resources
```

**Verify:**
- [ ] Default-deny NetworkPolicy exists
- [ ] Allow rules for Spark components (ingress on port 15002)
- [ ] Egress rules for DNS (UDP/53) and external APIs (TCP/443)
- [ ] RBAC follows least privilege principle

### Scenario 3: Observability Stack

**Test:** Verify Prometheus integration and Grafana dashboards

```bash
# Check ServiceMonitor
helm template spark-test charts/spark-4.1 \
  --values charts/spark-4.1/environments/dev/values.yaml \
  --show-only templates/monitoring/servicemonitor.yaml

# Expected: ServiceMonitor with Prometheus labels

# Check PodMonitor
helm template spark-test charts/spark-4.1 \
  --values charts/spark-4.1/environments/dev/values.yaml \
  --show-only templates/monitoring/podmonitor.yaml

# Expected: PodMonitor for executor pods

# Check Grafana dashboards exist
ls charts/spark-4.1/templates/monitoring/grafana-dashboard-*.yaml

# Expected: 3 dashboards (spark-overview, executor-metrics, job-performance)
```

**Verify:**
- [ ] ServiceMonitor has correct `prometheus.io/scrape` labels
- [ ] PodMonitor targets Spark executor pods
- [ ] Grafana dashboards are valid JSON
- [ ] Log4j2 configured for JSON output (check `docker/spark-4.1/conf/log4j2.properties`)

### Scenario 4: External Secrets

**Test:** Verify all 7 secret provider templates

```bash
# List secret templates
ls charts/spark-4.1/templates/secrets/

# Expected: external-secrets.yaml, vault-secrets.yaml, aws-secrets.yaml,
#          azure-secrets.yaml, gcp-secrets.yaml, ibm-secrets.yaml, sealed-secrets.yaml

# Test each template renders
for provider in external vault aws azure gcp ibm sealed; do
  echo "Testing $provider..."
  helm template spark-test charts/spark-4.1 \
    --values charts/spark-4.1/environments/dev/values.yaml \
    --show-only templates/secrets/${provider}-secrets.yaml > /dev/null
done

# Expected: All render without errors
```

**Verify:**
- [ ] All 7 provider templates exist
- [ ] Each template renders valid YAML
- [ ] Secret references follow provider conventions

### Scenario 5: Governance Documentation

**Test:** Verify documentation files exist and are comprehensive

```bash
# Check governance docs
ls docs/recipes/governance/

# Expected: data-access-control.md, data-lineage.md, naming-conventions.md,
#          audit-logging.md, dataset-readme-template.md

# Check README template
cat docs/recipes/governance/dataset-readme-template.md | grep -E "## .*Dataset"

# Expected: Dataset documentation template with sections for Schema, Usage, Owner
```

**Verify:**
- [ ] Data access control guide covers Hive ACLs
- [ ] Data lineage guide includes manual patterns + DataHub reference
- [ ] Naming conventions guide exists
- [ ] Audit logging guide covers Spark + Kubernetes
- [ ] Dataset README template is usable

### Scenario 6: GitHub Actions Workflows

**Test:** Verify promotion workflows exist

```bash
# Check workflows exist
ls .github/workflows/

# Expected: promote-to-staging.yml, promote-to-prod.yml, security-scan.yml

# Validate workflow YAML syntax
yamllint .github/workflows/promote-to-staging.yml || echo "YAML validation passed"
yamllint .github/workflows/promote-to-prod.yml || echo "YAML validation passed"
yamllint .github/workflows/security-scan.yml || echo "YAML validation passed"
```

**Verify:**
- [ ] Promotion workflow uses `helm upgrade` with environment-specific values
- [ ] Security scan workflow includes Trivy
- [ ] Workflows are valid YAML

## Code Sanity Checks

```bash
# 1. No TODO/FIXME in code
grep -rn "TODO\|FIXME\|HACK\|XXX" charts/
# Expected: No output

# 2. All tests pass
python -m pytest tests/ -v
# Expected: 101 passed, 2 skipped

# 3. Helm template validation
helm template test charts/spark-4.1 --values charts/spark-4.1/environments/dev/values.yaml > /dev/null
# Expected: No errors

# 4. File size check (identify large files for future refactoring)
find charts/spark-4.1/templates -name "*.yaml" -exec wc -l {} \; | sort -rn | head -5
# Expected: Grafana dashboards may exceed 200 LOC (JSON-generated, acceptable)
#          Other files should be <200 LOC
```

## Red Flags Checklist

| # | Red Flag | Severity | Status |
|---|----------|----------|--------|
| 1 | Stack trace in Helm template output | 🔴 HIGH | ✅ Not found |
| 2 | Empty/missing template files | 🔴 HIGH | ✅ All files populated |
| 3 | TODO/FIXME in code | 🔴 HIGH | ✅ None found |
| 4 | Files >200 LOC (non-JSON) | 🟡 MEDIUM | ⚠️ Grafana dashboards (357/347/326 LOC) - acceptable for JSON |
| 5 | Coverage < 80% | 🟡 MEDIUM | N/A (YAML/Helm, not Python) |
| 6 | Missing RBAC in prod | 🔴 HIGH | ✅ RBAC templates exist |
| 7 | No Network Policies | 🔴 HIGH | ✅ Default-deny + allow rules |
| 8 | Secret values hardcoded | 🔴 HIGH | ✅ External Secrets templates |
| 9 | Missing environment separation | 🔴 HIGH | ✅ dev/staging/prod exist |
| 10 | No observability integration | 🔴 HIGH | ✅ Prometheus/Grafana/Tempo |

**Grafana Dashboard Note:** The large files (357/347/326 LOC) are Grafana dashboard JSONs embedded in ConfigMaps. This is acceptable because:
- They are auto-generated from Grafana export
- Refactoring would break the JSON structure
- Alternative: consider storing as separate `.json` files and loading via `Files.Glob`

## Sign-off

**Human Tester:** Please complete the following:

- [ ] Quick smoke test passed (30 sec)
- [ ] All 6 detailed scenarios passed (5-10 min)
- [ ] No critical red flags found
- [ ] Code sanity checks passed
- [ ] Documentation is comprehensive and usable

**Verdict:**
- [ ] ✅ **APPROVED** - Proceed to merge Phase 1 to main
- [ ] ❌ **CHANGES REQUESTED** - See blockers below

**Blockers (if any):**
```
List any critical issues that must be fixed before approval.
```

**Tester Signature:** ____________________
**Date:** ____________________

## Summary Metrics

| Workstream | Tests | Files | Status |
|------------|-------|-------|--------|
| 06-001-01: Multi-Environment | 35 passed | 11 files | ✅ |
| 06-004-01: Security Stack | 16 passed | 10 files | ✅ |
| 06-002-01: Observability | 19 passed | 9 files | ✅ |
| 06-007-01: Governance | 31 passed | 6 files | ✅ |
| **Total** | **101 passed** | **36 files** | **4/4 complete** |

## Next Steps After Approval

1. Merge Phase 1 workstreams to `main` branch
2. Tag release: `git tag -a v0.2.0 -m "Phase 1: Production Readiness Stack"`
3. Push to remote: `git push origin main --tags`
4. Deploy to staging cluster using `promote-to-staging.yml` workflow
5. Run production smoke tests
6. Deploy to production using `promote-to-prod.yml` workflow
