# External Hive Metastore Integration

**Source:** Integration recipes

## Overview

Подключить Spark к корпоративному Hive Metastore вместо деплоя собственного.

## Architecture

```
Spark Connect / Jobs
    ↓
Thrift Client
    ↓
External Hive Metastore (RDS / EMR / HDInsight)
    ↓
S3 / ADLS / HDFS (Warehouse)
```

## Deployment

### Вариант A: AWS Glue Data Catalog

```bash
# Spark 4.1
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set hiveMetastore.enabled=false \
  --set connect.sparkConf.spark\\.hive\\.metastore.uris=thrift://glue.us-east-1.amazonaws.com:9083 \
  --set connect.sparkConf.spark\\.hive\\.metastore.client.factory.class=com.amazonaws.glue.catalog.GlueCatalog \
  --set connect.sparkConf.spark\\.glue\\.catalog.skipArchive=true \
  --set connect.sparkConf.spark\\.sql\\.warehouseDir=s3a://company-bucket/warehouse \
  --set connect.sparkConf.spark\\.sql\\.catalogImplementation=hive \
  --reuse-values
```

### Вариант B: AWS EMR Metastore

```bash
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set hiveMetastore.enabled=false \
  --set connect.sparkConf.spark\\.hive\\.metastore.uris=thrift://emr-metastore.company.com:9083 \
  --set connect.sparkConf.spark\\.sql\\.warehouseDir=s3a://aws-emr-warehouse/ \
  --set connect.sparkConf.spark\\.hive\\.metastore.sasl.enabled=true \
  --reuse-values
```

### Вариант C: Azure HDInsight / ADLS

```bash
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set hiveMetastore.enabled=false \
  --set connect.sparkConf.spark\\.hive\\.metastore.uris=thrift://hdinsight-metastore.company.com:9083 \
  --set connect.sparkConf.spark\\.sql\\.warehouseDir=abfss://container@storageaccount.dfs.core.windows.net/warehouse \
  --set connect.sparkConf.spark.hadoop.fs.abfss.impl=org.apache.hadoop.fs.adl.AdlFileSystem \
  --set connect.sparkConf.spark.hadoop.fs.adls.account.keydatalake.gen2.hadoop.fs.adl.SecretKeyProviderService \
  --reuse-values
```

### Вариант D: On-prem Hive Metastore (PostgreSQL)

```bash
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set hiveMetastore.enabled=false \
  --set connect.sparkConf.spark\\.hive\\.metastore.uris=thrift://hive-metastore.prod.svc.cluster.local:9083 \
  --set connect.sparkConf.spark\\.sql\\.warehouseDir=s3a://company-bucket/warehouse \
  --reuse-values

# Или через environment переменные
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set connect.env.HIVE_SITE_CONF=hive.metastore.uris=thrift://hive-metastore.prod.svc.cluster.local:9083 \
  --reuse-values
```

## Authentication

### Kerberos

```bash
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set connect.sparkConf.spark\\.hive\\.metastore.kerberos.principal=hive/_HOST@COMPANY.COM \
  --set connect.sparkConf.spark\\.hive\\.metastore.kerberos.keytab=/etc/secrets/hive.keytab \
  --set connect.extraVolumes[0].name=kerberos \
  --set connect.extraVolumes[0].secret.secretName=kerberos-keytab \
  --set connect.extraVolumeMounts[0].name=kerberos \
  --set connect.extraVolumeMounts[0].mountPath=/etc/secrets \
  --reuse-values
```

### AWS IAM Role (через IRSA)

```bash
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set connect.sparkConf.spark\\.hadoop\\.fs.s3a.aws.credentials.provider=com.amazonaws.auth.WebIdentityTokenCredentialsProvider \
  --set connect.sparkConf.spark\\.hadoop\\.fs.s3a.aws.credentials.role.arn=arn:aws:iam::111122223333:role/spark-role \
  --set connect.serviceAccount.annotations."eks\\.amazonaws\\.com/role-arn"=arn:aws:iam::111122223333:role/spark-role \
  --reuse-values
```

## Verification

### Проверить подключение к Metastore

```bash
# 1. Из Spark Connect pod
kubectl exec -n spark deploy/spark-connect -- \
  /opt/spark/bin/beeline -u jdbc:hive2://<metastore-host>:9083 -e "SHOW DATABASES;"

# Или через beeline внутри Jupyter
kubectl exec -n spark deploy/jupyter -- \
  /opt/spark/bin/beeline -u jdbc:hive2://glue.us-east-1.amazonaws.com:9083 \
  -e "SHOW DATABASES;"
```

### Проверить из Spark

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .remote("sc://spark-connect:15002") \
    .config("spark hive.metastore.uris", "thrift://glue.us-east-1.amazonaws.com:9083") \
    .enableHiveSupport() \
    .getOrCreate()

# Проверить warehouse
spark.sql("SHOW DATABASES").show()

# Проверить таблицы
spark.sql("SHOW TABLES IN production").show()

# Query
df = spark.sql("SELECT * FROM production.events LIMIT 10")
df.show()

spark.stop()
```

### Проверить ACL/Permissions

```bash
# AWS Glue: проверить permissions
aws glue get-databases --query 'DatabaseList[?Name==`production`].Name'

# AWS S3: проверить доступ к warehouse
aws s3 ls s3://company-bucket/warehouse/ --recursive --summarize
```

## Configuration Examples

### EMR + S3 + Glue

```yaml
connect:
  sparkConf:
    # Glue Catalog
    spark hive.metastore.uris: "thrift://glue.us-east-1.amazonaws.com:9083"
    spark.catalogImplementation: "hive"
    spark.sql.warehouse.dir: "s3a://company-warehouse/"
    # S3
    spark.hadoop.fs.s3a.aws.credentials.provider: "com.amazonaws.auth.WebIdentityTokenCredentialsProvider"
    spark.hadoop.fs.s3a.path.style.access: "true"
    # Optimizations
    spark.sql.shuffle.partitions: "200"
    spark.dynamicAllocation.enabled: "true"
```

### Azure HDInsight + ADLS Gen2

```yaml
connect:
  sparkConf:
    # Metastore
    spark hive.metastore.uris: "thrift://hdinsight-metastore.eastus2.cloudapp.azure.com:9083"
    # ADLS Gen2
    spark.hadoop.fs.abfss.impl: "org.apache.hadoop.fs.adl.AdlFileSystem"
    spark.hadoop.fs.adls.account.keydatalake.gen2.hadoop.fs.adl.SecretKeyProviderService:
    spark.hadoop.fs.adls.account.keydatalake.gen2.secret.key: "<storage-account-key>"
    spark.sql.warehouse.dir: "abfss://data@storageaccount.dfs.core.windows.net/warehouse"
```

## Troubleshooting

```bash
# Если connection refused
nc -zv <metastore-host> 9083

# Если authentication failed
kinit -k -t /etc/secrets/hive.keytab hive/$(hostname -s)@COMPANY.COM

# Если table not found
# Проверьте что вы используете правильный database
spark.sql("USE production").show()
spark.sql("SHOW TABLES").show()

# Если permission denied на S3
# Проверьте IAM role и политики
aws iam get-role --role-name spark-role --query 'Role.AssumeRolePolicy'
```

## Migration from Embedded Metastore

Если вы мигрируете с встроенного Metastore на внешний:

1. **Экспортировать metastore database**
```bash
kubectl exec -n spark deploy/hive-metastore -- \
  /opt/hive/bin/schematool -info -dbType postgres -userName hive -pass <password>

# Dump schema
kubectl exec -n spark deploy/postgresql-metastore-41 -- \
  pg_dump -U hive metastore_spark41 > metastore_dump.sql
```

2. **Импортировать во внешний Metastore**
```bash
psql -h <external-metastore> -U hive -d metastore < metastore_dump.sql
```

3. **Перенастроить Connect**
```bash
helm upgrade spark-connect charts/spark-4.1 -n spark \
  --set hiveMetastore.enabled=false \
  --set connect.sparkConf.spark\\.hive\\.metastore.uris=thrift://<external-metastore>:9083 \
  --reuse-values
```

## References

- AWS Glue: https://docs.aws.amazon.com/glue/latest/dg/catalog-and-crawl.html
- Azure HDInsight: https://docs.microsoft.com/en-us/azure/hdinsight/hdinsight-use-hive-metastore
- Hive Metastore: https://cwiki.apache.org/confluence/display/Hive/AdminManual+Metastore+Administration
