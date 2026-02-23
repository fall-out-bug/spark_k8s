# Airflow DAG Templates

This directory contains production-grade Airflow DAG templates for Spark K8s.

## Directory Structure

```
examples/airflow/
├── dags/
│   ├── production/           # Production-ready DAGs
│   │   ├── spark_etl_daily.py      # Daily ETL with retry/SLA/alerting
│   │   ├── spark_backfill.py       # Idempotent backfill DAG
│   │   └── spark_data_quality.py   # DQ checks (row count, nulls, freshness)
│   └── examples/             # Example DAGs (not for production)
└── README.md
```

## DAG Patterns

### 1. Daily ETL (`spark_etl_daily.py`)

**Use case:** Daily batch processing pipeline

**Features:**
- Retry logic: 3x with exponential backoff
- SLA: 2 hours
- Failure alerts: Email + Slack
- Execution timeout: 2 hours per task

**Usage:**
```bash
# Deploy to Airflow
cp dags/production/spark_etl_daily.py $AIRFLOW_HOME/dags/

# Configure variables
airflow variables set s3_access_key "your-key"
airflow variables set s3_secret_key "your-secret"
```

### 2. Backfill (`spark_backfill.py`)

**Use case:** Historical data backfill

**Features:**
- Idempotent: re-running same date produces same result
- Manual trigger with date range
- Parallel execution support (max 3 concurrent)

**Usage:**
```bash
# Trigger with parameters
airflow dags trigger spark_backfill \
  --conf '{"start_date": "2024-01-01", "end_date": "2024-12-31"}'
```

### 3. Data Quality (`spark_data_quality.py`)

**Use case:** Automated data quality monitoring

**Features:**
- Row count validation
- Null percentage check
- Data freshness validation
- Automated DQ reports

**Checks:**
| Check | Threshold | Action |
|-------|-----------|--------|
| Row count | min 1000 | Fail |
| Null % | max 5% | Fail |
| Data age | max 24h | Fail |

## Production Patterns

### 1. Retry Configuration

```python
DEFAULT_ARGS = {
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "max_retry_delay": timedelta(minutes=30),
}
```

### 2. SLA Monitoring

```python
DEFAULT_ARGS = {
    "sla": timedelta(hours=2),
}

def sla_miss_callback(dag, task_list, slas, blocking_tis):
    # Send alert
    pass
```

### 3. Failure Alerts

```python
def on_failure_callback(context):
    task_id = context["task_instance"].task_id
    # Send Slack/Email alert
    pass

with DAG(..., on_failure_callback=on_failure_callback):
    ...
```

### 4. Idempotency

```python
# Use overwrite mode for partitions
application_args=[
    "--mode", "overwrite",
    "--partition", "{{ ds }}",
]
```

### 5. SparkSubmitOperator Best Practices

```python
SparkSubmitOperator(
    task_id="my_task",
    conn_id="spark_connect_default",
    application="s3a://scripts/my_job.py",
    name="my_task_{{ ds }}",  # Unique name per run
    conf={
        "spark.master": "spark://spark-connect:15002",
        "spark.sql.adaptive.enabled": "true",
    },
    execution_timeout=timedelta(hours=1),
)
```

## Customization

### Adding New DAGs

1. Copy template:
   ```bash
   cp dags/production/spark_etl_daily.py dags/production/my_dag.py
   ```

2. Modify:
   - `dag_id`: Unique identifier
   - `schedule_interval`: Cron expression
   - Tasks: Add/modify as needed
   - Tags: Update for filtering

3. Test:
   ```bash
   python dags/production/my_dag.py  # Syntax check
   airflow dags test my_dag 2024-01-01  # Dry run
   ```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `s3_access_key` | S3 access key |
| `s3_secret_key` | S3 secret key |
| `slack_webhook` | Slack webhook URL |
| `alert_email` | Alert recipient email |

## Troubleshooting

### DAG Not Appearing

1. Check syntax: `python dags/my_dag.py`
2. Check imports: All dependencies available?
3. Check Airflow logs: `airflow dags show my_dag`

### Task Failing

1. Check Spark logs in History Server
2. Verify S3 credentials
3. Check resource limits

### SLA Misses

1. Increase `execution_timeout`
2. Optimize Spark job
3. Scale Spark Connect resources
