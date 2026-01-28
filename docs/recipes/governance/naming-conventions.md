# Naming Conventions Guide

## Overview

Этот guide описывает стандарты именования для всех объектов в Spark K8s Constructor deployment.

## Principles

1. **Consistency** — One naming pattern across all environments
2. **Clarity** — Names should be self-documenting
3. **Discoverability** — Easy to find related objects
4. **Hierarchy** — Reflect organizational structure

## Database Naming

### Pattern

```
{environment}.{domain}.{entity}
```

### Environments

| Environment | Prefix | Purpose |
|-------------|--------|---------|
| Development | `dev_` | Local development and testing |
| Staging | `staging_` | Pre-production testing |
| Production | `prod_` | Production data |

### Domains

| Domain | Description | Examples |
|--------|-------------|----------|
| `raw` | Unprocessed source data | `dev_raw_pos_transactions` |
| `staging` | Cleaned but not transformed | `staging_sales_clean` |
| `analytics` | Aggregated for reporting | `prod_analytics_daily_sales` |
| `ml` | Machine learning features/models | `prod_ml_customer_features` |
| `reference` | Reference data (lookup tables) | `prod_reference_products` |
| `governance` | Metadata and audit data | `prod_governance_data_lineage` |

### Examples

```sql
-- Good names
dev_raw_sales_transactions
staging_marketing_campaigns
prod_analytics_daily_revenue
prod_ml_customer_churn_features
prod_reference_postal_codes
prod_governance_access_log

-- Bad names (avoid)
sales  -- No environment or domain
daily  -- Too vague
temp   -- No indication of purpose
test123  -- Uninformative
```

## Table Naming

### Pattern

```
{domain}_{business_entity}_{granularity?}_{suffix?}
```

### Granularity Suffixes

| Suffix | Description | Example |
|--------|-------------|---------|
| `_daily` | Daily aggregated data | `analytics_sales_daily` |
| `_weekly` | Weekly aggregated data | `analytics_sales_weekly` |
| `_monthly` | Monthly aggregated data | `analytics_sales_monthly` |
| `_hourly` | Hourly aggregated data | `iot_readings_hourly` |
| *(no suffix)* | Transaction-level data | `raw_transactions` |

### Table Type Suffixes

| Suffix | Description | Example |
|--------|-------------|---------|
| `_fact` | Fact table (star schema) | `analytics_sales_fact` |
| `_dim` | Dimension table (star schema) | `analytics_customer_dim` |
| `_bridge` | Bridge table (many-to-many) | `analytics_customer_product_bridge` |
| `_snapshot` | Period snapshot (SCD2) | `inventory_snapshot` |

### Examples

```sql
-- Fact tables
prod_analytics_sales_fact
dev_analytics_web_traffic_fact

-- Dimension tables
prod_analytics_customer_dim
prod_analytics_product_dim
prod_analytics_store_dim

-- Bridge tables
prod_analytics_customer_campaign_bridge

-- Transaction tables
staging_sales_transactions
prod_marketing_email_clicks

-- Snapshot tables
prod_inventory_snapshot  -- Monthly inventory state
```

## Column Naming

### Pattern

```
{entity}_{attribute}_{qualifier?}
```

### Rules

1. **snake_case** — Always use lowercase with underscores
2. **Descriptive** — Column name should indicate content
3. **Typed suffixes** — Include type for clarity

### Type Suffixes

| Suffix | Type | Example |
|--------|------|---------|
| `_id` | Identifier (string or int) | `customer_id` |
| `_key` | Foreign key | `product_key` |
| `_code` | Categorical code | `country_code` |
| `_flag` | Boolean flag | `is_active_flag` |
| `_cnt` | Count integer | `transaction_cnt` |
| `_amt` | Monetary amount | `revenue_amt` |
| `_pct` | Percentage (decimal 0-1) | `conversion_pct` |
| `_ts` | Timestamp | `created_ts` |
| `_date` | Date (no time) | `transaction_date` |
| `_nm` | Name (string) | `customer_nm` |
| `_desc` | Description (string) | `product_desc` |
| `_url` | URL string | `product_image_url` |
| `_email` | Email address | `customer_email` |

### Examples

```sql
-- Identifiers
transaction_id
customer_id
product_key

-- Metrics
revenue_amt
quantity_cnt
discount_pct
is_purchased_flag

-- Attributes
customer_first_nm
product_desc
transaction_ts
order_date
```

### Reserved Words (Avoid)

```sql
-- Avoid SQL reserved words as column names
-- Instead of:
date, time, timestamp, user, order, group

-- Use:
order_date, event_time, transaction_ts, app_user, purchase_order, customer_group
```

## View Naming

### Pattern

```
vw_{domain}_{purpose}
```

### Examples

```sql
-- Materialized views (future Spark feature)
mvw_analytics_daily_revenue

-- Regular views
vw_staging_valid_customers
vw_ml_training_dataset
vw_analytics_current_quarter
```

## Job Naming

### Pattern

```
{environment}_{domain}_{action}_{entity}_{frequency}
```

### Frequency Suffixes

| Suffix | Description | Example |
|--------|-------------|---------|
| `_batch_1min` | Every minute | `etl_raw_ingest_batch_1min` |
| `_batch_5min` | Every 5 minutes | `etl_raw_ingest_batch_5min` |
| `_batch_hourly` | Every hour | `etl_staging_normalize_batch_hourly` |
| `_batch_daily` | Every day | `etl_analytics_aggregate_batch_daily` |
| `_batch_weekly` | Every week | `analytics_sales_report_batch_weekly` |
| `_batch_monthly` | Every month | `analytics_compliance_batch_monthly` |
| `_adhoc` | One-time or manual | `migration_historical_load_adhoc` |

### Examples

```bash
# ETL jobs
etl_raw_pos_ingest_batch_hourly
etl_staging_sales_normalize_batch_daily
etl_analytics_revenue_aggregate_batch_daily

# ML jobs
ml_feature_engineering_batch_daily
ml_model_training_batch_weekly
ml_scoring_batch_hourly

# Data quality jobs
dq_validation_batch_daily
dq_profiling_batch_weekly
```

## Path Naming (S3/GCS)

### Pattern

```
s3a://{bucket}/{environment}/{domain}/{entity}/{date_partition?}
```

### Examples

```
s3a://company-data/dev/raw/sales/transactions/2026/01/28/
s3a://company-data/staging/cleaned/marketing/campaigns/
s3a://company-data/prod/analytics/reports/daily/2026/01/28/
s3a://company-data/prod/ml/features/customer/
```

### Date Partitioning

Always use Hive-style partitioning:

```
s3a://.../table_name/year=2026/month=01/day=28/
s3a://.../table_name/year=2026/month=01/
s3a://.../table_name/year=2026/
```

## Kubernetes Resources

### Namespace Naming

```
{environment}-{project}
```

Examples:
```
dev-spark
staging-spark
prod-spark
```

### Deployment Naming

```
{component}-{environment}
```

Examples:
```
spark-connect-prod
spark-connect-staging
```

### ConfigMap Naming

```
{component}-{purpose}-{environment}
```

Examples:
```
spark-config-prod
spark-log4j2-prod
```

## File Naming

### SQL Migration Files

```
{version}_{description}_{environment}.sql
```

Examples:
```
001_create_sales_tables_prod.sql
002_add_customer_flags_prod.sql
003_drop_legacy_columns_prod.sql
```

### Notebook Files

```
{number}_{title}_{domain}.ipynb
```

Examples:
```
01_exploratory_analysis_sales.ipynb
02_feature_engineering_ml.ipynb
03_model_training_customer_churn.ipynb
```

## Variable Naming (Python/Scala)

### Python

```python
# Constants (UPPER_SNAKE_CASE)
MAX_EXECUTORS = 100
S3_BUCKET = "company-data"
DEFAULT_TIMEOUT = 300

# Variables (snake_case)
customer_id = "12345"
transaction_amount = 99.99
is_active = True

# Functions (snake_case)
def process_sales_data(raw_df):
    pass

def calculate_revenue_metrics(sales_df):
    pass

# Classes (PascalCase)
class SalesProcessor:
    pass

class CustomerFeatureExtractor:
    pass
```

### Scala

```scala
// Constants (camelCase with first letter uppercase)
val MaxExecutors = 100
val S3Bucket = "company-data"

// Variables (camelCase)
val customerId = "12345"
val transactionAmount = 99.99
val isActive = true

// Functions (camelCase)
def processSalesData(rawDf: DataFrame): Unit = {
  // ...
}

// Classes (PascalCase)
class SalesProcessor {
  // ...
}
```

## Environment-Specific Names

### Development

```
dev_{table/job}
```

- Use `dev_` prefix
- Can use simplified names
- Add `_test` for test data

### Staging

```
staging_{table/job}
```

- Use `staging_` prefix
- Same naming as production
- Test production-like behavior

### Production

```
prod_{table/job}
```

- Use `prod_` prefix
- Most formal naming
- No abbreviations

## Renaming Strategy

### When to Rename

1. **Inconsistent naming** — Fix immediately
2. **Ambiguous names** — Fix in next sprint
3. **Major refactoring** — Opportunistic rename

### Safe Renaming Process

```sql
-- 1. Create new table with correct name
CREATE TABLE prod_analytics_sales_daily_new AS
SELECT * FROM prod_analytics_sales_daily;

-- 2. Verify data
SELECT COUNT(*) FROM prod_analytics_sales_daily_new;

-- 3. Grant permissions
GRANT SELECT ON prod_analytics_sales_daily_new TO GROUP analysts;

-- 4. Update downstream consumers (views, jobs)

-- 5. Drop old table (after grace period)
DROP TABLE prod_analytics_sales_daily;
```

## Validation

### Naming Convention Checker

```python
import re

def validate_table_name(name):
    """Validate table name follows conventions"""
    pattern = r'^(dev|staging|prod)_(raw|staging|analytics|ml|reference|governance)_[a-z_]+$'
    if not re.match(pattern, name):
        raise ValueError(f"Invalid table name: {name}. Expected format: env_domain_name")

def validate_column_name(name):
    """Validate column name follows conventions"""
    pattern = r'^[a-z][a-z0-9_]*$'
    if not re.match(pattern, name):
        raise ValueError(f"Invalid column name: {name}. Use snake_case")

# Usage
validate_table_name("prod_analytics_sales_daily")  # OK
validate_table_name("sales")  # Raises ValueError
```

## Checklist

### New Database

- [ ] Environment prefix included
- [ ] Domain prefix included
- [ ] Purpose is clear from name

### New Table

- [ ] Follows pattern: domain_entity_granularity
- [ ] snake_case used
- [ ] No SQL reserved words
- [ ] Descriptive and concise

### New Column

- [ ] snake_case used
- [ ] Type suffix included (_id, _amt, _ts, etc.)
- [ ] Not a SQL reserved word
- [ ] Descriptive of content

### New Job

- [ ] Environment prefix included
- [ ] Domain/action included
- [ ] Frequency suffix included
- [ ] Descriptive of purpose

## References

- SQL Style Guide: https://www.sqlstyle.guide/
- Google SQL Convention Guide: https://google.github.io/styleguide/pyguide.html
- Python PEP 8: https://www.python.org/dev/peps/pep-0008/

---

**Governance Status:** Naming conventions documented.
