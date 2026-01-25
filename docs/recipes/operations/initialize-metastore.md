# Initialize Hive Metastore

**Related Issue:** ISSUE-029

## Symptoms

- Spark jobs не могут найти таблицы
- Ошибка: `Database 'default' not found`
- Metastore не инициализирован

## Diagnosis

```bash
# Проверить статус Metastore
kubectl exec -n <namespace> deploy/hive-metastore -- \
  /opt/hive/bin/schematool -info -dbType postgres

# Проверить подключение к PostgreSQL
kubectl exec -n <namespace> deploy/hive-metastore -- \
  psql -h postgresql-metastore -U hive -d metastore_spark41 -c "\dt"
```

## Solution

### Для Spark 4.1

```bash
# 1. Включить Metastore
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set hiveMetastore.enabled=true \
  --set hiveMetastore.warehouseDir=s3a://warehouse/spark-41 \
  --set hiveMetastore.postgresql.enabled=true \
  --set hiveMetastore.postgresql.persistence.enabled=true \
  --set hiveMetastore.postgresql.persistence.size=5Gi \
  --reuse-values

# 2. Инициализировать schema
kubectl exec -n <namespace> deploy/hive-metastore -- \
  /opt/hive/bin/schematool -initSchema -dbType postgres
```

### Для Spark 3.5

```bash
# 1. Включить Metastore
helm upgrade spark-connect charts/spark-3.5/charts/spark-connect -n <namespace> \
  --set hiveMetastore.enabled=true \
  --set postgresql.enabled=true \
  --set postgresql.persistence.enabled=true \
  --reuse-values

# 2. Инициализировать schema
kubectl exec -n <namespace> deploy/hive-metastore -- \
  /opt/hive/bin/schematool -initSchema -dbType postgres
```

### Использовать external Metastore

```bash
# Подключиться к существующему Metastore
helm upgrade spark-connect charts/spark-4.1 -n <namespace> \
  --set hiveMetastore.enabled=false \
  --set connect.sparkConf.spark\\.hive\\.metastore.uris=thrift://external-metastore.prod.svc.cluster.local:9083 \
  --set connect.sparkConf.spark\\.sql\\.warehouseDir=s3a://warehouse/company \
  --reuse-values
```

## Verification

```bash
# Дождаться готовности Metastore
kubectl wait --for=condition=ready pod -n <namespace> -l app=hive-metastore --timeout=300s

# Проверить подключение
kubectl exec -n <namespace> deploy/hive-metastore -- \
  /opt/hive/bin/beeline -u jdbc:hive2://localhost:9083 -e "SHOW DATABASES;"

# Из Spark
kubectl exec -n <namespace> deploy/jupyter -- \
  python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote('sc://spark-41-connect:15002').getOrCreate()
spark.sql('CREATE DATABASE IF NOT EXISTS test_db')
spark.sql('SHOW DATABASES').show()
spark.stop()
"
```

## Troubleshooting

```bash
# Если Metastore не стартует
kubectl logs -n <namespace> deploy/hive-metastore --tail=100

# Проверить PostgreSQL
kubectl exec -n <namespace> postgresql-metastore-41 -- \
  psql -U hive -d metastore_spark41 -c "SELECT version();"

# Переинициализировать (DROP DATABASE сначала)
kubectl exec -n <namespace> postgresql-metastore-41 -- \
  psql -U hive -d metastore_spark41 -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
kubectl exec -n <namespace> deploy/hive-metastore -- \
  /opt/hive/bin/schematool -initSchema -dbType postgres
```

## References

- ISSUE-029: Hive Metastore init
- Apache Hive Metastore: https://cwiki.apache.org/confluence/display/Hive/AdminManual+Metastore+Administration
