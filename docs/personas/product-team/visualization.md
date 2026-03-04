# Visualization

Create charts from Spark DataFrames in Jupyter.

## Matplotlib

```python
import matplotlib.pyplot as plt
df = spark.sql("SELECT category, SUM(amount) as total FROM sales GROUP BY category").toPandas()
df.plot.bar(x="category", y="total")
plt.show()
```

## Plotly

```python
import plotly.express as px
df = spark.sql("SELECT * FROM sales LIMIT 1000").toPandas()
px.scatter(df, x="amount", y="quantity", color="category")
```
