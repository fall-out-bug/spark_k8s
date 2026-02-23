# Dataset README Template

Этот template используется для документирования всех datasets в Spark K8s Constructor deployment.

---

# `{dataset_name}` Dataset

## Overview

**Description:** {Brief description of the dataset}

**Owner:** {Team or individual responsible}

**Contact:** {Email or Slack channel}

**Status:** {Development | Staging | Production}

**Last Updated:** {YYYY-MM-DD}

---

## Table Information

**Database:** `{database_name}`

**Table:** `{table_name}`

**Table Type:** {Fact | Dimension | Transaction | Aggregated}

**Location:** `s3a://bucket/{path_to_table}`

**Format:** {Delta | Parquet | ORC | JSON | CSV}

**Partitioning:** {year={YYYY}/month={MM}/day={DD} | None}

**Size:** {Approximate size, e.g., ~500GB}

---

## Schema

| Column Name | Type | Description | Nullable | Source |
|-------------|------|-------------|----------|--------|
| {column_1} | {string|integer|timestamp|...} | {Description} | {Yes|No} | {Source column} |
| {column_2} | {string|integer|timestamp|...} | {Description} | {Yes|No} | {Source column} |
| ... | ... | ... | ... | ... |

### Primary Key(s)

- `{column_name}` — {Description}

### Foreign Key(s)

- `{column_name}` → `{referenced_table}`.{`referenced_column`}

---

## Data Lineage

### Upstream Sources

```
{Source System 1}
  ↓ (ETL Job: {job_name})
{Staging Table}
  ↓ (Transformation: {description})
{This Table}
```

| Source | Type | Frequency | Path |
|--------|------|-----------|------|
| {source_1} | {System/API/File} | {Real-time/Hourly/Daily} | {s3a://...} |
| {source_2} | {System/API/File} | {Real-time/Hourly/Daily} | {s3a://...} |

### Downstream Consumers

| Consumer | Type | Contact | Purpose |
|----------|------|---------|---------|
| {table_or_job_1} | {Table/Report/Dashboard/Model} | {Contact} | {Purpose} |
| {table_or_job_2} | {Table/Report/Dashboard/Model} | {Contact} | {Purpose} |

---

## Transformations

### Data Processing Steps

1. **{Step 1}**
   - Description: {What happens}
   - Code: {Reference to ETL job or SQL}
   - Output: {Intermediate table or files}

2. **{Step 2}**
   - Description: {What happens}
   - Code: {Reference to ETL job or SQL}
   - Output: {Intermediate table or files}

3. **...**
   - ...

### Business Rules

- **{Rule 1}**: {Description}
  - Example: {Concrete example}
  - SQL: `SELECT ... WHERE ...`

- **{Rule 2}**: {Description}
  - Example: {Concrete example}
  - SQL: `SELECT ... WHERE ...`

---

## Data Quality

### Quality Checks

| Check | Type | Threshold | Current Status | Notes |
|-------|------|-----------|----------------|-------|
| {check_name_1} | {Completeness|Uniqueness|Validity|Timeliness} | {> X% | = 0 | ...} | {Passing/Failing} | {Notes} |
| {check_name_2} | {Completeness|Uniqueness|Validity|Timeliness} | {> X% | = 0 | ...} | {Passing/Failing} | {Notes} |

### Known Data Issues

| Issue | Impact | Mitigation | Status |
|-------|--------|------------|--------|
| {description} | {High/Medium/Low} | {Workaround or fix} | {Open/In Progress/Resolved} |

---

## Access & Security

### Access Permissions

| Group/User | Permissions | Purpose | Granted By | Date |
|------------|-------------|---------|------------|------|
| {group_name} | {SELECT|INSERT|UPDATE|DELETE|ALL} | {Purpose} | {Who granted} | {YYYY-MM-DD} |

### Sensitive Data

| Column | Sensitivity Level | Masking Applied | Access Restrictions |
|--------|------------------|-----------------|-------------------|
| {column_name} | {PII|PHI|Financial|Confidential|Public} | {Yes/No - describe} | {Who can access} |

---

## Refresh & Availability

### Refresh Schedule

- **Frequency:** {Real-time/Hourly/Daily/Weekly/Monthly}
- **Schedule:** {Cron expression or time, e.g., 02:00 UTC daily}
- **ETL Job:** {Job name that creates/updates this table}
- **SLA:** {Data available by HH:MM UTC}

### Historical Retention

- **Retention Period:** {e.g., 2 years}
- **Archive Location:** {e.g., Cold storage / Glacier}
- **Purge Policy:** {e.g., Data older than 2 years deleted quarterly}

---

## Usage Examples

### SQL Queries

```sql
-- Example 1: Basic query
SELECT
    column1,
    column2,
    COUNT(*) as record_count
FROM {database}.{table}
WHERE date >= CURRENT_DATE - INTERVAL '7' DAY
GROUP BY column1, column2;

-- Example 2: Join with dimension table
SELECT
    f.*,
    d.attribute_name
FROM {database}.{table} f
LEFT JOIN {database}.{dimension_table} d
    ON f.foreign_key = d.primary_key
WHERE f.partition_column = '2026-01-28';
```

### Spark (PySpark)

```python
from pyspark.sql import functions as F

# Read table
df = spark.read.format("delta") \
    .load("s3a://bucket/{table_path}")

# Filter and aggregate
result = df.filter(F.col("date") == "2026-01-28") \
    .groupBy("column1") \
    .agg(F.sum("column2").alias("total"))

# Show result
result.show()
```

---

## Performance Notes

### Query Performance

- **Typical Query Time:** {e.g., 5-10 seconds for 1 day of data}
- **Optimizations:** {e.g., Z-ORDER by column, cached in memory}
- **Known Slow Queries:** {List any known performance issues}

### Cost Considerations

- **Compute Cost:** {Approximate cost per query}
- **Storage Cost:** {Approximate storage cost}
- **Optimization Tips:** {Tips for reducing query costs}

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| {YYYY-MM-DD} | {1.0 | 1.1 | ...} | {Description of changes} | {Who made changes} |

---

## Support & Troubleshooting

### Common Issues

| Issue | Symptoms | Solution | Contact |
|-------|----------|----------|---------|
| {Issue 1} | {What you see} | {How to fix} | {Who to contact} |
| {Issue 2} | {What you see} | {How to fix} | {Who to contact} |

### Getting Help

- **Documentation:** {Link to relevant docs}
- **Slack Channel:** {#channel-name}
- **Email:** {support@company.com}
- **On-Call:** {On-call rotation for critical issues}

---

## Related Resources

- **ETL Job:** {Link to job code or repo}
- **Dashboard:** {Link to Grafana/looker dashboard}
- **Documentation:** {Link to related docs}
- **Schema Registry:** {Link if applicable}
- **Data Dictionary:** {Link to business glossary}

---

## Tags

{Tags for searchability, e.g.}

- `sales`
- `transactions`
- `production`
- `piidata`
- `finance`
- `daily`

---

## Appendix

### Sample Data

| column1 | column2 | column3 |
|---------|---------|---------|
| {example_1} | {example_2} | {example_3} |
| {example_1} | {example_2} | {example_3} |

### Business Glossary

- **{Term 1}**: {Definition}
- **{Term 2}**: {Definition}

### Related Datasets

- `{dataset_1}` — {Relationship description}
- `{dataset_2}` — {Relationship description}

---

**README Template Version:** 1.0
**Last Updated:** 2026-01-28
**Maintained By:** Data Governance Team
