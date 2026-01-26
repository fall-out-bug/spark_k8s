# Setup Resource Quotas for Team

**Source:** Deployment recipes

## Overview

Настроить resource quotas чтобы одна команда не могла использовать все ресурсы кластера.

## Prerequisites

- Namespace для команды создан
- Spark уже развернут

## Resource Quota Types

### 1. Compute ResourceQuota

```bash
cat <<EOF | kubectl apply -n datascience-alpha -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: spark-compute-resources
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 40Gi
    limits.cpu: "20"
    limits.memory: 80Gi
    persistentvolumeclaims: "5"
    requests.nvidia.com/gpu: "0"
EOF
```

### 2. LimitRange (значения по умолчанию)

```bash
cat <<EOF | kubectl apply -n datascience-alpha -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: spark-limits
spec:
  limits:
  - max:
      cpu: "4"
      memory: "16Gi"
    min:
      cpu: "100m"
      memory: "256Mi"
    default:
      cpu: "500m"
      memory: "2Gi"
    defaultRequest:
      cpu: "100m"
      memory: "512Mi"
    type: Container
EOF
```

### 3. Storage ResourceQuota

```bash
cat <<EOF | kubectl apply -n datascience-alpha -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: spark-storage-resources
spec:
  hard:
    requests.storage: "100Gi"
    persistentvolumeclaims: "5"
EOF
```

## Team Sizes

### Small team (1-3 engineers, dev/testing)

```yaml
# ResourceQuota
requests.cpu: "4"
requests.memory: "16Gi"
limits.cpu: "8"
limits.memory: "32Gi"
```

### Medium team (3-10 engineers, staging)

```yaml
# ResourceQuota
requests.cpu: "10"
requests.memory: "40Gi"
limits.cpu: "20"
limits.memory: "80Gi"
```

### Large team (10+ engineers, production)

```yaml
# ResourceQuota
requests.cpu: "50"
requests.memory: "200Gi"
limits.cpu: "100"
limits.memory: "400Gi"
```

## Verification

```bash
# 1. Проверить quota
kubectl describe quota -n datascience-alpha

# 2. Проверить текущее использование
kubectl describe quota -n datascience-alpha | grep Used

# 3. Тест - попробовать превысить quota
kubectl run test-quota --image=busybox -n datascience-alpha --requests=cpu=100,memory=1Ti --restart=Never
# Ожидаем: Error from server (Forbidden): exceeded quota

# 4. Проверить limit range
kubectl describe limitrange -n datascience-alpha

# 5. Запустить pod без лимитов - должны примениться default
kubectl run test-defaults --image=nginx -n datascience-alpha --restart=Never
kubectl get pod test-defaults -n datascience-alpha -o jsonpath='{.spec.containers[0].resources}'
```

## Preset с учетом quota

```yaml
# charts/spark-4.1/values-team-alpha-with-quota.yaml
connect:
  enabled: true
  replicas: 1
  resources:
    requests:
      cpu: "500m"      # В пределах quota
      memory: "2Gi"
    limits:
      cpu: "2"         # В пределах max
      memory: "4Gi"
  executor:
    cores: "1"
    coresLimit: "2"
    memory: "2Gi"
    memoryLimit: "3Gi"
  dynamicAllocation:
    enabled: true
    minExecutors: 1
    maxExecutors: 5    # 5 * 2 cores = 10 cores (в пределах limits.cpu: 20)
```

## Monitoring

```bash
# Установить metrics-server если не установлен
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Проверить использование ресурсов
kubectl top pods -n datascience-alpha
kubectl top nodes

# Агрегированная статистика по namespace
kubectl top pods -n datascience-alpha --sum=true
```

## Update Quota

```bash
# Увеличить quota для команды
kubectl patch resourcequota spark-compute-resources -n datascience-alpha -p '
{
  "spec": {
    "hard": {
      "requests.cpu": "20",
      "requests.memory": "80Gi",
      "limits.cpu": "40",
      "limits.memory": "160Gi"
    }
  }
}'

# Или через edit
kubectl edit resourcequota spark-compute-resources -n datascience-alpha
```

## References

- K8s Resource Quotas: https://kubernetes.io/docs/concepts/policy/resource-quotas/
- K8s Limit Ranges: https://kubernetes.io/docs/concepts/policy/limit-range/
- Resource Management: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
