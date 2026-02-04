# Phase 8: Advanced Security

> **Status:** Backlog
> **Priority:** P1 - Security hardening
> **Feature:** F14
> **Estimated Workstreams:** 7
> **Estimated LOC:** ~4200

## Goal

Создать 48 security сценариев для проверки PSS, SCC, Network Policies, RBAC, Secret Management, Container Security, S3 Security. Валидировать production-ready security posture соотвествие стандартам.

## Current State

**Не реализовано** — Phase 8 только начинается. Design Decisions уже approved.

## Updated Workstreams

| WS | Task | Scenarios | Scope | Dependencies | Status |
|----|------|-----------|-------|-------------|--------|
| WS-014-01 | PSS tests | 8 | MEDIUM (~600 LOC) | Phase 0, Phase 1 | backlog |
| WS-014-02 | SCC tests | 12 | MEDIUM (~900 LOC) | Phase 0, Phase 1 | backlog |
| WS-014-03 | Network policies | 6 | MEDIUM (~500 LOC) | Phase 0, Phase 1 | backlog |
| WS-014-04 | RBAC tests | 6 | MEDIUM (~500 LOC) | Phase 0, Phase 1 | backlog |
| WS-014-05 | Secret management | 6 | MEDIUM (~500 LOC) | Phase 0, Phase 1 | backlog |
| WS-014-06 | Container security | 8 | MEDIUM (~700 LOC) | Phase 0, Phase 1 | backlog |
| WS-014-07 | S3 security | 6 | MEDIUM (~500 LOC) | Phase 0, Phase 1 | backlog |

**Total Scenarios:** 48

## Design Decisions (Approved)

### 1. Validation Method

**PSS compliance:**
- `helm template + kubeconform` для быстрой проверки
- `kubectl apply --dry-run` для финальной валидации

**SCC compliance:**
- Мокать `oc` команды (не нужен реальный OpenShift кластер)
- Проверять YAML совместимость с SCC constraints

### 2. Secret Management

- Только K8s native секреты в Phase 8
- External Secrets, Vault, Sealed Secrets — в будущих phases

### 3. Network Policies

- Тестировать через `helm template + yaml parsing`
- Проверять default-deny + explicit allow rules

### 4. S3 Security

- **TLS in-flight**: проверять HTTPS в endpoint
- **Encryption at rest**: проверять fs.s3a.server-side-encryption-algorithm
- **IRSA**: проверять eks.amazonaws.com/role-arn annotation

### 5. Test Matrix

**PSS tests (8 scenarios):**
- restricted, baseline profiles × Spark 3.5, 4.1 × presets

**SCC tests (12 scenarios):**
- anyuid, nonroot, restricted-v2 × Spark versions × components

**Network policies (6 scenarios):**
- Default-deny ingress/egress
- Explicit allow for Spark components
- MinIO/PostgreSQL access rules

**RBAC tests (6 scenarios):**
- ServiceAccount permissions
- Role/ClusterRole least privilege
- No wildcard permissions

**Secret management (6 scenarios):**
- K8s Secret creation/mounting
- Environment variable injection
- Volume mount secrets

**Container security (8 scenarios):**
- Non-root user validation
- No privilege escalation
- Read-only root filesystem
- Drop capabilities

**S3 security (6 scenarios):**
- TLS endpoint validation
- Server-side encryption
- IRSA annotation for EKS

## Dependencies

- **Phase 0 (F06):** Helm charts deployed
- **Phase 1 (F07):** Security templates applied

## Success Criteria

1. ⏳ 48 security сценариев созданы
2. ⏳ PSS restricted profile подтверждён (kubeconform validation)
3. ⏳ OpenShift SCC совместимость подтверждена (mocked `oc` commands)
4. ⏳ Network политики работают (default-deny + explicit allow)
5. ⏳ RBAC настроен корректно (least privilege, no wildcards)
6. ⏳ Secret management проверен (K8s native only)
7. ⏳ Container security проверен (non-root, no privilege escalation)
8. ⏳ S3 security проверен (TLS in-flight, encryption at rest)

## File Structure

```
tests/security/
├── conftest.py              # Security test fixtures
├── pytest.ini                # Pytest configuration
├── pss/
│   ├── test_pss_restricted_35.py
│   ├── test_pss_restricted_41.py
│   ├── test_pss_baseline_35.py
│   └── test_pss_baseline_41.py
├── scc/
│   ├── test_scc_anyuid.py
│   ├── test_scc_nonroot.py
│   ├── test_scc_restricted_v2.py
│   └── test_scc_presets.py
├── network/
│   ├── test_network_default_deny.py
│   ├── test_network_explicit_allow.py
│   └── test_network_component_rules.py
├── rbac/
│   ├── test_rbac_service_accounts.py
│   ├── test_rbac_roles.py
│   └── test_rbac_cluster_roles.py
├── secrets/
│   ├── test_secret_creation.py
│   ├── test_secret_env_vars.py
│   └── test_secret_volume_mounts.py
├── container/
│   ├── test_container_non_root.py
│   ├── test_container_no_privilege.py
│   ├── test_container_readonly_fs.py
│   └── test_container_capabilities.py
└── s3/
    ├── test_s3_tls_endpoint.py
    ├── test_s3_encryption_at_rest.py
    └── test_s3_irsa_annotation.py
```

## Integration with Other Phases

- **Phase 0 (F06):** Charts provide security base
- **Phase 1 (F07):** Security templates validated
- **Phase 7 (F13):** Load tests verify security under load

## Beads Integration

```bash
# Feature
spark_k8s-xxx - F14: Phase 8 - Advanced Security (P1)

# Workstreams
spark_k8s-xxx - WS-014-01: PSS tests (P1)
spark_k8s-xxx - WS-014-02: SCC tests (P1)
spark_k8s-xxx - WS-014-03: Network policies (P1)
spark_k8s-xxx - WS-014-04: RBAC tests (P1)
spark_k8s-xxx - WS-014-05: Secret management (P1)
spark_k8s-xxx - WS-014-06: Container security (P1)
spark_k8s-xxx - WS-014-07: S3 security (P1)

# Dependencies
All WS depend on F06, F07
```

## References

- [PRODUCT_VISION.md](../../PRODUCT_VISION.md)
- [workstreams/INDEX.md](../workstreams/INDEX.md)
- [phase-01-security.md](./phase-01-security.md)
- [phase-07-load.md](./phase-07-load.md)
