# Spark Properties File Format

**Related Issue:** ISSUE-019

## Symptoms

```
Error parsing Spark properties
Invalid property format
Expected key=value but got: "spark.property=value"
```

## Diagnosis

```bash
# Проверить формат properties файла
kubectl get cm -n <namespace> spark-properties -o yaml

# Проверить ConfigMap формат
kubectl describe cm -n <namespace> <configmap-name>
```

## Solution

### Правильный формат Spark properties

**Правильно:**
```properties
spark.executor.memory=2g
spark.executor.cores=2
spark.executor.instances=10
spark.sql.shuffle.partitions=200
```

**Неправильно:**
```properties
# ❌ Нет кавычек
"spark.executor.memory"="2g"

# ❌ Нет пробелов вокруг =
spark.executor.memory= 2g

# ❌ Нет комментариев внутри строки
spark.executor.memory=2g # 2GB memory
```

### Spark 4.1: sparkConf в values.yaml

**Правильно:**
```yaml
connect:
  sparkConf:
    spark.executor.memory: "2g"
    spark.executor.cores: "2"
    spark.sql.shuffle.partitions: "200"
```

**Неправильно:**
```yaml
connect:
  sparkConf:
    # ❌ Не используйте строковые ключи с точками
    "spark.executor.memory": "2g"
```

### Создание ConfigMap с properties

```bash
# Правильный способ
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: spark-properties
  namespace: <namespace>
data:
  spark-defaults.conf: |
    spark.executor.memory=2g
    spark.executor.cores=2
    spark.executor.instances=10
    spark.sql.shuffle.partitions=200
    spark.dynamicAllocation.enabled=true
    spark.dynamicAllocation.minExecutors=1
    spark.dynamicAllocation.maxExecutors=10
EOF
```

### Подключение ConfigMap к Spark

**Spark 4.1:**
```yaml
connect:
  sparkConfMap:
    name: spark-properties
    key: spark-defaults.conf
```

**Spark 3.5:**
```yaml
sparkConnect:
  sparkConfMap:
    name: spark-properties
    key: spark-defaults.conf
```

## Verification

```bash
# Проверить что свойства применились
kubectl exec -n <namespace> deploy/spark-connect -- \
  cat /opt/spark/conf/spark-defaults.conf

# Из Spark UI
kubectl port-forward -n <namespace> <spark-pod> 4040:4040
# Открыть: http://localhost:4040 -> Environment
```

## References

- ISSUE-019: Properties format
- Spark Configuration: https://spark.apache.org/docs/latest/configuration.html
- ISSUE-018: Properties file unsupported (4.1)
