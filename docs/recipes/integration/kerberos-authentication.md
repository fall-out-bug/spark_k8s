# Kerberos Authentication Integration

**Source:** Integration recipes

## Overview

Настроить Kerberos аутентификацию для Spark при работе с secured кластерами (HDFS, Hive Metastore, S3).

## Architecture

```
Spark Connect / Jobs
    ↓
Kinit (keytab)
    ↓
KDC (Key Distribution Center)
    ↓
Secured Resources (HDFS / Hive / S3)
```

## Prerequisites

- Active Directory / MIT Kerberos KDC
- Kerberos keytab для principal
- Krb5.conf файл

## Deployment

### Шаг 1: Создать Kerberos secret

```bash
# 1. Создать keytab secret
kubectl create secret generic spark-kerberos \
  -n spark \
  --from-file=krb5.conf=/etc/krb5.conf \
  --from-file=spark.keytab=/path/to/spark.keytab

# 2. Проверить secret
kubectl describe secret spark-kerberos -n spark
```

### Шаг 2: Настроить Spark Connect

```bash
# Spark 4.1
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set connect.sparkConf.spark\\.authenticate=true \
  --set connect.sparkConf.spark\\.kerberos.principal=spark/_HOST@COMPANY.COM \
  --set connect.sparkConf.spark\\.kerberos.keytab=/etc/secrets/spark.keytab \
  --set connect.sparkConf.spark\\.kerberos.kinit.path=/usr/bin/kinit \
  --set connect.sparkConf.spark\\.kerberos.refreshKrb5Config=true \
  --set connect.extraVolumes[0].name=kerberos \
  --set connect.extraVolumes[0].secret.secretName=spark-kerberos \
  --set connect.extraVolumeMounts[0].name=kerberos \
  --set connect.extraVolumeMounts[0].mountPath=/etc/secrets \
  --reuse-values
```

### Шаг 3: Настроить HDFS access

```bash
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set connect.sparkConf.spark\\.hadoop\\.dfs.namenode.kerberos.principal=nn/_HOST@COMPANY.COM \
  --set connect.sparkConf.spark\\.hadoop\\.dfs.namenode.kerberos.keytab=/etc/secrets/nn.keytab \
  --set connect.sparkConf.spark\\.hadoop\\.dfs.webhdfs.kerberos.principal=HTTP/_HOST@COMPANY.COM \
  --set connect.sparkConf.spark\\.hadoop\\.dfs.webhdfs.kerberos.keytab=/etc/secrets/http.keytab \
  --reuse-values
```

### Шаг 4: Настроить Hive Metastore (если secured)

```bash
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set connect.sparkConf.spark\\.hive\\.metastore.kerberos.principal=hive/_HOST@COMPANY.COM \
  --set connect.sparkConf.spark\\.hive\\.metastore.kerberos.keytab=/etc/secrets/hive.keytab \
  --reuse-values
```

### Шаг 5: Настроить S3 с Kerberos (если S3AD)

```bash
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set connect.sparkConf.spark\\.hadoop\\.fs.s3a.kerberos.supported=true \
  --set connect.sparkConf.spark\\.hadoop\\.fs.s3a.kerberos.principal=s3a@COMPANY.COM \
  --set connect.sparkConf.spark\\.hadoop\\.fs.s3a.kerberos.keytab=/etc/secrets/s3a.keytab \
  --reuse-values
```

## krb5.conf Configuration

```ini
[libdefaults]
  default_realm = COMPANY.COM
  dns_lookup_realm = false
  ticket_lifetime = 24h
  renew_lifetime = 7d
  forwardable = true
  udp_preference_limit = 1
  rdns = false

[realms]
  COMPANY.COM = {
    kdc = kdc.company.com:88
    admin_server = kdc.company.com:749
    default_domain = company.com
  }

[domain_realm]
  .company.com = COMPANY.COM
  company.com = COMPANY.COM
```

## Docker Image с Kerberos support

```dockerfile
# docker/spark-4.1/Dockerfile
FROM apache/spark:4.1.0

# Установить Kerberos client
RUN apt-get update && \
    apt-get install -y krb5-user libpam-krb5 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Скопировать конфиги
COPY krb5.conf /etc/krb5.conf
COPY spark.keytab /etc/secrets/spark.keytab

ENV KRB5_CONFIG=/etc/krb5.conf
```

## Usage в Jupyter

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .remote("sc://spark-connect:15002") \
    .config("spark.authenticate", "true") \
    .config("spark.kerberos.principal", "spark@COMPANY.COM") \
    .config("spark.kerberos.keytab", "/etc/secrets/spark.keytab") \
    .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
    .enableHiveSupport() \
    .getOrCreate()

# Read from secured HDFS
df = spark.read.parquet("hdfs://namenode:9000/warehouse/table")
df.show()

spark.stop()
```

## Usage в Airflow

```python
from airflow import DAG
from airflow.providers.spark.operators.spark_submit import SparkSubmitOperator

dag = DAG('kerberos_job', start_date=datetime(2025, 1, 26), schedule_interval='@daily')

spark_job = SparkSubmitOperator(
    task_id='secured_etl',
    application='s3a://dags/jobs/process_data.py',
    conn_id='spark_connect_default',
    conf={
        'spark.authenticate': 'true',
        'spark.kerberos.principal': 'spark@COMPANY.COM',
        'spark.kerberos.keytab': '/etc/secrets/spark.keytab',
        'spark.hadoop.fs.defaultFS': 'hdfs://namenode:9000',
    },
    dag=dag
)
```

## Keytab Renewal

Kerberos tickets истекают (обычно через 24 часа). Настройте auto-renewal:

```bash
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set connect.sparkConf.spark\\.kerberos.refreshKrb5Config=true \
  --set connect.sparkConf.spark\\.kerberos.kinit.path=/usr/bin/kinit \
  --set connect.sparkConf.spark\\.kerberos.principal=spark@COMPANY.COM \
  --reuse-values
```

Или через init container:

```yaml
connect:
  initContainers:
    - name: kinit
      image: spark-custom:4.1.0
      command:
        - sh
        - -lc
        - |
          kinit -kt /etc/secrets/spark.keytab -p spark@COMPANY.COM
          sleep infinity
      volumeMounts:
        - name: kerberos
          mountPath: /etc/secrets
```

## Verification

```bash
# 1. Проверить ticket
kubectl exec -n spark deploy/spark-connect -- \
  klist

# 2. Проверить principal
kubectl exec -n spark deploy/spark-connect -- \
  klist -k /etc/secrets/spark.keytab

# 3. Тест подключения к HDFS
kubectl exec -n spark deploy/spark-connect -- \
  hdfs dfs -ls /warehouse

# 4. Тест Spark job
kubectl exec -n spark deploy/jupyter -- \
  python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote('sc://spark-connect:15002').getOrCreate()
df = spark.sql('SHOW DATABASES')
df.show()
spark.stop()
"
```

## Troubleshooting

```bash
# Если ticket expired
kubectl exec -n spark deploy/spark-connect -- \
  kinit -kt /etc/secrets/spark.keytab -p spark@COMPANY.COM

# Если principal not found
# Проверьте что principal соответствует keytab
klist -k /etc/secrets/spark.keytab

# Если cannot contact KDC
# Проверьте krb5.conf и DNS
nc -zv kdc.company.com 88

# Если access denied
# Проверьте права principal на ресурс
kinit -kt spark.keytab spark@COMPANY.COM
hdfs dfs -ls /warehouse
```

## Security Best Practices

1. **ROTATE KEYTABS REGULARLY**
   - Используйте разные keytabs для dev/prod
   - Храните keytabs в Kubernetes Secrets
   - Вращайте keytabs через автоматизацию

2. **MINIMIZE TICKET LIFETIME**
   ```bash
   # В krb5.conf
   ticket_lifetime = 1h
   renew_lifetime = 8h
   ```

3. **USE SERVICE PRINCIPALS**
   - spark@COMPANY.COM вместо user@COMPANY.COM
   - Ограничьте права principals

4. **AUDIT KERBEROS ACCESS**
   ```bash
   # Логи в KDC
   grep spark /var/log/krb5kdc/kdc.log
   ```

## References

- Kerberos: https://web.mit.edu/kerberos/
- Spark Security: https://spark.apache.org/docs/latest/security.html
- HDFS Security: https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/Hadoop-Kerberos.html
