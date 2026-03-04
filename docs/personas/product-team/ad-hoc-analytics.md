# Ad-Hoc Analytics

Explore data interactively in Jupyter.

## Workflow

1. Open Jupyter
2. Create new notebook
3. Connect to Spark: `spark = SparkSession.builder.getOrCreate()`
4. Run SQL: `spark.sql("SELECT ...").show()`

## Tips

- Use `LIMIT` for quick exploration
- Cache frequently used tables: `df.cache()`
- Export results to CSV for sharing
