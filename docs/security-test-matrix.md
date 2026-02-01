# Security Test Matrix

Полная матрица security тестов для проверки соответствия OpenShift security требованиям, Pod Security Standards и SCC.

**Дата создания:** 2026-02-01
**Статус:** ⚠️ Требуется реализации

---

## Категории тестов

### 1. Pod Security Standards Tests (8 сценариев)

Проверка соответствия Kubernetes Pod Security Standards.

| Сценарий | PSS Profile | Версия | Статус |
|----------|-------------|--------|--------|
| `pss-restricted-35.sh` | restricted | 3.5.x | ❌ |
| `pss-restricted-41.sh` | restricted | 4.1.x | ❌ |
| `pss-baseline-35.sh` | baseline | 3.5.x | ❌ |
| `pss-baseline-41.sh` | baseline | 4.1.x | ❌ |
| `pss-privileged-35.sh` | privileged | 3.5.x | ❌ |
| `pss-privileged-41.sh` | privileged | 4.1.x | ❌ |
| `pss-custom-uid-35.sh` | restricted + custom UID | 3.5.x | ❌ |
| `pss-custom-uid-41.sh` | restricted + custom UID | 4.1.x | ❌ |

**Проверки PSS restricted:**
- ✅ `runAsNonRoot: true`
- ✅ `runAsUser` / `runAsGroup` (numeric, non-root)
- ✅ `fsGroup` (numeric)
- ✅ `seccompProfile.type: RuntimeDefault`
- ✅ `allowPrivilegeEscalation: false`
- ✅ `capabilities.drop: ALL`
- ✅ Нет `privileged: true`
- ✅ Нет hostPath volumes
- ✅ Нет hostNetwork

### 2. OpenShift SCC Tests (12 сценариев)

Проверка совместимости с OpenShift Security Context Constraints.

| Сценарий | SCC | Версия | Статус |
|----------|-----|--------|--------|
| `scc-restricted-35.sh` | restricted | 3.5.x | ❌ |
| `scc-restricted-41.sh` | restricted | 4.1.x | ❌ |
| `scc-anyuid-35.sh` | anyuid | 3.5.x | ❌ |
| `scc-anyuid-41.sh` | anyuid | 4.1.x | ❌ |
| `scc-nonroot-35.sh` | nonroot | 3.5.x | ❌ |
| `scc-nonroot-41.sh` | nonroot | 4.1.x | ❌ |
| `scc-hostmount-35.sh` | hostmount | 3.5.x | ❌ |
| `scc-hostmount-41.sh` | hostmount | 4.1.x | ❌ |
| `scc-hostnetwork-35.sh` | hostnetwork | 3.5.x | ❌ |
| `scc-hostnetwork-41.sh` | hostnetwork | 4.1.x | ❌ |
| `scc-uid-range-35.sh` | custom UID range | 3.5.x | ❌ |
| `scc-uid-range-41.sh` | custom UID range | 4.1.x | ❌ |

**Проверки SCC:**
- ✅ Pod запускается с correct UID/GID
- ✅ UID/GID в разрешённом range для SCC
- ✅ SELinux context корректен
- ✅ FsGroup правильно применяется
- ✅ Нет конфликтов с SCC policies

### 3. Network Policies Tests (6 сценариев)

Проверка сетевой изоляции и Network Policies.

| Сценарий | Policy | Версия | Статус |
|----------|--------|--------|--------|
| `network-default-35.sh` | Default deny all | 3.5.x | ❌ |
| `network-default-41.sh` | Default deny all | 4.1.x | ❌ |
| `network-spark-35.sh` | Spark communication | 3.5.x | ❌ |
| `network-spark-41.sh` | Spark communication | 4.1.x | ❌ |
| `network-external-35.sh` | External S3 access | 3.5.x | ❌ |
| `network-external-41.sh` | External S3 access | 4.1.x | ❌ |

**Проверки Network Policies:**
- ✅ Block cross-namespace traffic
- ✅ Allow Spark driver-executor communication
- ✅ Allow S3/MinIO access
- ✅ Block unauthorized ingress
- ✅ Block unauthorized egress

### 4. RBAC Tests (6 сценариев)

Проверка Role-Based Access Control.

| Сценарий | Role | Версия | Статус |
|----------|------|--------|--------|
| `rbac-read-only-35.sh` | Minimal permissions | 3.5.x | ❌ |
| `rbac-read-only-41.sh` | Minimal permissions | 4.1.x | ❌ |
| `rbac-full-35.sh` | Full permissions | 3.5.x | ❌ |
| `rbac-full-41.sh` | Full permissions | 4.1.x | ❌ |
| `rbac-custom-35.sh` | Custom role | 3.5.x | ❌ |
| `rbac-custom-41.sh` | Custom role | 4.1.x | ❌ |

**Проверки RBAC:**
- ✅ ServiceAccount создан
- ✅ Role/RoleBinding настроены
- ✅ Minimize permissions (principle of least privilege)
- ✅ Pod может создавать Kubernetes resources
- ✅ Pod может читать ConfigMaps/Secrets

### 5. Secret Management Tests (8 сценариев)

Проверка управления секретами.

| Сценарий | Method | Версия | Статус |
|----------|--------|--------|--------|
| `secret-k8s-native-35.sh` | K8s Secrets | 3.5.x | ❌ |
| `secret-k8s-native-41.sh` | K8s Secrets | 4.1.x | ❌ |
| `secret-external-35.sh` | External Secrets Operator | 3.5.x | ❌ |
| `secret-external-41.sh` | External Secrets Operator | 4.1.x | ❌ |
| `secret-sealed-35.sh` | Sealed Secrets | 3.5.x | ❌ |
| `secret-sealed-41.sh` | Sealed Secrets | 4.1.x | ❌ |
| `secret-vault-35.sh` | Vault Integration | 3.5.x | ❌ |
| `secret-vault-41.sh` | Vault Integration | 4.1.x | ❌ |

**Проверки Secrets:**
- ✅ S3 credentials не в plain text
- ✅ PostgreSQL credentials не в plain text
- ✅ Secrets монтируются как volumes
- ✅ Secrets доступны только нужным pods
- ✅ Secret rotation работает

### 6. Container Security Tests (8 сценариев)

Проверка безопасности контейнеров.

| Сценарий | Check | Версия | Статус |
|----------|-------|--------|--------|
| `container-readonly-35.sh` | Read-only root filesystem | 3.5.x | ❌ |
| `container-readonly-41.sh` | Read-only root filesystem | 4.1.x | ❌ |
| `container-capabilities-35.sh` | Drop all capabilities | 3.5.x | ❌ |
| `container-capabilities-41.sh` | Drop all capabilities | 4.1.x | ❌ |
| `container-seccomp-35.sh` | Seccomp profile | 3.5.x | ❌ |
| `container-seccomp-41.sh` | Seccomp profile | 4.1.x | ❌ |
| `container-vulnerability-35.sh` | Image vulnerability scan | 3.5.x | ❌ |
| `container-vulnerability-41.sh` | Image vulnerability scan | 4.1.x | ❌ |

**Проверки Container Security:**
- ✅ `readOnlyRootFilesystem: true`
- ✅ `allowPrivilegeEscalation: false`
- ✅ `capabilities.drop: ALL`
- ✅ `seccompProfile.type: RuntimeDefault`
- ✅ Нет известных vulnerabilities (CVE)
- ✅ Minimal attack surface

### 7. S3 Security Tests (6 сценариев)

Проверка безопасной работы с S3.

| Сценарий | Check | Версия | Статус |
|----------|-------|--------|--------|
| `s3-encryption-35.sh` | In-flight & at-rest encryption | 3.5.x | ❌ |
| `s3-encryption-41.sh` | In-flight & at-rest encryption | 4.1.x | ❌ |
| `s3-iam-35.sh` | IAM role instead of keys | 3.5.x | ❌ |
| `s3-iam-41.sh` | IAM role instead of keys | 4.1.x | ❌ |
| `s3-presigned-35.sh` | Presigned URLs | 3.5.x | ❌ |
| `s3-presigned-41.sh` | Presigned URLs | 4.1.x | ❌ |

**Проверки S3 Security:**
- ✅ SSL/TLS для S3 connections
- ✅ S3 bucket encryption enabled
- ✅ IAM roles вместо access keys
- ✅ Bucket policies настроены
- ✅ Event logs encrypted at rest

---

## Сводная таблица

| Категория | Сценариев | Создано | Progress |
|-----------|-----------|---------|----------|
| PSS Tests | 8 | 0 | 0% |
| SCC Tests | 12 | 0 | 0% |
| Network Policies | 6 | 0 | 0% |
| RBAC Tests | 6 | 0 | 0% |
| Secret Management | 8 | 0 | 0% |
| Container Security | 8 | 0 | 0% |
| S3 Security | 6 | 0 | 0% |
| **ИТОГО** | **54** | **0** | **0%** |

---

## Структура security test сценария

```bash
#!/bin/bash
# @meta
name: "security-pss-restricted-35"
type: "security"
description: "Pod Security Standards restricted profile compliance test for Spark 3.5"
version: "3.5.x"
category: "pss"
profile: "restricted"
checks:
  - "runAsNonRoot: true"
  - "runAsUser: numeric non-root"
  - "seccompProfile: RuntimeDefault"
  - "allowPrivilegeEscalation: false"
  - "capabilities.drop: ALL"
estimated_time: "5 min"
# @endmeta
```

---

## Обязательные проверки для всех security тестов

Все security тесты **ДОЛЖНЫ** включать:

1. **S3 для Event Log** - все логи выполнения Spark jobs сохраняются в S3
2. **History Server** - развёрнут для чтения логов из S3
3. **Security enabled** - проверяемые security настройки включены

```yaml
# Обязательные значения для всех security тестов
global:
  s3:
    enabled: true
    endpoint: "http://minio:9000"
    accessKey: "minioadmin"
    secretKey: "minioadmin"
    pathStyleAccess: true
    sslEnabled: false

security:
  podSecurityStandards: true
  createNamespace: true

connect:
  eventLog:
    enabled: true
    dir: "s3a://spark-logs/{version}/security/{scenario}/events"

historyServer:
  enabled: true
  provider: "s3"
  s3:
    endpoint: "http://minio:9000"
```

---

## OpenShift Deployment Presets

### Preset files

| Preset | Путь | Статус |
|--------|------|--------|
| OpenShift PSS | `charts/spark-3.5/presets/openshift-pss.yaml` | ❌ |
| OpenShift SCC | `charts/spark-3.5/presets/openshift-scc.yaml` | ❌ |
| OpenShift Full | `charts/spark-3.5/presets/openshift-full.yaml` | ❌ |
| OpenShift PSS | `charts/spark-4.1/presets/openshift-pss.yaml` | ❌ |
| OpenShift SCC | `charts/spark-4.1/presets/openshift-scc.yaml` | ❌ |
| OpenShift Full | `charts/spark-4.1/presets/openshift-full.yaml` | ❌ |

### OpenShift Full Preset Example

```yaml
# charts/spark-4.1/presets/openshift-full.yaml
# OpenShift deployment preset with full security hardening

global:
  s3:
    enabled: true
    endpoint: "https://s3.openshift.example.com"
    sslEnabled: true
  postgresql:
    host: "postgresql-openshift.example.com"
    port: 5432

# RBAC for OpenShift
rbac:
  create: true
  serviceAccountName: "spark-41"

# OpenShift Security
security:
  podSecurityStandards: true
  createNamespace: true
  # OpenShift UID range (adjust for your cluster)
  # Check with: oc describe namespace <project>
  runAsUser: 1000000000
  runAsGroup: 1000000000
  fsGroup: 1000000000
  readOnlyRootFilesystem: true
  networkPolicies:
    enabled: true

# Spark Connect
connect:
  enabled: true
  eventLog:
    enabled: true
    dir: "s3a://spark-logs/4.1/events"

# History Server
historyServer:
  enabled: true
  provider: "s3"
  s3:
    endpoint: "https://s3.openshift.example.com"
    sslEnabled: true

# Monitoring
monitoring:
  serviceMonitor:
    enabled: true
  podMonitor:
    enabled: true
```

---

## Security Validation Script

**Файл:** `scripts/tests/security/validate-security.sh`

```bash
#!/bin/bash
# Validate OpenShift security compliance

check_pss_compliance() {
    local pod="$1"
    local namespace="$2"

    echo "Checking PSS compliance for $pod in $namespace..."

    # Check runAsNonRoot
    local runAsNonRoot=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.securityContext.runAsNonRoot}')
    if [[ "$runAsNonRoot" != "true" ]]; then
        echo "❌ runAsNonRoot is not true"
        return 1
    fi

    # Check seccompProfile
    local seccomp=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.securityContext.seccompProfile.type}')
    if [[ "$seccomp" != "RuntimeDefault" ]]; then
        echo "❌ seccompProfile is not RuntimeDefault"
        return 1
    fi

    echo "✅ PSS compliance OK"
}

check_scc_compliance() {
    local pod="$1"
    local namespace="$2"

    echo "Checking SCC compliance for $pod in $namespace..."

    # Check if pod is running
    local phase=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.status.phase}')
    if [[ "$phase" != "Running" ]]; then
        echo "❌ Pod is not running (phase: $phase)"
        return 1
    fi

    echo "✅ SCC compliance OK"
}

main() {
    local namespace="${1:-spark-41}"
    local release="${2:-spark}"

    echo "Validating security for release $release in namespace $namespace..."

    # Get all pods
    local pods=$(kubectl get pods -n "$namespace" -l app.kubernetes.io/instance="$release" -o jsonpath='{.items[*].metadata.name}')

    for pod in $pods; do
        check_pss_compliance "$pod" "$namespace"
        check_scc_compliance "$pod" "$namespace"
    done
}

main "$@"
```

---

## План работ

### Phase 1: Critical Security Tests (День 1)

**Priority:** P0 - Critical for OpenShift deployment

- [ ] `pss-restricted-35.sh` - PSS restricted для Spark 3.5
- [ ] `pss-restricted-41.sh` - PSS restricted для Spark 4.1
- [ ] `scc-restricted-35.sh` - SCC restricted для Spark 3.5
- [ ] `scc-restricted-41.sh` - SCC restricted для Spark 4.1

### Phase 2: Chart Templates (День 1)

- [ ] Создать `templates/namespace.yaml` в spark-3.5
- [ ] Создать `templates/namespace.yaml` в spark-4.1
- [ ] Создать `presets/openshift-pss.yaml` для обеих версий
- [ ] Создать `presets/openshift-scc.yaml` для обеих версий

### Phase 3: Additional Security Tests (День 2)

- [ ] PSS baseline/privileged tests (4)
- [ ] SCC anyuid/nonroot tests (4)
- [ ] Network policies tests (6)

### Phase 4: Advanced Security (День 3+)

- [ ] RBAC tests (6)
- [ ] Secret management tests (8)
- [ ] Container security tests (8)
- [ ] S3 security tests (6)

---

## Результаты security тестов

После выполнения security тесты создают отчеты в `tests/security/results/`:

```
tests/security/results/
├── pss-restricted-35/
│   ├── validation.json       # Результаты валидации
│   ├── summary.md            # Краткое резюме
│   └── logs/                 # Логи проверки
└── ...
```

### Формат validation.json

```json
{
  "scenario": "pss-restricted-35",
  "timestamp": "2026-02-01T14:00:00Z",
  "platform": "openshift",
  "kubernetes_version": "1.28.0",
  "checks": {
    "pss_profile": "restricted",
    "runAsNonRoot": true,
    "runAsUser": 1000000000,
    "seccompProfile": "RuntimeDefault",
    "allowPrivilegeEscalation": false,
    "capabilities_drop_all": true,
    "readOnlyRootFilesystem": true
  },
  "pods_checked": 5,
  "pods_compliant": 5,
  "pods_non_compliant": 0,
  "verdict": "PASS",
  "warnings": [],
  "errors": []
}
```

---

## Last updated

2026-02-01 14:30 - Initial security test matrix creation
- Progress: 0/54 (0%)
- Next: Phase 1 - Critical Security Tests + Chart Templates
