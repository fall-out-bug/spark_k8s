# Product Team Quick Start

Welcome! This guide helps non-technical users get started with Spark on Kubernetes.

## What is Spark?

Apache Spark is a tool for processing large amounts of data quickly. Think of it as Excel on steroids:
- **Like Excel**: You can analyze, filter, and visualize data
- **Unlike Excel**: Spark can handle millions or billions of rows

## What You Can Do

- **Query data**: Ask questions about your data using SQL
- **Create dashboards**: Build visualizations and share them
- **Ad-hoc analysis**: Explore data without IT help
- **Schedule reports**: Automate recurring analyses

## Quick Start (5 Minutes)

### 1. Access JupyterHub

Open your browser and go to:
```
https://jupyter.your-company.com
```

Login with your company credentials.

### 2. Start a Notebook

1. Click "New" → "Spark Notebook"
2. A blank notebook opens with Spark ready to use

### 3. Your First Query

```python
# This is a code cell - click it and press Shift+Enter to run

# Load data from S3
df = spark.read.parquet("s3a://company-data/sales/")

# Show the data
df.show(10)
```

### 4. Ask Questions

```python
# What were total sales by month?
df.createOrReplaceTempView("sales")

result = spark.sql("""
    SELECT
        month,
        SUM(amount) as total_sales
    FROM sales
    GROUP BY month
    ORDER BY month
""")

result.show()
```

### 5. Visualize

```python
# Create a simple chart
result.toPandas().plot.bar(x='month', y='total_sales')
```

## Common Tasks

### Query SQL Tables

```python
# List available tables
spark.catalog.listTables().show()

# Query a table
df = spark.sql("SELECT * FROM users WHERE country = 'US'")
df.show()
```

### Filter Data

```python
# Filter to show only high-value customers
high_value = df.filter(df["purchases"] > 1000)
high_value.show()
```

### Group and Aggregate

```python
# Average purchase by category
df.groupBy("category").agg({"amount": "avg"}).show()
```

### Join Data

```python
# Combine transactions with customer info
transactions = spark.read.parquet("s3a://data/transactions/")
customers = spark.read.parquet("s3a://data/customers/")

joined = transactions.join(customers, "customer_id")
joined.show()
```

## SQL Reference

### SELECT Basics

```sql
-- Get specific columns
SELECT customer_id, amount, date
FROM transactions

-- Filter rows
SELECT *
FROM transactions
WHERE amount > 100

-- Sort results
SELECT *
FROM transactions
ORDER BY amount DESC
```

### Aggregation

```sql
-- Count rows
SELECT COUNT(*)
FROM transactions

-- Group by category
SELECT category, SUM(amount) as total
FROM transactions
GROUP BY category

-- Multiple aggregations
SELECT
    category,
    COUNT(*) as transactions,
    SUM(amount) as total,
    AVG(amount) as average
FROM transactions
GROUP BY category
```

### Joins

```sql
-- Inner join
SELECT t.*, c.name, c.email
FROM transactions t
JOIN customers c ON t.customer_id = c.id

-- Left join (keep all customers)
SELECT c.*, t.amount
FROM customers c
LEFT JOIN transactions t ON c.id = t.customer_id
```

### Date Filtering

```sql
-- Last 30 days
SELECT *
FROM events
WHERE event_date >= CURRENT_DATE() - INTERVAL 30 DAYS

-- Specific date range
SELECT *
FROM events
WHERE event_date BETWEEN '2024-01-01' AND '2024-01-31'
```

## Common Patterns

### Year-over-Year Comparison

```python
df = spark.read.parquet("s3a://data/sales/")

df.createOrReplaceTempView("sales")

spark.sql("""
    WITH yearly_sales AS (
        SELECT
            YEAR(date) as year,
            SUM(amount) as total
        FROM sales
        GROUP BY YEAR(date)
    )
    SELECT
        year,
        total,
        LAG(total) OVER (ORDER BY year) as prev_year,
        total - LAG(total) OVER (ORDER BY year) as growth
    FROM yearly_sales
""").show()
```

### Top N per Category

```python
spark.sql("""
    WITH ranked AS (
        SELECT
            customer_id,
            amount,
            ROW_NUMBER() OVER (PARTITION BY category ORDER BY amount DESC) as rn
        FROM transactions
    )
    SELECT * FROM ranked WHERE rn <= 10
""").show()
```

### Moving Average

```python
spark.sql("""
    SELECT
        date,
        sales,
        AVG(sales) OVER (
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as moving_avg_7day
    FROM daily_sales
""").show()
```

## Working with Different Data Sources

### Reading Files

```python
# Parquet (recommended - fast and efficient)
df = spark.read.parquet("s3a://data/file.parquet")

# CSV
df = spark.read.csv("s3a://data/file.csv", header=True, inferSchema=True)

# JSON
df = spark.read.json("s3a://data/file.json")
```

### Writing Results

```python
# Save to S3
df.write.parquet("s3a://my-output/results.parquet", mode="overwrite")

# Save as CSV
df.write.csv("s3a://my-output/results.csv", header=True, mode="overwrite")
```

## Tips and Tricks

### 1. Use `.show()` for Preview

```python
# Just show first 20 rows
df.show()

# Show with more rows
df.show(50)

# Show vertically (better for wide tables)
df.show(1, truncate=False)
```

### 2. Check Row Count

```python
# Count rows (expensive!)
df.count()

# Estimate (fast)
df.rdd.mapPartitions(lambda x: [len(x)]).sum()
```

### 3. Get Schema

```python
# See column names and types
df.printSchema()
```

### 4. Convert to Pandas for Visualization

```python
# Convert to pandas for charts
pandas_df = df.limit(1000).toPandas()
pandas_df.plot()
```

### 5. Cache Frequently Used Data

```python
# Cache for faster repeated access
df.cache()
df.count()  # Materialize cache
```

## Getting Help

### Within Jupyter

```python
# See available functions on a DataFrame
df.groupBy?

# Get help for a function
help(df.filter)
```

### Sample Notebooks

Check the shared folder for example notebooks:
- `shared/intro-to-spark.ipynb` - Basic operations
- `shared/sql-queries.ipynb` - SQL examples
- `shared/visualization.ipynb` - Charts and graphs

### Ask the Team

- **Technical questions**: Slack #data-engineering
- **Data questions**: Slack #data-analytics
- **Access issues**: Submit a ticket to IT

## Best Practices

1. **Start with filters**: Reduce data size before processing
2. **Use SQL for complex queries**: Often easier than chaining functions
3. **Check your results**: Verify counts and sample values
4. **Save intermediate results**: Don't re-compute everything
5. **Ask for help**: Don't struggle alone!

## Next Steps

- [ ] Complete the SQL Tutorial (shared/sql-tutorial.ipynb)
- [ ] Explore the Sample Notebooks
- [ ] Join the weekly office hours
- [ ] Request access to production data

## Common Issues

**Issue: Out of memory**
- Solution: Add `.limit(10000)` after read statements

**Issue: Query is slow**
- Solution: Filter data early or ask for help optimizing

**Issue: Permission denied**
- Solution: Contact #data-engineering for access

## Glossary

| Term | Meaning |
|------|---------|
| DataFrame | Like a spreadsheet in Spark |
| Schema | Column names and types |
| Partition | How data is organized for processing |
| Parquet | Efficient file format for big data |
| S3 | S3 is Amazon's cloud storage (we use s3a:// protocol) |

---

**Need help?** Contact the data team or join office hours!
