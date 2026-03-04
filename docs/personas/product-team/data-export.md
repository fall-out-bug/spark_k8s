# Data Export

Export query results from Jupyter.

## CSV

```python
df = spark.sql("SELECT * FROM sales LIMIT 10000")
df.coalesce(1).write.mode("overwrite").csv("/tmp/export")
```

## Parquet

```python
df.write.parquet("s3a://bucket/export/")
```

## Download to Local

Use Jupyter's download or `df.toPandas().to_csv("local.csv")` for small datasets.
