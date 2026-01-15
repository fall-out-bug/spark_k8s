#!/bin/bash
# Spark K8s Platform - Test Script
# Тестирование платформы

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Spark K8s Platform - Tests ==="
echo ""

# Check if services are running
echo "Checking services..."
if ! docker-compose ps | grep -q "spark-connect.*healthy"; then
    echo "ERROR: spark-connect is not healthy. Run ./start.sh first"
    exit 1
fi

PASS=0
FAIL=0

# Test 1: Spark Connect
echo ""
echo "=== Test 1: Spark Connect Connection ==="
if docker exec jupyter python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('Test').remote('sc://spark-connect:15002').getOrCreate()
print(f'Spark version: {spark.version}')
"; then
    echo "PASS: Spark Connect"
    ((PASS++))
else
    echo "FAIL: Spark Connect"
    ((FAIL++))
fi

# Test 2: DataFrame Operations
echo ""
echo "=== Test 2: DataFrame Operations ==="
if docker exec jupyter python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('Test').remote('sc://spark-connect:15002').getOrCreate()
df = spark.createDataFrame([('Alice', 25), ('Bob', 30)], ['name', 'age'])
assert df.count() == 2
print('DataFrame count: 2')
"; then
    echo "PASS: DataFrame Operations"
    ((PASS++))
else
    echo "FAIL: DataFrame Operations"
    ((FAIL++))
fi

# Test 3: S3 Write
echo ""
echo "=== Test 3: S3 Write ==="
if docker exec jupyter python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('Test').remote('sc://spark-connect:15002').getOrCreate()
df = spark.createDataFrame([('Test', 100)], ['name', 'value'])
df.write.mode('overwrite').parquet('s3a://warehouse/test/test_write')
print('Write successful')
"; then
    echo "PASS: S3 Write"
    ((PASS++))
else
    echo "FAIL: S3 Write"
    ((FAIL++))
fi

# Test 4: S3 Read
echo ""
echo "=== Test 4: S3 Read ==="
if docker exec jupyter python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('Test').remote('sc://spark-connect:15002').getOrCreate()
df = spark.read.parquet('s3a://warehouse/test/test_write')
assert df.count() >= 1
print(f'Read {df.count()} rows')
"; then
    echo "PASS: S3 Read"
    ((PASS++))
else
    echo "FAIL: S3 Read"
    ((FAIL++))
fi

# Test 5: pandas API
echo ""
echo "=== Test 5: pandas API on Spark ==="
if docker exec jupyter python3 -c "
from pyspark.sql import SparkSession
import pyspark.pandas as ps
spark = SparkSession.builder.appName('Test').remote('sc://spark-connect:15002').getOrCreate()
psdf = ps.DataFrame({'a': [1, 2, 3], 'b': [4, 5, 6]})
assert len(psdf) == 3
print(f'pandas-on-Spark DataFrame rows: {len(psdf)}')
"; then
    echo "PASS: pandas API"
    ((PASS++))
else
    echo "FAIL: pandas API"
    ((FAIL++))
fi

# Test 6: SQL Query
echo ""
echo "=== Test 6: SQL Query ==="
if docker exec jupyter python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('Test').remote('sc://spark-connect:15002').getOrCreate()
df = spark.createDataFrame([('Alice', 25), ('Bob', 30)], ['name', 'age'])
df.createOrReplaceTempView('test_table')
result = spark.sql('SELECT * FROM test_table WHERE age > 26')
assert result.count() == 1
print('SQL query returned 1 row')
"; then
    echo "PASS: SQL Query"
    ((PASS++))
else
    echo "FAIL: SQL Query"
    ((FAIL++))
fi

# Summary
echo ""
echo "=================================="
echo "=== Test Results ==="
echo "=================================="
echo "PASSED: $PASS"
echo "FAILED: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
