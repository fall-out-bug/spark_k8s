# Jupyter PySpark Startup Script
# Automatically configures PySpark and Spark Connect for Jupyter notebooks

import os
import sys

# Add Spark to Python path
spark_home = os.environ.get("SPARK_HOME", "/opt/spark")
if spark_home not in sys.path:
    sys.path.insert(0, spark_home + "/python")

# Find PySpark lib
import glob
pyspark_lib = glob.glob(spark_home + "/python/lib/py4j-*.zip")
if pyspark_lib:
    for lib in pyspark_lib:
        if lib not in sys.path:
            sys.path.insert(0, lib)

# Import findspark for easy Spark initialization
try:
    import findspark
    findspark.init(spark_home)
    print(f"PySpark initialized from {spark_home}")
except ImportError:
    print("Warning: findspark not available, Spark initialization may require manual setup")

# Set PyArrow timezone fix (if available)
# Check if pyarrow is available without try/except
import importlib.util
if importlib.util.find_spec("pyarrow") is not None:
    os.environ["PYARROW_IGNORE_TIMEZONE"] = "1"

print("PySpark startup complete. Spark is ready to use!")
print("To create a Spark session, use:")
print("  from pyspark.sql import SparkSession")
print("  spark = SparkSession.builder.getOrCreate()")
