# Spark Connect CrashLoop - RBAC ConfigMaps Permission

**Related Issues:** ISSUE-032, ISSUE-033

## Symptoms

```
test-spark-spark-41-connect-xxxxx-xxxxx   0/1     CrashLoopBackOff   5 (2m ago)
```

Connect pod постоянно перезапускается (CrashLoopBackOff).

## Error from Logs

```bash
kubectl logs -n <namespace> <connect-pod> --previous
```

```
configmaps is forbidden: User "system:serviceaccount:<namespace>:spark-41"
cannot create resource "configmaps" in API group "" in the namespace "<namespace>".

at org.apache.spark.scheduler.cluster.k8s.KubernetesClusterSchedulerBackend.setUpExecutorConfigMap
```

## Diagnosis

```bash
# 1. Проверить статус пода
kubectl get pods -n <namespace> -l app=spark-connect

# 2. Проверить логи (предыдущей попытки)
kubectl logs -n <namespace> <connect-pod> --previous | grep -i "configmaps\|forbidden"

# 3. Проверить RBAC права
kubectl auth can-i create configmaps -n <namespace> \
  --as=system:serviceaccount:<namespace>:spark-41

# 4. Проверить текущий Role/ClusterRole
kubectl get role -n <namespace> spark-41 -o yaml
```

Если `can-i` возвращает `no` - проблема в RBAC.

## Root Cause

Spark Connect на K8s backend mode создаёт ConfigMap для конфигурации executor'ов.
ServiceAccount должен иметь право `create` на `configmaps`.

Текущий RBAC в chart имел только `get` и `list`, но не `create`.

## Solution

### Исправленный RBAC (charts/spark-4.1/templates/rbac.yaml)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: spark-41
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create", "get", "list", "watch", "delete"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["create", "get", "list", "delete"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["create", "get", "list", "watch"]  # Добавлены create и watch
```

### Применение исправления

```bash
# Если chart уже установлен
kubectl patch role spark-41 -n <namespace> --type=json \
  -p='[
    {"op": "add", "path": "/rules/2/verbs/-1", "value": "create"},
    {"op": "add", "path": "/rules/2/verbs/-1", "value": "watch"}
  ]'

# Или переустановить chart
helm upgrade spark charts/spark-4.1 -n <namespace> --reuse-values
```

## Verification

```bash
# Проверить права
kubectl auth can-i create configmaps -n <namespace> \
  --as=system:serviceaccount:<namespace>:spark-41
# Должно вернуть: yes

# Подождать пока Connect станет ready
kubectl wait --for=condition=ready pod -n <namespace> -l app=spark-connect --timeout=180s

# Проверить что Connect запустился
kubectl logs -n <namespace> -l app=spark-connect --tail=20 | grep -i "started"
```

## Related

- ISSUE-032: Spark 4.1 Connect crashloop (symptom)
- ISSUE-033: RBAC configmaps create permission (root cause)
- check-rbac.sh: Скрипт для проверки RBAC
