# Your First Spark Job

Run your first "Hello World" Spark job on Kubernetes.

## Prerequisites

- Spark Connect deployed (see [Local Setup](local-dev.md) or [Cloud Setup](cloud-setup.md))
- Jupyter notebook or Python with `pyspark`

## Option A: Python Script

### 1. Install Dependencies

```bash
pip install pyspark==4.1.0
```

### 2. Run Job

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("HelloWorld") \
    .remote("sc://localhost") \
    .getOrCreate()

# Create a simple DataFrame
data = [
    ("Alice", 34, "Engineer"),
    ("Bob", 45, "Data Scientist"),
    ("Charlie", 29, "Designer")
]

df = spark.createDataFrame(data, ["name", "age", "role"])

# Show the data
df.show()

# Run a SQL query
df.createOrReplaceTempView("people")
spark.sql("SELECT role, AVG(age) as avg_age FROM people GROUP BY role").show()

spark.stop()
```

### 3. Run It

```bash
python first_job.py
```

---

## Option B: Jupyter Notebook

### 1. Open Jupyter

Navigate to http://localhost:8888

### 2. Create New Notebook

1. Click "New" → "Python 3"
2. Name it `first_spark_job.ipynb`

### 3. Add Cells

**Cell 1: Connect to Spark**

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("NotebookDemo") \
    .remote("sc://localhost") \
    .getOrCreate()

print("✅ Connected to Spark!")
```

**Cell 2: Your Analysis**

```python
# Create sample data
data = [
    ("Product A", 100, 50),
    ("Product B", 80, 30),
    ("Product C", 120, 70)
]

df = spark.createDataFrame(data, ["product", "sales", "returns"])
df.createOrReplaceTempView("inventory")

spark.sql("SELECT product, (sales - returns) as net_sales FROM inventory").show()
```

**Cell 3: Cleanup**

```python
spark.stop()
print("✅ Session stopped")
```

### 4. Run All Cells

Click "Run" → "Run All Cells"

---

## Option C: Spark Submit (Production Style)

### 1. Prepare Your Job

```python
# my_spark_job.py
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("ProductionJob") \
    .remote("sc://localhost") \
    .getOrCreate()

# Your actual code here
df = spark.range(1000)
print(f"Total rows: {df.count()}")

spark.stop()
```

### 2. Submit Job

```bash
spark-submit \
  --master local \
  --name hello-world \
  my_spark_job.py
```

---

## Expected Output

```
+-----+---+-------+
| name | age|   role|
+-----+---+-------+
|Alice|  34|Engineer|
|  Bob|  45|Data Scientist|
|Charlie|29|Designer|
+-----+---+-------+

+-------+--------+
|   role|avg_age|
+-------+--------+
|Designer|  29.0|
|Engineer|  34.0|
|Data Scientist|  45.0|
+-------+--------+

✅ Connected to Spark!
Total rows: 1000
✅ Session stopped
```

---

## Troubleshooting

### "Connection refused" error

```bash
# Check Spark Connect is running
kubectl get pods -l app=spark-connect

# Port forward if needed
kubectl port-forward svc/spark-connect 15002:15002
```

### "Module 'pyspark' not found"

```bash
pip install --upgrade pyspark
```

### Job hangs forever

```bash
# Check Spark Connect logs
kubectl logs -f deployment/spark-connect

# Check driver pod status
kubectl get pods -l spark-role=driver
```

---

## Next Steps

- [Choose a Preset](choose-preset.md) — Pre-configured scenarios
- [Production Checklist](../operations/production-checklist.md) — Going live checklist

---

**Time:** 10 minutes
**Difficulty:** Beginner
**Last Updated:** 2026-02-04
