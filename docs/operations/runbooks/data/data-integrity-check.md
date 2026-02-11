# Data Integrity Check Runbook

## Overview

This runbook covers the detection, diagnosis, and remediation of data integrity issues including corruption, silent data loss, and checksum mismatches.

## Detection

### Symptoms

| Symptom | Severity | Description |
|---------|----------|-------------|
| Checksum mismatch | Critical | Calculated checksum doesn't match stored |
| Corrupted data read | Critical | Parquet/ORC file corruption |
| Silent data loss | High | Files missing but no error thrown |
| Schema mismatch | High | Data doesn't match expected schema |
| Duplicate data | Medium | Duplicate records in output |

### Detection Queries

```sql
-- Check for NULL in critical columns
SELECT COUNT(*) FROM fact_table WHERE critical_column IS NULL;

-- Check for duplicates
SELECT key_column, COUNT(*) as cnt
FROM fact_table
GROUP BY key_column
HAVING COUNT(*) > 1;

-- Check for out-of-range values
SELECT COUNT(*) FROM fact_table WHERE amount < 0 OR amount > 1000000;

-- Check referential integrity
SELECT COUNT(*) FROM fact_table f
LEFT JOIN dim_customer c ON f.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
```

### Checksum Detection

```bash
# Calculate MD5 checksum
md5sum /data/file.parquet

# Calculate SHA256 checksum
sha256sum /data/file.parquet

# Verify against stored checksum
echo "stored_checksum  /data/file.parquet" | md5sum -c

# Batch verify directory
find /data -name "*.parquet" -exec md5sum {} \; > checksums.txt
md5sum -c checksums.txt
```

### Spark Data Validation

```scala
// Add checksum validation to Spark jobs
val df = spark.read.parquet("s3a://spark-data/production/fact_table")

// Check for empty files
val emptyFiles = spark.sparkContext.parallelize(List.empty[String])
df.rdd.mapPartitionsWithIndex { (idx, iter) =>
  if (iter.isEmpty) Iterator((idx, true)) else Iterator()
}.collect().foreach { case (idx, _) =>
  logError(s"Empty partition detected: $idx")
}

// Check for NULL in critical columns
val nullCounts = df.columns.map { col =>
  (col, df.filter(df(col).isNull).count())
}.filter(_._2 > 0)

// Schema validation
val expectedSchema = StructType(Seq(
  StructField("id", LongType),
  StructField("name", StringType)
))
if (!df.schema.equals(expectedSchema)) {
  throw new Exception(s"Schema mismatch: ${df.schema} vs $expectedSchema")
}
```

### Grafana Dashboard Queries

```promql
# Data validation failure rate
rate(data_validation_failures_total[5m])

# Checksum mismatch rate
rate(checksum_mismatches_total[5m])

# Corrupted file count
data_corrupted_files_total

# Missing partition count
data_missing_partitions_total
```

---

## Diagnosis

### Step 1: Identify Affected Data

```bash
# Run integrity check script
scripts/operations/recovery/verify-data-integrity.sh \
  --bucket spark-data \
  --prefix "production/fact_table/" \
  --verbose

# Check for corrupted Parquet files
spark-submit \
  --class com.example.ParquetValidator \
  --master local \
  /jars/parquet-validator.jar \
  --path s3a://spark-data/production/fact_table/

# Check for missing files
aws s3 ls s3://spark-data/production/fact_table/dt=2026-02-11/ | wc -l
# Compare with expected count
```

### Step 2: Verify Checksums

```bash
# Get stored checksums
aws s3 ls s3://spark-data/checksums/ | grep "fact_table"

# Download checksum file
aws s3 cp s3://spark-data/checksums/fact_table-checksums.txt /tmp/

# Verify checksums
md5sum -c /tmp/fact_table-checksums.txt

# Identify mismatched files
md5sum -c /tmp/fact_table-checksums.txt | grep ": FAILED"
```

### Step 3: Check Schema Consistency

```bash
# Use Spark to check schema
spark-sql -e "DESCRIBE EXTENDED production.fact_table;"

# Compare with expected schema
spark-submit \
  --class com.example.SchemaValidator \
  --master local \
  /jars/schema-validator.jar \
  --table production.fact_table \
  --expected-schema /schemas/fact_table.json

# Check for schema drift
for file in $(aws s3 ls s3://spark-data/production/fact_table/ --recursive); do
  schema=$(parquet-tools schema "$file" 2>/dev/null)
  # Compare schemas
done
```

### Step 4: Identify Corrupt Files

```bash
# Use Parquet tools to check files
find /data -name "*.parquet" -exec parquet-tools show {} \; > /tmp/parquet-content.txt

# Check for ORC corruption
find /data -name "*.orc" -exec orc-tool scan {} \; > /tmp/orc-scan.txt

# Check for corrupted files using Spark
spark-submit \
  --class com.example.CorruptFileFinder \
  --master local[*] \
  /jars/corrupt-file-finder.jar \
  --path s3a://spark-data/production/fact_table/
```

### Step 5: Determine Impact Scope

```bash
# Count affected partitions
aws s3 ls s3://spark-data/production/fact_table/ | grep "dt=" | wc -l

# Count affected files
aws s3 ls s3://spark-data/production/fact_table/ --recursive | wc -l

# Calculate data volume
aws s3 ls s3://spark-data/production/fact_table/ --recursive --summarize | tail -1

# Check downstream dependencies
kubectl get sparkapplications -n spark-operations -o json | \
  jq -r '.items[] | select(.spec.mainAppFile | contains("fact_table")) | .metadata.name'
```

---

## Remediation

### Option 1: Restore from Backup (Recommended)

**Time to recover**: Hours
**Data loss**: Up to RPO (24 hours)

```bash
# 1. Identify affected files
scripts/operations/recovery/verify-data-integrity.sh \
  --bucket spark-data \
  --prefix "production/fact_table/" \
  --output /tmp/corrupted-files.txt

# 2. Restore from backup
cat /tmp/corrupted-files.txt | while read file; do
  backup_path=$(echo $file | sed 's|spark-data/|spark-backups/|')
  aws s3 cp "s3://$backup_path" "s3://$file"
done

# 3. Verify restore
scripts/operations/recovery/verify-data-integrity.sh \
  --bucket spark-data \
  --prefix "production/fact_table/"
```

### Option 2: Restore from Versioning

**Time to recover**: Minutes to hours
**Data loss**: None (if previous version exists)

```bash
# 1. Get file versions
aws s3api list-object-versions \
  --bucket spark-data \
  --prefix "production/fact_table/corrupt-file.parquet" \
  --query 'Versions[?IsLatest==`true`].VersionId'

# 2. Restore previous version
VERSION_ID="<previous-version-id>"
aws s3api get-object \
  --bucket spark-data \
  --key "production/fact_table/corrupt-file.parquet" \
  --version-id "$VERSION_ID" \
  /tmp/restored-file.parquet

# 3. Upload restored version
aws s3 cp /tmp/restored-file.parquet \
  s3://spark-data/production/fact_table/corrupt-file.parquet

# 4. Batch restore
scripts/operations/recovery/restore-s3-bucket.sh \
  --bucket spark-data \
  --prefix "production/fact_table/" \
  --restore-to "2026-02-10 12:00:00"
```

### Option 3: Recompute from Source

**Time to recover**: Hours to days
**Data loss**: None

```bash
# 1. Submit recomputation job
kubectl apply -f - <<EOF
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: recompute-fact-table-$(date +%Y%m%d-%H%M%S)
  namespace: spark-operations
spec:
  type: Scala
  mode: cluster
  image: spark:3.5.0
  mainClass: com.example.RecomputeFactTable
  arguments:
    - --source
    - s3a://spark-input-data/raw_events/
    - --target
    - s3a://spark-data/production/fact_table/
    - --corrupt-partitions
    - dt=2026-02-11
  driver:
    cores: 1
    memory: 2g
  executor:
    cores: 2
    instances: 20
    memory: 4g
EOF
```

### Option 4: Repair Using MSCK

**Time to recover**: Minutes
**Data loss**: None

```bash
# 1. Drop corrupted partition
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "ALTER TABLE production.fact_table DROP IF EXISTS PARTITION (dt='2026-02-11');"

# 2. Repair partition from S3
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "MSCK REPAIR TABLE production.fact_table;"

# 3. Verify data
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "SELECT COUNT(*) FROM production.fact_table WHERE dt='2026-02-11';"
```

### Option 5: Schema Evolution Fix

**Time to recover**: Minutes
**Data loss**: None

```bash
# 1. Identify schema change
spark-sql -e "DESCRIBE production.fact_table;" > /tmp/current-schema.txt
diff /schemas/expected-schema.txt /tmp/current-schema.txt

# 2. Alter table if needed
kubectl exec -n spark-operations spark-hive-metastore-0 -- \
  hive -e "ALTER TABLE production.fact_table ADD COLUMNS (new_column STRING);"

# 3. Update schema validation
spark-sql -e "ALTER TABLE production.fact_table SET SERDEPROPERTIES ('mapping.column_name'='new_column_name');"
```

---

## Verification

### Post-Remediation Checks

```bash
# 1. Run integrity check
scripts/operations/recovery/verify-data-integrity.sh \
  --bucket spark-data \
  --prefix "production/fact_table/" \
  --verbose

# 2. Verify checksums
md5sum -c /tmp/fact_table-checksums.txt | grep ": OK" | wc -l

# 3. Verify schema
spark-sql -e "DESCRIBE production.fact_table;" > /tmp/verified-schema.txt
diff /schemas/expected-schema.txt /tmp/verified-schema.txt

# 4. Run test queries
spark-sql -e "SELECT COUNT(*) FROM production.fact_table WHERE dt='2026-02-11';"

# 5. Verify data quality
spark-submit \
  --class com.example.DataQualityValidator \
  --master local \
  /jars/data-quality-validator.jar \
  --table production.fact_table
```

### Automated Validation

```bash
# Run full validation suite
scripts/operations/recovery/verify-data-integrity.sh \
  --bucket spark-data \
  --prefix "production/" \
  --full-validation \
  --report /tmp/validation-report.html

# Expected output:
# - Files validated: 10000
# - Checksums verified: 10000
# - Schema valid: Yes
# - NULL checks: Passed
# - Duplicate checks: Passed
# - Referential integrity: Passed
```

---

## Prevention

### 1. Enable Checksum Storage

```bash
# Calculate and store checksums
aws s3 ls s3://spark-data/production/ --recursive | \
  awk '{print $4}' | \
  while read file; do
    checksum=$(aws s3api head-object --bucket spark-data --key "$file" --query 'Metadata.checksum' --output text)
    echo "$checksum  $file" >> /tmp/checksums.txt
  done

# Upload checksums
aws s3 cp /tmp/checksums.txt s3://spark-data/checksums/
```

### 2. Enable Data Validation in Spark

```scala
// Add validation to Spark jobs
val df = spark.read.parquet("s3a://spark-data/production/fact_table")

// Enable checksum validation
spark.conf.set("spark.sql.parquet.enableChecksumValidation", "true")

// Enable schema validation
spark.conf.set("spark.sql.parquet.respectSummaryFiles", "false")

// Validate data quality
val validationRules = Map(
  "id_not_null" -> "id IS NOT NULL",
  "amount_positive" -> "amount > 0",
  "date_valid" -> "dt BETWEEN '2020-01-01' AND '2026-12-31'"
)

validationRules.foreach { case (name, rule) =>
  val violations = df.filter(rule).count()
  if (violations > 0) {
    throw new Exception(s"Data quality violation $name: $violations records")
  }
}
```

### 3. Implement Pre-commit Validation

```bash
# Add to Spark job lifecycle
pre-commit:
  - validate-schema
  - validate-checksums
  - validate-data-quality
  - store-checksums

# Example
scripts/data-quality/validate-spark-output.sh \
  --path s3a://spark-data/production/fact_table/dt=2026-02-11/ \
  --schema /schemas/fact_table.json
```

### 4. Enable Replication

```bash
# Enable cross-region replication
aws s3api put-bucket-replication \
  --bucket spark-data \
  --replication-configuration file://replication.json

# Configure replication.json
{
  "Role": "arn:aws:iam::123456789012:role/s3-replication",
  "Rules": [
    {
      "Status": "Enabled",
      "Priority": 1,
      "Filter": {},
      "Destination": {
        "Bucket": "arn:aws:s3:::spark-data-dr"
      }
    }
  ]
}
```

### 5. Monitor Data Quality

```yaml
# CronJob for daily validation
apiVersion: batch/v1
kind: CronJob
metadata:
  name: data-integrity-check
  namespace: spark-operations
spec:
  schedule: "0 4 * * *"  # 4 AM UTC
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: validator
            image: spark:3.5.0
            command:
            - /scripts/operations/recovery/verify-data-integrity.sh
            - --bucket
            - spark-data
            - --full-validation
```

---

## Monitoring

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `data_validation_failures_total` | Validation failures | > 0 |
| `checksum_mismatches_total` | Checksum errors | > 0 |
| `data_corrupted_files_total` | Corrupted files | > 0 |
| `schema_drift_total` | Schema changes | > 0 |
| `data_quality_violations_total` | Quality rule failures | > 100 |

### Grafana Dashboard Queries

```promql
# Data validation status
data_validation_status

# Checksum verification rate
rate(checksum_verifications_total[5m])

# Corrupted file count
data_corrupted_files_total

# Schema drift detection
data_schema_drift_detected

# Data quality score
data_quality_score{table="fact_table"}

# Validation failure rate by table
rate(data_validation_failures_total{table="fact_table"}[5m])
```

---

## Escalation

### Escalation Path

1. **Level 1**: Operations Team (initial diagnosis, 15 min SLA)
2. **Level 2**: Data Engineering Team (recompute jobs, 1 hour SLA)
3. **Level 3**: Data Quality Team (schema issues, 4 hour SLA)
4. **Level 4**: Data Steward (data impact decisions, 24/7 on-call)

### Contact Information

| Team | Contact | Availability |
|------|---------|---------------|
| Operations | `#ops-team` | 24/7 |
| Data Engineering | `#data-team` | Business hours |
| Data Quality Team | `#data-quality` | Business hours |
| Data Steward | `#data-steward` | Business hours |

---

## Related Runbooks

- [Hive Metastore Restore](./hive-metastore-restore.md)
- [S3 Object Restore](./s3-object-restore.md)
- [Restore Procedure](../../procedures/backup-dr/restore-procedure.md)

---

## References

- [Parquet File Format](https://parquet.apache.org/docs/file-format/)
- [ORC File Format](https://orc.apache.org/specification/)
- [S3 Checksums](https://docs.aws.amazon.com/AmazonS3/latest/userguide/checking-object-integrity.html)
