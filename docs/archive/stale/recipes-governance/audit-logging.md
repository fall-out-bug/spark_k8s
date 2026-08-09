# Audit Logging Guide

## Overview

Этот guide описывает настройку audit logging для Spark K8s Constructor deployment.

## What is Audit Logging?

Audit logging — запись всех операций с данными для compliance, security, и troubleshooting:

- **Who** accessed what data
- **When** access occurred
- **What** operations were performed
- **From where** access originated

## Spark Audit Logging

### Enable Audit Logging

```bash
# In spark-defaults.conf
spark.sql.audit.log.enabled=true
spark.sql.audit.log.path=s3a://audit/spark/
spark.sql.audit.log.format=json
spark.sql.audit.log.rotation.enabled=true
spark.sql.audit.log.rotation.size=100MB
```

### Audit Event Types

| Event Type | Description | Example |
|------------|-------------|---------|
| `createQuery` | Temporary view created | `CREATE TEMP VIEW sales_vw AS SELECT...` |
| `dropTable` | Table dropped | `DROP TABLE staging.temp_data` |
| `modifyTable` | Table schema altered | `ALTER TABLE...ADD COLUMN...` |
| `readTable` | Table data read | `SELECT * FROM production.sales` |
| `writeTable` | Data written to table | `INSERT INTO TABLE...` |
| `grantPrivilege` | Permissions granted | `GRANT SELECT ON...` |
| `revokePrivilege` | Permissions revoked | `REVOKE SELECT ON...` |

### Audit Log Format

```json
{
  "timestamp": "2026-01-28T12:34:56.789Z",
  "event_type": "readTable",
  "user": "alice@company.com",
  "database": "production",
  "table": "sales_transactions",
  "operation": "SELECT",
  "access_mode": "READ",
  "ip_address": "10.0.1.100",
  "session_id": "spark-1234567890",
  "query": "SELECT * FROM production.sales_transactions WHERE date >= '2026-01-01'"
}
```

### Configuring Audit Log Level

```bash
# Minimal audit (only writes)
spark.sql.audit.log.level=write

# Standard audit (reads + writes)
spark.sql.audit.log.level=read_and_write

# Comprehensive audit (all operations)
spark.sql.audit.log.level=all
```

## Metastore Audit Logging

### Hive Metastore Audit

```bash
# In hive-site.xml
<property>
  <name>hive.metastore.authentication.keystore.path</name>
  <value>/path/to/keystore</value>
</property>

<property>
  <name>hive.metastore.pre.event.listeners</name>
  <value>org.apache.hadoop.hive.ql.security.authorization.plugin.metastore.AuditMetastoreAlertNotifier</value>
</property>
```

### Metastore Audit Events

| Event | Description | Logged Fields |
|-------|-------------|---------------|
| `CREATE_DATABASE` | Database created | db_name, owner |
| `DROP_DATABASE` | Database dropped | db_name, user |
| `CREATE_TABLE` | Table created | db, table, owner |
| `DROP_TABLE` | Table dropped | db, table, user |
| `GRANT_PRIVILEGE` | Permission granted | privilege, grantee, grantor |
| `REVOKE_PRIVILEGE` | Permission revoked | privilege, user |

## Kubernetes Audit Logging

### Enable Kubernetes Audit

```yaml
# kube-apiserver audit policy
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
    verbs: ["get", "list", "watch"]
  - level: Request
    verbs: ["create", "update", "delete"]
    resources:
      - group: "sparkoperator.k8s.io"
        resources: ["sparkapplications"]
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets"]
        resourceNames: ["s3-credentials"]
```

### Kubernetes Audit Log Location

```bash
# Audit logs stored on master nodes
/var/log/kubernetes/audit/audit.log

# Or forward to centralized logging
kubectl logs -n kube-system kube-apiserver-master | grep audit
```

## Application-Level Audit Logging

### Custom Audit Logger

```python
from pyspark.sql import SparkSession
import json
from datetime import datetime

class AuditLogger:
    """Custom audit logger for Spark applications"""

    def __init__(self, spark, audit_path="s3a://audit/spark/"):
        self.spark = spark
        self.audit_path = audit_path
        self.app_id = spark.conf.get("spark.app.id")

    def log_event(self, event_type, details):
        """Log an audit event"""
        audit_record = {
            "timestamp": datetime.utcnow().isoformat(),
            "app_id": self.app_id,
            "event_type": event_type,
            "user": self.spark.conf.get("spark.user.name"),
            "details": details
        }

        # Write to audit log
        audit_df = self.spark.createDataFrame([audit_record])
        audit_df.write \
            .mode("append") \
            .json(f"{self.audit_path}{event_type}/")

    def log_read(self, table_name, query=None):
        """Log table read operation"""
        self.log_event("read", {
            "table": table_name,
            "query": query
        })

    def log_write(self, table_name, row_count):
        """Log table write operation"""
        self.log_event("write", {
            "table": table_name,
            "rows_written": row_count
        })

    def log_error(self, error_message, context):
        """Log error event"""
        self.log_event("error", {
            "message": error_message,
            "context": context
        })

# Usage
audit = AuditLogger(spark)

# Before reading
audit.log_read("production.sales_transactions")

# After writing
audit.log_write("analytics.daily_sales", row_count=1000000)

# On error
try:
    # ... operation ...
except Exception as e:
    audit.log_error(str(e), {"table": "production.sales"})
```

### DataFrame Listener

```python
from pyspark.sql.listener import *

class AuditListener(QueryExecutionListener):
    """Spark SQL query execution listener for audit"""

    def __init__(self, audit_logger):
        self.audit = audit_logger

    def onSuccess(self, funcName, qe, durationSecs):
        """Called when query succeeds"""
        tables = [t.tableIdentifier for t in qe.logicalPlan.collect()]
        for table in tables:
            if funcName == "command":
                self.audit.log_write(str(table), durationSecs)
            else:
                self.audit.log_read(str(table))

    def onFailure(self, funcName, qe, exception):
        """Called when query fails"""
        self.audit.log_error(str(exception), {
            "query": str(qe.logicalPlan)
        })

# Register listener
spark.sparkContext.addSparkListener(AuditListener(audit))
```

## Centralized Audit Storage

### S3 Audit Bucket Structure

```
s3a://audit/
├── spark/
│   ├── read/
│   │   └── year=2026/month=01/day=28/
│   ├── write/
│   └── error/
├── metastore/
│   ├── create_database/
│   ├── drop_table/
│   └── grant_privilege/
└── kubernetes/
    ├── sparkapplications/
    └── secrets/
```

### Retention Policy

```python
from datetime import datetime, timedelta

def cleanup_old_audit_logs(spark, retention_days=90):
    """Remove audit logs older than retention period"""
    cutoff_date = datetime.utcnow() - timedelta(days=retention_days)

    audit_paths = [
        "s3a://audit/spark/",
        "s3a://audit/metastore/",
        "s3a://audit/kubernetes/"
    ]

    for path in audit_paths:
        # List and delete old partitions
        df = spark.read.format("json").load(path)
        old_logs = df.filter(col("timestamp") < cutoff_date)
        count = old_logs.count()

        if count > 0:
            # Delete old files (implementation varies by storage)
            print(f"Deleting {count} old audit logs from {path}")
```

## Audit Query Examples

### Who Accessed a Table?

```sql
-- Recent table access
SELECT
    user,
    timestamp,
    ip_address,
    query
FROM spark_audit
WHERE table_name = 'production.sales_transactions'
  AND timestamp > CURRENT_TIMESTAMP - INTERVAL '7' DAY
ORDER BY timestamp DESC;
```

### Data Access by User

```sql
-- All tables accessed by user in last 30 days
SELECT
    table_name,
    COUNT(*) as access_count,
    MAX(timestamp) as last_access
FROM spark_audit
WHERE user = 'alice@company.com'
  AND timestamp > CURRENT_TIMESTAMP - INTERVAL '30' DAY
GROUP BY table_name
ORDER BY access_count DESC;
```

### Failed Access Attempts

```sql
-- Failed reads/writes (potential security issue)
SELECT
    timestamp,
    user,
    table_name,
    error_message
FROM spark_audit
WHERE event_type = 'error'
  AND timestamp > CURRENT_TIMESTAMP - INTERVAL '1' DAY
ORDER BY timestamp DESC;
```

### Permission Changes

```sql
-- Recent privilege grants/revokes
SELECT
    timestamp,
    user,
    operation,
    privilege,
    grantee
FROM metastore_audit
WHERE event_type IN ('grantPrivilege', 'revokePrivilege')
  AND timestamp > CURRENT_TIMESTAMP - INTERVAL '7' DAY;
```

## Compliance Reports

### GDPR Data Access Report

```sql
-- All access to customer PII data (for GDPR Article 15 - Right of Access)
SELECT
    timestamp,
    user,
    ip_address,
    table_name,
    query
FROM spark_audit
WHERE table_name IN (
    'production.customers',
    'production.customer_profiles',
    'production.customer_transactions'
)
  AND timestamp > CURRENT_TIMESTAMP - INTERVAL '12' MONTH
ORDER BY timestamp;
```

### SOX Financial Data Access

```sql
-- Financial data access (SOX compliance)
SELECT
    DATE_TRUNC('month', timestamp) as month,
    user,
    COUNT(*) as access_count,
    COUNT(DISTINCT table_name) as tables_accessed
FROM spark_audit
WHERE table_name LIKE '%sales%' OR table_name LIKE '%revenue%'
  AND timestamp > CURRENT_TIMESTAMP - INTERVAL '12' MONTH
GROUP BY DATE_TRUNC('month', timestamp), user
ORDER BY month DESC, access_count DESC;
```

## Alerting on Suspicious Activity

### Anomaly Detection

```python
from pyspark.sql.functions import col, count, when

def detect_suspicious_access(spark):
    """Detect potentially suspicious data access patterns"""

    # Load audit logs
    audit_df = spark.read.json("s3a://audit/spark/*")

    # Pattern 1: Bulk data export
    bulk_exports = audit_df.filter(col("rows_read") > 1000000)

    # Pattern 2: Access outside business hours
    outside_hours = audit_df.filter(
        (hour(col("timestamp")) < 6) |
        (hour(col("timestamp")) > 22)
    )

    # Pattern 3: Unusual table access for role
    # (requires role mapping)
    unusual_access = audit_df.filter(
        col("table_name").contains("admin")
    )

    # Pattern 4: Failed access attempts
    failed_attempts = audit_df.filter(
        col("event_type") == "error"
    ).groupBy(
        col("user"),
        window(col("timestamp"), "1 hour")
    ).agg(
        count("*").alias("failure_count")
    ).filter(
        col("failure_count") > 10
    )

    return {
        "bulk_exports": bulk_exports.collect(),
        "outside_hours": outside_hours.collect(),
        "unusual_access": unusual_access.collect(),
        "failed_attempts": failed_attempts.collect()
    }

# Run daily
suspicious = detect_suspicious_access(spark)
if suspicious["failed_attempts"]:
    # Send alert to security team
    send_security_alert(suspicious)
```

## Audit Log Integrity

### Checksum Verification

```python
import hashlib

def generate_audit_checksum(audit_log_path):
    """Generate SHA-256 checksum of audit log"""
    sha256 = hashlib.sha256()

    with open(audit_log_path, 'rb') as f:
        while True:
            data = f.read(65536)
            if not data:
                break
            sha256.update(data)

    return sha256.hexdigest()

# Store checksum with audit log
checksum = generate_audit_checksum("/var/log/audit/spark.log")
with open("/var/log/audit/spark.log.checksum", "w") as f:
    f.write(checksum)
```

### Immutable Storage

```bash
# Use WORM (Write Once, Read Many) storage for audit logs
# S3 Object Lock configuration

aws s3api put-object-lock-configuration \
  --bucket audit-logs \
  --object-lock-configuration \
    '{"ObjectLockEnabled":"Enabled","Rule":{"DefaultRetention":{"Mode":"COMPLIANCE","Days":90}}}'
```

## Performance Considerations

### Async Audit Logging

```python
import threading
import queue

class AsyncAuditLogger:
    """Non-blocking audit logger"""

    def __init__(self, spark, buffer_size=1000):
        self.spark = spark
        self.queue = queue.Queue(maxsize=buffer_size)
        self.running = True
        self.worker = threading.Thread(target=self._worker)
        self.worker.start()

    def log_event(self, event):
        """Queue event for async logging"""
        self.queue.put(event)

    def _worker(self):
        """Background thread to flush audit logs"""
        batch = []
        while self.running:
            try:
                event = self.queue.get(timeout=1)
                batch.append(event)

                if len(batch) >= 100:
                    self._flush(batch)
                    batch = []
            except queue.Empty:
                if batch:
                    self._flush(batch)

    def _flush(self, batch):
        """Write batch to audit log"""
        df = spark.createDataFrame(batch)
        df.write.mode("append").json("s3a://audit/spark/")

    def close(self):
        """Flush and stop"""
        self.running = False
        self.worker.join()
```

## Troubleshooting

### Missing Audit Logs

**Problem:** Expected audit events not found

**Solution:**
```bash
# Check audit logging is enabled
spark-conf | grep audit

# Check audit log path exists
aws s3 ls s3a://audit/spark/

# Check for write permissions
aws s3api get-bucket-policy --bucket audit-logs
```

### Performance Impact

**Problem:** Audit logging slowing down queries

**Solution:**
```bash
# Use async logging
spark.sql.audit.log.async.enabled=true

# Reduce log level
spark.sql.audit.log.level=write  # Only log writes, not reads

# Batch writes
spark.sql.audit.log.batch.size=100
```

## Security Checklist

### Initial Setup

- [ ] Audit logging enabled in all environments
- [ ] Audit logs stored in separate bucket
- [ ] Immutable storage configured (production)
- [ ] Retention policy defined (90 days minimum)
- [ ] Access to audit logs restricted to security team

### Ongoing Operations

- [ ] Daily audit log integrity checks
- [ ] Weekly compliance reports generated
- [ ] Monthly access reviews conducted
- [ ] Quarterly audit retention cleanup
- [ ] Annual security audit of audit logging system

### Incident Response

- [ ] Audit log preservation process defined
- [ ] Audit log export procedure documented
- [ ] Legal hold procedure for investigations
- [ ] Audit log chain of custody maintained

## References

- Spark Security: https://spark.apache.org/docs/latest/security.html
- Kubernetes Audit: https://kubernetes.io/docs/tasks/debug-application-cluster/audit/
- AWS CloudTrail: https://docs.aws.amazon.com/awscloudtrail/

---

**Governance Status:** Audit logging documented. Centralized SIEM integration deferred to future phases.
