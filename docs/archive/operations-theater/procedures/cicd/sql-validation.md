# SQL Validation Procedure

## Overview

This procedure defines the validation process for Spark SQL queries, including syntax checking, schema validation, and query plan analysis.

## Validation Types

### 1. Syntax Validation

**Purpose**: Catch syntax errors before deployment

**Tools**:
- Spark SQL parser
- `spark-sql --driver-memory 1g -e "EXPLAIN <query>"`

**Process**:
```bash
# Validate SQL syntax
spark-sql --driver-memory 1g -e "EXPLAIN $(cat query.sql)"

# Exit code 0 = valid, non-zero = invalid
```

**Common Syntax Errors**:
- Missing commas in SELECT list
- Unmatched parentheses
- Invalid table names
- Invalid function names
- Missing GROUP BY columns

---

### 2. Schema Validation

**Purpose**: Ensure queries reference valid tables and columns

**Tools**:
- Hive Metastore API
- `spark.catalog.tableExists()`
- `spark.sql().schema`

**Process**:
```bash
# Validate schema against Hive Metastore
scripts/cicd/validate-sql-schema.sh --file query.sql --catalog hive
```

**Checks**:
- Table exists
- Column exists in table
- Data type compatible
- Partition columns valid

---

### 3. Query Plan Analysis

**Purpose**: Identify anti-patterns and performance issues

**Tools**:
- Spark Explain
- Query Plan Analyzer

**Process**:
```bash
# Analyze query plan
scripts/cicd/analyze-sql-plan.sh --file query.sql --format json
```

**Anti-Patterns Detected**:
- **Cartesian products**: CROSS JOIN without ON condition
- **Skewed joins**: Large table join with large table
- **Too many stages**: > 200 stages
- **Broadcast threshold**: Broadcasting > 2GB tables
- **Shuffle spill**: Spill to disk detected
- **Missing filters**: No filter on large tables
- **Subquery explosion**: Many nested subqueries

---

## Validation Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                     SQL Validation Pipeline                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SQL File                                                       │
│     │                                                           │
│     ▼                                                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  1. Syntax Validation                                    │  │
│  │     - Parse SQL using Spark parser                       │  │
│  │     - Check for syntax errors                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│     │                                                           │
│     ▼                                                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  2. Schema Validation                                    │  │
│  │     - Check table existence                               │  │
│  │     - Check column existence                              │  │
│  │     - Validate data types                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│     │                                                           │
│     ▼                                                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  3. Query Plan Analysis                                  │  │
│  │     - Analyze Spark query plan                            │  │
│  │     - Detect anti-patterns                                │  │
│  │     - Estimate resource usage                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│     │                                                           │
│     ▼                                                           │
│  Report Generated                                               │
│  - Syntax errors                                               │
│  - Schema issues                                               │
│  - Performance warnings                                         │
│  - Recommendations                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Validation Script

### `scripts/cicd/validate-spark-sql.sh`

```bash
#!/bin/bash
set -euo pipefail

SQL_FILE="${1:-}"
CATALOG="${2:-hive}"

if [[ -z "$SQL_FILE" ]]; then
    echo "Usage: $0 <sql-file> [catalog]"
    exit 1
fi

echo "Validating SQL: $SQL_FILE"

# Syntax validation
echo "1. Syntax validation..."
if spark-sql --driver-memory 1g -e "EXPLAIN $(cat "$SQL_FILE")" 2>&1 | grep -i "error"; then
    echo "Syntax validation FAILED"
    exit 1
else
    echo "Syntax validation PASSED"
fi

# Schema validation
echo "2. Schema validation..."
python3 - <<EOF
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("SQLValidator").enableHiveSupport().getOrCreate()

with open("$SQL_FILE", 'r') as f:
    sql = f.read()

try:
    df = spark.sql(sql)
    print("Schema validation PASSED")
except Exception as e:
    print(f"Schema validation FAILED: {e}")
    exit(1)
EOF

# Query plan analysis
echo "3. Query plan analysis..."
spark-submit scripts/cicd/analyze-sql-plan.py --file "$SQL_FILE"

echo "Validation complete!"
```

---

## Anti-Pattern Reference

### Cartesian Product

**Problem**: CROSS JOIN without condition

**Example**:
```sql
-- BAD: Cartesian product
SELECT * FROM table1, table2

-- GOOD: Explicit join with condition
SELECT * FROM table1 JOIN table2 ON table1.id = table2.id
```

**Detection**: Query plan contains `CartesianProduct`

---

### Skewed Join

**Problem**: Joining two large tables

**Example**:
```sql
-- BAD: Large table join large table
SELECT * FROM huge_table1 JOIN huge_table2 ON id

-- GOOD: Broadcast smaller table
SELECT /*+ BROADCAST(table2) */ * FROM huge_table1 JOIN table2 ON id
```

**Detection**: Query plan has `SortMergeJoin` on two large inputs

---

### Broadcast Too Large

**Problem**: Broadcasting table > broadcast threshold

**Example**:
```sql
-- BAD: Broadcasting huge table
SELECT /*+ BROADCAST(huge_table) */ * FROM huge_table JOIN small_table ON id

-- GOOD: Don't broadcast huge table
SELECT * FROM huge_table JOIN small_table ON id
```

**Detection**: Broadcast hint on table > 2GB

---

### Too Many Stages

**Problem**: Complex query with many stages

**Example**:
```sql
-- BAD: Many nested subqueries
SELECT ... FROM (
  SELECT ... FROM (
    SELECT ... FROM (
      SELECT ... FROM table
    )
  )
)

-- GOOD: Use CTEs or temp views
WITH cte1 AS (SELECT ... FROM table),
     cte2 AS (SELECT ... FROM cte1)
SELECT ... FROM cte2
```

**Detection**: Query plan has > 200 stages

---

## CI Integration

### GitHub Actions

```yaml
sql-validation:
  name: SQL Validation
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3

    - name: Set up Spark
      uses: ./.github/actions/setup-spark

    - name: Validate SQL files
      run: |
        for sql_file in $(find . -name "*.sql"); do
          scripts/cicd/validate-spark-sql.sh "$sql_file"
        done

    - name: Upload validation report
      uses: actions/upload-artifact@v3
      with:
        name: sql-validation-report
        path: reports/sql-validation.json
```

---

## Common Issues and Fixes

### Issue: Table Not Found

**Error**: `Table or view not found: table_name`

**Fixes**:
1. Check database context: `USE database_name;`
2. Check table exists: `SHOW TABLES;`
3. Use qualified name: `database.table`

### Issue: Column Ambiguity

**Error**: `Reference 'column_name' is ambiguous`

**Fixes**:
1. Use table alias: `SELECT t1.column_name FROM table1 t1`
2. Use qualified names: `SELECT table1.column_name FROM table1`

### Issue: Type Mismatch

**Error**: `Cannot resolve 'column_name' due to data type mismatch`

**Fixes**:
1. Cast explicitly: `CAST(column_name AS INT)`
2. Use compatible types
3. Check schema: `DESCRIBE table_name`

---

## Best Practices

### 1. Use CTEs for Readability

```sql
-- GOOD: Common Table Expressions
WITH filtered AS (
  SELECT * FROM table WHERE date > '2026-01-01'
),
aggregated AS (
  SELECT user_id, COUNT(*) as cnt FROM filtered GROUP BY user_id
)
SELECT * FROM aggregated WHERE cnt > 10
```

### 2. Explicitly Specify Columns

```sql
-- GOOD: Explicit columns
SELECT user_id, name, email FROM users

-- BAD: SELECT *
SELECT * FROM users
```

### 3. Use Appropriate Joins

```sql
-- INNER JOIN: Only matching rows
SELECT * FROM table1 INNER JOIN table2 ON id

-- LEFT JOIN: All from left, matching from right
SELECT * FROM table1 LEFT JOIN table2 ON id

-- CROSS JOIN: Cartesian product (use with caution)
SELECT * FROM table1 CROSS JOIN table2
```

### 4. Filter Early

```sql
-- GOOD: Filter before join
SELECT * FROM (
  SELECT * FROM large_table WHERE date = '2026-02-11'
) t1
JOIN small_table t2 ON t1.id = t2.id

-- BAD: Filter after join
SELECT * FROM large_table t1
JOIN small_table t2 ON t1.id = t2.id
WHERE t1.date = '2026-02-11'
```

---

## Related Procedures

- [Job CI/CD Pipeline](./job-cicd-pipeline.md)
- [Python Validation](./python-validation.md)
- [Scala Validation](./scala-validation.md)

## References

- [Spark SQL Guide](https://spark.apache.org/docs/latest/sql-programming-guide.html)
- [Query Execution](https://spark.apache.org/docs/latest/sql-performance-tuning.html)
