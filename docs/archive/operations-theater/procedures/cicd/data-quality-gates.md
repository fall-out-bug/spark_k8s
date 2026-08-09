# Data Quality Gates

> **Last Updated:** 2026-02-13
> **Owner:** Platform Team
> **Related:** [Job CI/CD Pipeline](./job-cicd-pipeline.md), [SQL Validation](./sql-validation.md)

## Overview

Data quality gates ensure that data meets quality standards before Spark jobs process it in production. This prevents data quality issues from propagating downstream.

## Quality Dimensions

### 1. Completeness

**Definition:** All required data is present

**Checks:**
- No null values in required columns
- Row counts within expected ranges
- No missing partitions

**Implementation:**
```sql
-- Check for nulls
SELECT COUNT(*) FROM table WHERE required_column IS NULL;

-- Expected: 0 rows
```

### 2. Accuracy

**Definition:** Data values are correct

**Checks:**
- Numeric values within valid ranges
- Dates are logical (not in future/past)
- Referential integrity maintained

**Implementation:**
```sql
-- Check for values outside valid range
SELECT COUNT(*) FROM metrics WHERE value < 0 OR value > 1000000;
```

### 3. Consistency

**Definition:** Data is consistent across sources

**Checks:**
- No duplicate records
- Aggregate calculations consistent
- Join keys exist in all tables

**Implementation:**
```sql
-- Check for duplicates
SELECT key, COUNT(*) FROM table GROUP BY key HAVING COUNT(*) > 1;
```

### 4. Timeliness

**Definition:** Data is fresh enough for use

**Checks:**
- Data updated within expected window
- No stale partitions
- Lag within acceptable limits

**Implementation:**
```sql
-- Check data freshness
SELECT MAX(updated_at) FROM table;
-- Expected: Within last 24 hours
```

### 5. Uniqueness

**Definition:** No duplicate primary keys

**Checks:**
- Primary key constraints satisfied
- Natural keys unique

**Implementation:**
```sql
-- Check primary key uniqueness
SELECT COUNT(*) - COUNT(DISTINCT pk_column) FROM table;
-- Expected: 0
```

## Great Expectations Integration

### Expectation Suite Example

```python
import great_expectations as ge
from great_expectations.core import ExpectationSuite

# Create expectation suite
suite = ExpectationSuite("spark_data_quality")

# Add expectations
suite.add_expectation(
    ge.expect_column_values_to_not_be_null(
        column="user_id",
        mostly=0.99  # 99% not null
    )
)

suite.add_expectation(
    ge.expect_column_values_to_be_between(
        column="revenue",
        min_value=0,
        max_value=1000000
    )
)

suite.add_expectation(
    ge.expect_column_values_to_match_regex(
        column="email",
        regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    )
)
```

### Running Validation

```bash
scripts/cicd/run-data-quality-checks.sh \
  --suite great_expectations/expectations/spark_data_suite.json \
  --data-source s3a://spark-data/cleaned/
```

## CI/CD Integration

### Pre-Deployment Checks

```yaml
- name: Data Quality Checks
  run: |
    ./scripts/cicd/run-data-quality-checks.sh \
      --suite data-quality-expectations.json

- name: Promote if quality passes
  if: success()
  run: |
    ./scripts/cicd/promote-job.sh --to staging
```

### Quality Gate Rules

| Quality Level | Completeness | Accuracy | Timeliness | Action |
|--------------|--------------|----------|------------|--------|
| **Production** | >99.9% | >99.5% | <1h lag | Deploy |
| **Staging** | >99% | >99% | <4h lag | Test |
| **Development** | >95% | >95% | <24h lag | Develop |
| **Failed** | <95% | <95% | >24h lag | Block |

## Automated Enforcement

### Blocking on Quality Failures

```bash
#!/bin/bash
# Data quality gate for CI/CD

QUALITY_RESULT=$(./scripts/cicd/run-data-quality-checks.sh --suite critical.json)

if echo "$QUALITY_RESULT" | grep -q "failed"; then
    echo "Critical quality checks failed!"
    echo "Review: $QUALITY_RESULT"

    # Check if any critical failures
    if echo "$QUALITY_RESULT" | grep -q "critical.*failed"; then
        echo "Blocking deployment due to critical failures"
        exit 1
    fi
fi

echo "Quality checks passed, proceeding with deployment"
```

## Monitoring

### Quality Metrics Dashboard

Track in Grafana:
- Data quality pass rate
- Failed expectations by type
- Data freshness by source
- Quality trend over time

### Alerts

```yaml
- alert: DataQualityCritical
  expr: data_quality_pass_rate < 0.95
  for: 5m
  annotations:
    summary: "Data quality below 95% for {{ $labels.dataset }}"
```

## Troubleshooting

### Quality Check Failures

**Symptom:** Quality checks fail consistently

**Diagnosis:**
1. Review expectation definitions
2. Check data source quality
3. Review data pipeline for issues

**Resolution:**
- Adjust expectations if unrealistic
- Fix upstream data quality issues
- Add data cleaning steps

### False Positives

**Symptom:** Quality checks fail but data looks correct

**Diagnosis:**
1. Review expectation logic
2. Check edge cases in data
3. Validate test data

**Resolution:**
- Update expectations to handle edge cases
- Add sample data to expectations
- Use "mostly" parameter for tolerances

## Best Practices

1. **Start small:** Begin with a few critical expectations
2. **Iterate:** Add expectations based on incidents
3. **Monitor trends:** Track quality over time
4. **Document:** Document expectation rationale
5. **Review:** Regularly review expectation relevance

## References

- [Great Expectations Documentation](https://docs.greatexpectations.io/)
- [SQL Validation](./sql-validation.md)
- [Job CI/CD Pipeline](./job-cicd-pipeline.md)
