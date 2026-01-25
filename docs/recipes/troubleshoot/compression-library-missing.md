# Zstandard Compression Library Missing

**Related Issue:** ISSUE-023

## Symptoms

```
java.lang.NoClassDefFoundError: com/github/luben/zstd/ZstdInputStream
Failed to load native zstd library
java.lang UnsatisfiedLinkError: /tmp/libzstd.so.xxxxx
```

## Diagnosis

```bash
# Проверить наличие библиотеки в classpath
kubectl exec -n <namespace> deploy/spark-connect -- \
  ls -la /opt/spark/jars/ | grep zstd

# Проверить версию Spark
kubectl exec -n <namespace> deploy/spark-connect -- \
  /opt/spark/bin/spark-submit --version
```

## Solution

### Spark 4.1: Добавить zstd библиотеку

```bash
# В Dockerfile
RUN mkdir -p /opt/spark/jars && \
    curl -L https://repo1.maven.org/maven2/com/github/luben/zstd-jni/1.5.5-5/zstd-jni-1.5.5-5.jar -o /opt/spark/jars/zstd-jni-1.5.5-5.jar

# Или через init container в values.yaml
connect:
  extraVolumes:
    - name: zstd-lib
      emptyDir: {}
  extraVolumeMounts:
    - name: zstd-lib
      mountPath: /opt/spark/jars/zstd-jni-1.5.5-5.jar
      subPath: zstd-jni.jar
  initContainers:
    - name: copy-zstd
      image: busybox
      command:
        - sh
        - -c
        - |
          wget -O /tmp/zstd/zstd-jni.jar https://repo1.maven.org/maven2/com/github/luben/zstd-jni/1.5.5-5/zstd-jni-1.5.5-5.jar
      volumeMounts:
        - name: zstd-lib
          mountPath: /tmp/zstd
```

### Встроенное решение (обновить image)

```dockerfile
# docker/spark-4.1/Dockerfile
FROM apache/spark:4.1.0

# Добавить zstd библиотеку
RUN wget -q https://repo1.maven.org/maven2/com/github/luben/zstd-jni/1.5.5-5/zstd-jni-1.5.5-5.jar -O /opt/spark/jars/zstd-jni-1.5.5-5.jar
```

### Временно отключить компрессию

```bash
# Если не критично
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.eventLog.compress=false \
  --reuse-values
```

## Verification

```bash
# Пересобрать image
docker build -t spark-custom:4.1.0-zstd docker/spark-4.1/

# Обновить deployment
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set connect.image.tag=4.1.0-zstd \
  --reuse-values

# Проверить
kubectl exec -n <namespace> deploy/spark-connect -- \
  ls -la /opt/spark/jars/ | grep zstd

# Тест job с компрессией
kubectl exec -n <namespace> deploy/jupyter -- \
  python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote('sc://spark-connect:15002').getOrCreate()
spark.conf.set('spark.eventLog.compression.codec', 'zstd')
spark.range(1000).count()
spark.stop()
"
```

## References

- ISSUE-023: Zstandard missing (4.1)
- Zstd JNI: https://github.com/luben/zstd-jni
- Spark Compression: https://spark.apache.org/docs/latest/configuration.html#compression
