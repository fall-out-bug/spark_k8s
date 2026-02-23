# UAT Guide: F14 — Phase 8 Advanced Security

**Feature:** F14  
**Date:** 2026-02-10  

---

## Overview

F14 delivers 48 security test scenarios across PSS, SCC, Network Policies, RBAC, Secret Management, Container Security, and S3 Security. Tests validate Spark Helm charts against production-ready security standards via `helm template` + YAML parsing (no live cluster required for most tests).

---

## Prerequisites

Before testing, ensure:

- [ ] Python 3.10+ with pytest, pyyaml
- [ ] `helm` installed and in PATH
- [ ] Repository checked out at project root
- [ ] Run from repo root with `PYTHONPATH=.` (or `export PYTHONPATH=.`) for security test imports

### Quick Environment Check

```bash
python -m pytest --version
helm version
```

---

## Quick Verification (30 seconds)

### Smoke Test

```bash
PYTHONPATH=. pytest tests/security/ -q --tb=no
```

**Expected result:** All pass or skip (0 failures). Note: PYTHONPATH=. required for `tests.security.conftest` import.

---

## Detailed Scenarios

### Scenario 1: PSS Tests

**Description:** Validate Pod Security Standards (restricted/baseline) for Spark 3.5 and 4.1.

```bash
pytest tests/security/pss/ -v
```

**Expected:** All pass. Namespace labels, non-root user, privilege escalation, capabilities, seccomp validated.

### Scenario 2: SCC Tests

**Description:** Validate OpenShift Security Context Constraints (anyuid, nonroot, restricted-v2).

```bash
pytest tests/security/scc/ -v
```

**Expected:** All pass. OpenShift presets and UID ranges validated.

### Scenario 3: RBAC Tests

**Description:** Validate least-privilege RBAC (ServiceAccount, Role, ClusterRole).

```bash
pytest tests/security/rbac/ -v
```

**Expected:** All pass. No wildcard permissions.

### Scenario 4: Secret Management

**Description:** Validate no hardcoded secrets, correct secret refs.

```bash
pytest tests/security/secrets/ -v
```

**Expected:** All pass.

### Scenario 5: Container Security

**Description:** Validate non-root, no privilege escalation, read-only FS, dropped capabilities.

```bash
pytest tests/security/container/ -v
```

**Expected:** All pass.

### Scenario 6: S3 Security

**Description:** Validate TLS endpoint, encryption at rest, IRSA annotation.

```bash
pytest tests/security/s3/ -v
```

**Expected:** All pass (2 IRSA tests may skip if EKS not configured).

### Scenario 7: Network Policies

**Description:** Validate default-deny and explicit allow rules.

```bash
pytest tests/security/network/ -v
```

**Expected:** Pass or skip (skips when network policy templates not rendered for given preset).

---

## Red Flags

| # | Red Flag | Severity |
|---|----------|----------|
| 1 | Any test FAILED | 🔴 HIGH |
| 2 | `test_no_secret_keys_in_templates` fails | 🔴 HIGH |
| 3 | `test_serviceaccount_created` fails | 🔴 HIGH |
| 4 | TODO/FIXME in tests/security/ | 🟡 MEDIUM |
| 5 | Files in tests/security/ > 200 LOC | 🟡 MEDIUM |

---

## Code Sanity Checks

```bash
# File sizes
wc -l tests/security/*.py tests/security/**/*.py | awk '$1 > 200 {print "OVER 200:", $0}'

# No bare except
grep -rn "except:" tests/security/ || true

# Coverage
pytest tests/security/ --cov=tests/security --cov-report=term-missing -q
```

---

## Sign-off

- [ ] Quick smoke test passed
- [ ] All 7 scenarios run (pass or intentional skip)
- [ ] No red flags
- [ ] All files in tests/security/ < 200 LOC (after blocker fix)

---

**Human tester:** Complete this UAT before approving F14 deployment.
