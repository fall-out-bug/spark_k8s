# Phase 8: Advanced Security

> **Status:** Ready
> **Priority:** P1 - Security hardening
> **Estimated Workstreams:** 7
> **Estimated LOC:** ~4200

## Goal

Создать 48 security сценариев для проверки PSS, SCC, Network Policies, RBAC, Secret Management, Container Security, S3 Security.

## Design Decisions (Approved)

1. **Validation Method:**
   - PSS compliance: `helm template + kubeconform` для быстрой проверки
   - PSS compliance: `kubectl apply --dry-run` для финальной валидации
   - SCC compliance: мокать `oc` команды (не нужен реальный OpenShift кластер)

2. **Secret Management:**
   - Только K8s native секреты в Phase 8
   - External Secrets, Vault, Sealed Secrets — в будущих phases

3. **Network Policies:**
   - Тестировать через `helm template + yaml parsing`
   - Проверять default-deny + explicit allow rules

4. **S3 Security:**
   - TLS in-flight: проверять HTTPS в endpoint
   - Encryption at rest: проверять fs.s3a.server-side-encryption-algorithm
   - IRSA: проверять eks.amazonaws.com/role-arn annotation

## Workstreams

| WS | Task | Scenarios | Scope | Dependencies |
|----|------|-----------|-------|-------------|
| WS-008-01 | PSS tests | 8 | MEDIUM (~600 LOC) | Phase 0, Phase 1 |
| WS-008-02 | SCC tests | 12 | MEDIUM (~900 LOC) | Phase 0, Phase 1 |
| WS-008-03 | Network policies | 6 | MEDIUM (~500 LOC) | Phase 0, Phase 1 |
| WS-008-04 | RBAC tests | 6 | MEDIUM (~500 LOC) | Phase 0, Phase 1 |
| WS-008-05 | Secret management | 6 | MEDIUM (~500 LOC) | Phase 0, Phase 1 |
| WS-008-06 | Container security | 8 | MEDIUM (~700 LOC) | Phase 0, Phase 1 |
| WS-008-07 | S3 security | 6 | MEDIUM (~500 LOC) | Phase 0, Phase 1 |

**Total Scenarios:** 48 (was 54, simplified after Secret Management reduction)

## Dependencies

- Phase 0 (Helm charts)
- Phase 1 (Critical security)

## Success Criteria

1. 48 security сценариев созданы
2. PSS restricted profile подтверждён (kubeconform validation)
3. OpenShift SCC совместимость подтверждена (mocked `oc` commands)
4. Network policies работают (default-deny + explicit allow)
5. RBAC настроен корректно (least privilege, no wildcards)
6. Secret management проверен (K8s native only)
7. Container security проверен (non-root, no privilege escalation)
8. S3 security проверен (TLS in-flight, encryption at rest)
