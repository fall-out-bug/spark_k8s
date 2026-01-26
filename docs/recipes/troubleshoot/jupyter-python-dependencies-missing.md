# Jupyter Python Dependencies Missing for Spark Connect

**Related Issues:** ISSUE-034

## Symptoms

```
ModuleNotFoundError: No module named 'grpc'
PySparkImportError: [PACKAGE_NOT_INSTALLED] grpcio >= 1.48.1 must be installed

ModuleNotFoundError: No module named 'grpc_status'
PySparkImportError: [PACKAGE_NOT_INSTALLED] grpcio-status >= 1.48.1 must be installed

ModuleNotFoundError: No module named 'zstandard'
PySparkImportError: [PACKAGE_NOT_INSTALLED] zstandard >= 0.25.0 must be installed
```

При попытке подключиться к Spark Connect из Jupyter:

```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()
# Ошибка модуля
```

## Diagnosis

```bash
# 1. Проверить установленные пакеты в Jupyter pod
kubectl exec -n <namespace> <jupyter-pod> -- pip list | grep -E "grpc|zstandard"

# 2. Проверить версию PySpark
kubectl exec -n <namespace> <jupyter-pod> -- python3 -c "import pyspark; print(pyspark.__version__)"

# 3. Попробовать импортировать
kubectl exec -n <namespace> <jupyter-pod> -- python3 -c "import grpc; import grpc_status; import zstandard"
```

## Root Cause

Spark 4.1 Connect требует следующие Python зависимости для клиента:
- `grpcio >= 1.48.1` - gRPC framework
- `grpcio-status >= 1.48.1` - gRPC status handling
- `zstandard >= 0.25.0` - Zstd compression

Jupyter Dockerfile для Spark 4.1 не включал эти зависимости.

## Solution

### Обновить Dockerfile (docker/jupyter-4.1/Dockerfile)

```dockerfile
FROM apache/spark:4.1.0-python3

# Install JupyterLab
USER root
RUN pip install --no-cache-dir \
    jupyterlab==4.0.0 \
    pyspark==4.1.0 \
    "grpcio>=1.48.1" \
    "grpcio-status>=1.48.1" \
    "zstandard>=0.25.0" \
    pandas>=2.0.0 \
    pyarrow>=10.0.0 \
    matplotlib \
    seaborn

# ... остальное
```

### Пересобрать и задеплоить

```bash
# Пересобрать image
docker build -t jupyter-spark:4.1.0 docker/jupyter-4.1/

# В Minikube
minikube image load -p <profile> jupyter-spark:4.1.0

# Перезапустить Jupyter deployment
kubectl rollout restart deployment -n <namespace> <jupyter-deployment>

# Подождать готовности
kubectl wait --for=condition=ready pod -n <namespace> -l app=jupyter --timeout=120s
```

### Временное решение (установить в running pod)

```bash
kubectl exec -n <namespace> <jupyter-pod> -- \
  pip install "grpcio>=1.48.1" "grpcio-status>=1.48.1" "zstandard>=0.25.0"
```

⚠️ Это не сохранится после перезапуска pod!

## Verification

```bash
# 1. Проверить пакеты
kubectl exec -n <namespace> <jupyter-pod> -- \
  pip list | grep -E "grpc|zstandard|pyspark"

# 2. Проверить импорт
kubectl exec -n <namespace> <jupyter-pod> -- python3 -c "
import grpc
import grpc_status
import zstandard
from pyspark.sql import SparkSession
print('All dependencies OK')
"

# 3. Тест подключение к Connect
kubectl exec -n <namespace> <jupyter-pod> -- python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote('sc://spark-connect:15002').getOrCreate()
print(spark.version)
spark.stop()
"
```

## Минимальные версии для Spark Connect

| Spark Version | grpcio | grpcio-status | zstandard |
|---------------|--------|---------------|-----------|
| 4.1.0 | >= 1.48.1 | >= 1.48.1 | >= 0.25.0 |
| 4.0.x | >= 1.48.0 | >= 1.48.0 | >= 0.18.0 |
| 3.5.x | Не требуется | Не требуется | Не требуется |

## Related

- ISSUE-034: Jupyter grpcio missing for Connect 4.1
- compression-library-missing.md: Zstd для Java (отдельная проблема)
