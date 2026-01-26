# Helm Installation Label Validation Error (N/A)

**Related Issues:** ISSUE-030

## Symptoms

```
Error: INSTALLATION FAILED: 3 errors occurred:
	* PersistentVolumeClaim "minio-pvc" is invalid: metadata.labels: Invalid value: "N/A":
	  a valid label must be an empty string or consist of alphanumeric characters, '-', '_' or '.',
	  and must start and end with an alphanumeric character
	* Service "minio" is invalid: metadata.labels: Invalid value: "N/A"...
	* Deployment.apps "minio" is invalid: metadata.labels: Invalid value: "N/A"...
```

Helm chart installation fails with Kubernetes API validation error about label "N/A".

## Root Cause

Kubernetes labels не могут содержать специальные символы вроде "N/A".
Значение "N/A" появляется откуда-то в процессе рендеринга шаблона.

Проблема возникает когда spark-base используется как dependency от spark-4.1.
При прямой установке spark-base проблема не воспроизводится.

## Workaround 1: Раздельная установка

Установить компоненты по отдельности вместо единого chart:

```bash
# 1. Установить spark-base отдельно
helm install spark-base charts/spark-base -n <namespace> \
  --set minio.enabled=true \
  --set postgresql.enabled=false \
  --set security.podSecurityStandards=false

# 2. Установить Spark без spark-base dependency
helm install spark charts/spark-4.1 -n <namespace> \
  --set connect.enabled=true \
  --set spark-base.enabled=false
```

## Workaround 2: Отключить валидацию

```bash
helm install spark charts/spark-4.1 -n <namespace> \
  --set connect.enabled=true \
  --disable-openapi-validation
```

⚠️ Это обходной путь - проверка labels не выполняется.

## Workaround 3: Использовать spark-3.5

Для Spark 3.5 используйте модульные charts:

```bash
# Spark 3.5 не имеет этой проблемы
helm install spark-connect charts/spark-3.5/charts/spark-connect -n <namespace>
helm install spark-standalone charts/spark-3.5/charts/spark-standalone -n <namespace>
```

## Diagnosis

```bash
# Проверить chart на наличие "N/A" в values
helm show values charts/spark-4.1 | grep -i "n/a"

# Проверить отрендеренный шаблон
helm template test charts/spark-4.1 -n <namespace> \
  --set connect.enabled=true > /tmp/rendered.yaml

# Поиск "N/A" в отрендеренном yaml
grep -R "N/A" /tmp/rendered.yaml
```

## Solution (потребует investigation)

Нужно найти источник "N/A" в шаблонах. Возможные места:

1. **Chart.yaml** - проверить `appVersion` или другие поля
2. **values.yaml** - поискать "N/A" как дефолтное значение
3. **helpers.tpl** - проверить label helpers на условия которые могут вернуть "N/A"
4. **Subchart dependencies** - проверить как передаются значения при использовании как dependency

## Temporary Fix Values

Если проблема в конкретном поле, можно override:

```bash
# Пример (зависит от реального источника проблемы)
helm install spark charts/spark-4.1 -n <namespace> \
  --set spark-base.minio.persistence.storageClass="standard" \
  --set spark-base.someField="valid-value"
```

## Related

- ISSUE-030: Spark 4.1 MinIO label "N/A" error
- Helm Chart labels: https://helm.sh/docs/topics/charts/#labels-and-annotations
