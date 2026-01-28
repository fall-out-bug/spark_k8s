# Data Access Control Guide

## Overview

Этот guide описывает управление доступом к данным в Spark K8s Constructor deployment.

## Current State: Hive ACLs (Storage-Based Authorization)

### What Are Hive ACLs?

Hive ACLs (Access Control Lists) обеспечивают permission-based доступ к таблицам и databases на уровне storage (HDFS/S3).

### Enable Hive ACLs

```bash
# In spark-defaults.conf
spark.sql.hive.metastore.client.auth.mode=HIVE_CLI_AUTH
spark.sql.hive.metastore.client.auth.name=NONE
spark.sql.hive.security.authorization.enabled=true
spark.sql.hive.security.authorization.manager=org.apache.hadoop.hive.ql.security.authorization.StorageBasedAuthorizationProvider
spark.sql.hive.security.authenticator.manager=org.apache.hadoop.hive.ql.security.HadoopDefaultAuthenticator
```

### Grant Permissions

```sql
-- Grant SELECT on table
GRANT SELECT ON TABLE analytics.users TO GROUP data_science;

-- Grant ALL on database
GRANT ALL ON DATABASE analytics TO GROUP data_engineering;

-- Revoke permission
REVOKE SELECT ON TABLE analytics.users FROM GROUP data_science;
```

### Permission Levels

| Permission | Description |
|------------|-------------|
| `SELECT` | Read data from table |
| `INSERT` | Write data to table |
| `UPDATE` | Update existing rows (not common in data warehouses) |
| `DELETE` | Delete data from table |
| `CREATE` | Create new tables/views |
| `DROP` | Drop tables/views |
| `ALTER` | Modify table schema |
| `ALL` | All permissions |

### Best Practices

1. **Principle of Least Privilege**
   ```sql
   -- Start with SELECT only
   GRANT SELECT ON TABLE production.sales TO GROUP analysts;

   -- Add INSERT only if needed
   GRANT INSERT ON TABLE production.sales TO GROUP etl_jobs;
   ```

2. **Role-Based Access Control (RBAC)**
   ```sql
   -- Create groups for different teams
   -- Group: data_science (read-only access to analytics)
   -- Group: data_engineering (full access to staging)
   -- Group: platform_admins (full access to all)

   -- Grant permissions to groups, not individuals
   GRANT SELECT ON DATABASE analytics TO GROUP data_science;
   ```

3. **Separate Environments**
   ```sql
   -- Development: Open access
   GRANT ALL ON DATABASE dev_* TO GROUP all_users;

   -- Staging: Restricted to data engineering
   GRANT ALL ON DATABASE staging TO GROUP data_engineering;

   -- Production: Read-only for analysts
   GRANT SELECT ON DATABASE production TO GROUP analysts;
   GRANT ALL ON DATABASE production TO GROUP data_engineering_admins;
   ```

## Monitoring Access

### Audit Query

```sql
-- Check who has access to what
SELECT * FROM information_schema.table_privileges;

-- Check database-level grants
SHOW GRANT GROUP data_science ON DATABASE analytics;
```

### Regular Audits

```bash
# Export all grants
hive -e "SHOW GRANT;" > /tmp/hive_grants.csv

# Review regularly (monthly)
grep "production\." /tmp/hive_grants.csv | mail -s "Monthly Access Review" security@company.com
```

## Future: Apache Ranger

### What is Apache Ranger?

Apache Ranger — comprehensive security framework для Hadoop ecosystems с:
- Centralized administration
- Fine-grained access control (row/column level)
- Dynamic policy-based access
- Audit logging integration

### Migration Path

```
Current (Hive ACLs)           Future (Ranger)
┌─────────────────┐          ┌──────────────────────┐
│ Storage-based   │   ────>  │ Centralized policies │
│ Table-level     │          │ Row/Column level     │
│ Manual grants   │          │ Dynamic policies     │
└─────────────────┘          │ Audit integration    │
                              └──────────────────────┘
```

### Example Ranger Policies

```json
{
  "policyName": "analytics.pii.redaction",
  "resources": {
    "database": "analytics",
    "table": "users",
    "column": "email"
  },
  "policyItems": [
    {
      "accesses": [{"type": "SELECT"}],
      "users": ["data_science_team"],
      "dataMaskInfo": {
        "dataMaskType": "MASK",
        "maskExpr": "REPLACE(email, REGEXP_EXTRACT(email, '(@.*)$'), '***@***')"
      }
    }
  ]
}
```

### Ranger Deployment (Future)

```bash
# Install Ranger (not recommended for Phase 1)
helm install ranger apache/ranger -n governance --create-namespace

# Enable Ranger plugin for Spark
spark-submit \
  --conf spark.sql.catalogImplementation=hive \
  --conf spark.ranger.authentication.method=kerberos \
  --conf spark.ranger.resource.service.name=spark
```

## Common Patterns

### Pattern 1: Read-Only Analytics Access

```sql
-- Create read-only group
CREATE ROLE analytics_read_only;

-- Grant SELECT on all analytics tables
GRANT SELECT ON DATABASE analytics TO ROLE analytics_read_only;

-- Add users
GRANT ROLE analytics_read_only TO USER alice;
GRANT ROLE analytics_read_only TO USER bob;
```

### Pattern 2: Data Engineering Write Access

```sql
-- Create engineering group with full access
CREATE ROLE data_engineers;

-- Grant ALL on staging databases
GRANT ALL ON DATABASE staging TO ROLE data_engineers;
GRANT ALL ON DATABASE dev TO ROLE data_engineers;

-- Grant limited access to production
GRANT SELECT, INSERT ON DATABASE production TO ROLE data_engineers;
```

### Pattern 3: Cross-Environment Access

```sql
-- Development team needs access across environments
CREATE ROLE dev_team;

-- Dev: Full access
GRANT ALL ON DATABASE dev TO ROLE dev_team;

-- Staging: Read-only for debugging
GRANT SELECT ON DATABASE staging TO ROLE dev_team;

-- Production: No direct access (use promoted code only)
-- No GRANT for production
```

## Troubleshooting

### Permission Denied Errors

```
Error: Permission denied: USER=[alice] TABLE=[production.sales]
```

**Solution:**
```sql
-- Check current permissions
SHOW GRANT USER alice ON TABLE production.sales;

-- Grant required permission
GRANT SELECT ON TABLE production.sales TO USER alice;
```

### Metastore Connection Issues

```
Error: Unable to connect to Hive Metastore
```

**Solution:**
```bash
# Check metastore is running
kubectl get pods -n spark | grep metastore

# Verify authentication settings
kubectl exec -n spark spark-connect-0 -- cat /opt/spark/conf/hive-site.xml
```

## Security Checklist

### Initial Setup

- [ ] Hive ACLs enabled in Spark config
- [ ] Metastore authentication configured
- [ ] Initial permission grants reviewed
- [ ] Service accounts created for automated access

### Ongoing Maintenance

- [ ] Monthly access reviews
- [ ] Audit logs reviewed quarterly
- [ ] Offboarding process documented (revoke access when employees leave)
- [ ] New project access request process defined

### Pre-Production

- [ ] Production access restricted to minimum required users
- [ ] Automated jobs use service accounts (not personal credentials)
- [ ] Emergency access process documented
- [ ] Security incident response plan tested

## References

- Hive Security: https://cwiki.apache.org/confluence/display/Hive/SQL+Standard+Based+Hive+Authorization
- Apache Ranger: https://ranger.apache.org/
- Spark Security: https://spark.apache.org/docs/latest/security.html

---

**Governance Status:** Hive ACLs documented. Ranger implementation deferred to future phases.
