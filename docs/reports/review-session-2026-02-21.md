# Code Review: Session 2026-02-21

**Reviewer:** Claude Opus 4.6
**Date:** 2026-02-21
**Scope:** Data Engineering, DevOps, Python aspects
**Verdict:** ⚠️ CHANGES REQUESTED

---

## Metrics Summary

| Check | Target | Actual | Status |
|-------|--------|--------|--------|
| Goal Achievement | 100% | 90% | ⚠️ |
| Test Coverage | ≥80% | N/A (Helm) | - |
| Security | No issues | 1 found | 🔴 |
| Configuration | Idempotent | Not idempotent | 🔴 |
| Documentation | Complete | Partial | ⚠️ |

---

## Critical Issues

### 1. 🔴 CRITICAL: Non-idempotent lifecycle hooks

**File:** `charts/spark-3.5/templates/jupyter.yaml:40-59`

```yaml
lifecycle:
  postStart:
    exec:
      command:
        - /bin/bash
        - -c
        - |
          pip install --quiet 'pandas>=2.2,<3' 'pyarrow>=15' 'numpy<2' || true
```

**Problem:**
- `pip install` runs on every pod restart
- Network dependency at runtime (not reproducible)
- No version pinning (pandas>=2.2 could install 3.0.0)
- `|| true` silently ignores failures

**DevOps Impact:**
- Pod startup time increased by 30-60s
- Different versions on different pods
- Supply chain attack vector
- Offline clusters will fail

**Fix Required:**
```yaml
# Option A: Pre-baked Docker image (RECOMMENDED)
image: "custom-jupyter:spark-3.5-with-deps"

# Option B: Init container with cached packages
initContainers:
  - name: install-deps
    image: python:3.11-slim
    command: ['pip', 'install', '--target=/deps', 'pandas==2.2.0', 'pyarrow==15.0.0']
    volumeMounts:
      - name: deps
        mountPath: /deps
```

---

### 2. 🔴 HIGH: Hardcoded database credentials

**File:** `charts/spark-base/templates/core/postgresql-configmap.yaml:43`

```yaml
CREATE USER hive WITH PASSWORD 'hive123';
```

**Problem:**
- Password in plaintext in ConfigMap (not Secret!)
- Same password for all environments
- Not rotated automatically

**Security Impact:**
- CVE-style vulnerability
- Fails security audits
- Compliance violation (PCI-DSS, SOC2)

**Fix Required:**
```yaml
# Use existing secret
{{- if .Values.core.postgresql.existingSecret }}
- name: HIVE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.core.postgresql.existingSecret }}
      key: hive-password
{{- end }}
```

---

### 3. 🔴 HIGH: PostgreSQL authentication downgrade

**File:** `charts/spark-base/templates/core/postgresql-configmap.yaml:21`

```yaml
ALTER SYSTEM SET password_encryption = 'md5';
```

**Problem:**
- Downgrades security from SCRAM-SHA-256 to MD5
- Affects ALL databases on the PostgreSQL instance
- MD5 is considered cryptographically weak

**Security Impact:**
- Password hash vulnerable to rainbow tables
- Fails security compliance

**Fix Required:**
```yaml
# Option A: Upgrade Hive JDBC driver (supports SCRAM)
# Option B: Use separate PostgreSQL instance for Hive
# Option C: Use pg_hba.conf for specific user only
```

---

## High Priority Issues

### 4. ⚠️ HIGH: Dependency version conflicts

**File:** `charts/spark-3.5/templates/jupyter.yaml:54`

```yaml
pip install --quiet 'numpy<2'
```

**Problem:**
- Forces numpy<2 which conflicts with:
  - numba 0.57.1 (requires numpy>=1.21,<1.25)
  - scikit-learn 1.3.1 (requires numpy<2.0,>=1.17.3)
  - scipy 1.11.3 (requires numpy<1.28.0)

**Data Engineering Impact:**
- ML models may fail to train
- Import errors at runtime
- Silent degradation (warnings ignored)

**Fix Required:**
- Test matrix for numpy compatibility
- Pin exact versions in requirements.txt
- Consider separate virtual environment

---

### 5. ⚠️ HIGH: No resource limits for pip install

**File:** `charts/spark-3.5/templates/spark-connect.yaml:114-118`

```yaml
lifecycle:
  postStart:
    exec:
      command:
        - /bin/bash
        - -c
        - pip install --quiet prometheus_client || true
```

**Problem:**
- No memory/CPU limits on lifecycle hook
- pip can consume unbounded resources
- `|| true` hides OOM kills

**DevOps Impact:**
- Node instability
- OOM kills affecting other pods
- Difficult to debug

---

## Medium Priority Issues

### 6. ⚠️ MEDIUM: Selector mismatch pattern

**File:** `charts/spark-4.1/templates/history-server.yaml`

Fixed in commit 47022c1, but pattern exists elsewhere.

**Check required:**
```bash
grep -r "selector:" charts/*/templates/*.yaml | while read line; do
  # Verify template.labels match selector.matchLabels
done
```

---

### 7. ⚠️ MEDIUM: PSS not enabled by default

**File:** `charts/spark-4.1/values.yaml:162`

```yaml
spark-base:
  security:
    podSecurityStandards: true  # Was false before fix
```

**Problem:**
- Inconsistency: parent has `true`, subchart had `false`
- Security regression if values not carefully merged

**Fix Required:**
- Single source of truth for security settings
- Document security inheritance

---

## Data Engineering Issues

### 8. ⚠️ MEDIUM: No data validation in examples

**File:** `docs/demos/spark-35-full-stack-demo.md`

Demo shows:
```python
df = spark.range(10000)
```

**Missing:**
- Schema validation
- Data quality checks
- Null handling examples
- Type coercion documentation

---

### 9. ⚠️ MEDIUM: No partitioning strategy

**Demo writes:**
```python
df.write.mode('overwrite').parquet('s3a://spark-logs/demo/test.parquet')
```

**Problems:**
- Single file output (no parallelism)
- No partitioning by date/category
- No compression specified

**Best Practice:**
```python
df.write.mode('overwrite') \
    .partitionBy('category') \
    .option('compression', 'snappy') \
    .parquet('s3a://spark-logs/demo/test.parquet')
```

---

## Python Issues

### 10. ⚠️ MEDIUM: No error handling in demo code

```python
spark = SparkSession.builder.remote('sc://...').getOrCreate()
df = spark.range(100)
```

**Missing:**
- Try/except for connection failures
- Timeout handling
- Graceful shutdown

---

### 11. ⚠️ LOW: print() instead of logging

All demo code uses `print()` instead of proper logging:
- No log levels
- No structured logging
- No correlation IDs

---

## Test Issues

### 12. ⚠️ MEDIUM: Fixture scope mismatch

**Files:** `tests/observability/*.py`

17 tests skipped due to:
```
ScopeMismatch: You tried to access the function scoped fixture kube_namespace
with a class scoped request object
```

**Fix Required:**
```python
# Change fixture scope to match test class
@pytest.fixture(scope="class")
def kube_namespace():
    ...
```

---

## Summary Table

| # | Severity | Issue | File | Fix Complexity |
|---|----------|-------|------|----------------|
| 1 | 🔴 CRITICAL | Non-idempotent pip install | jupyter.yaml | High (Docker rebuild) |
| 2 | 🔴 HIGH | Hardcoded password | postgresql-configmap.yaml | Medium |
| 3 | 🔴 HIGH | MD5 auth downgrade | postgresql-configmap.yaml | High (driver update) |
| 4 | ⚠️ HIGH | numpy version conflicts | jupyter.yaml | Medium |
| 5 | ⚠️ HIGH | No resource limits | spark-connect.yaml | Low |
| 6 | ⚠️ MEDIUM | Selector mismatch pattern | Multiple | Low |
| 7 | ⚠️ MEDIUM | PSS inconsistency | values.yaml | Low |
| 8 | ⚠️ MEDIUM | No data validation | demos | Low |
| 9 | ⚠️ MEDIUM | No partitioning | demos | Low |
| 10 | ⚠️ MEDIUM | No error handling | demos | Low |
| 11 | ⚠️ LOW | print vs logging | demos | Low |
| 12 | ⚠️ MEDIUM | Fixture scope | tests | Low |

---

## Verdict

**⚠️ CHANGES REQUESTED**

### Blocking Issues (must fix before production):

1. **Issue #2:** Hardcoded database credentials - security vulnerability
2. **Issue #3:** MD5 authentication downgrade - compliance failure

### Recommended Actions:

1. **Short-term (this sprint):**
   - Move hardcoded passwords to Kubernetes Secrets
   - Document the MD5 auth tradeoff in security docs

2. **Medium-term (next sprint):**
   - Build custom Docker images with pre-installed dependencies
   - Add integration tests for auth flow

3. **Long-term (backlog):**
   - Upgrade to SCRAM-SHA-256 compatible JDBC driver
   - Add data quality framework to examples

---

## Files Reviewed

| File | Lines Changed | Issues Found |
|------|---------------|--------------|
| charts/spark-3.5/templates/jupyter.yaml | +16 | 3 |
| charts/spark-3.5/templates/spark-connect.yaml | +7 | 1 |
| charts/spark-base/templates/core/postgresql-configmap.yaml | 0 | 2 |
| charts/spark-4.1/templates/history-server.yaml | +1 | 0 |
| charts/spark-4.1/values.yaml | +1 | 1 |
| docs/demos/spark-35-full-stack-demo.md | +209 | 4 |

---

## Next Steps

1. Create WS for blocking issues
2. Run `/build WS-XXX-XX` for each
3. Re-run `/review` after fixes
