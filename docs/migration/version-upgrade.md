# Spark Version Upgrade Guide

This guide covers upgrading Spark versions on Kubernetes.

## Version Compatibility Matrix

| From → To | 3.3.x | 3.4.x | 3.5.x | 4.0.x | 4.1.x |
|-----------|-------|-------|-------|-------|-------|
| **3.3.x** | ✓ | ✓ | ⚠️ | ❌ | ❌ |
| **3.4.x** | - | ✓ | ✓ | ⚠️ | ❌ |
| **3.5.x** | - | - | ✓ | ✓ | ⚠️ |
| **4.0.x** | - | - | - | ✓ | ✓ |
| **4.1.x** | - | - | - | - | ✓ |

Legend:
- ✓: Direct upgrade supported
- ⚠️: Minor changes required
- ❌: Major migration needed

## Pre-Upgrade Checklist

- [ ] Read Spark release notes
- [ ] Review breaking changes
- [ ] Test in non-production environment
- [ ] Backup all data and configurations
- [ ] Prepare rollback plan
- [ ] Schedule maintenance window
- [ ] Notify stakeholders

## Upgrade Paths

### 3.3.x → 3.5.x

**Breaking changes:**
- Removed `spark.sql.caseSensitive` default change
- Changed `spark.sql.legacy.allowHashOnMapType` default
- Updated default `spark.sql.shuffle.partitions`

**Migration steps:**
1. Update Docker image to Spark 3.5.0
2. Add compatibility configs:
   ```yaml
   sparkConf:
     spark.sql.legacy.allowHashOnMapType: "true"
   ```
3. Test all workloads
4. Remove legacy configs after validation

### 3.4.x → 3.5.x

**Minor changes:**
- New `join` hints syntax
- Changed `spark.sql.execution.arrow.pyspark.enabled` default

**Migration steps:**
1. Update image tag
2. Review PySpark Arrow usage
3. Validate join performance

### 3.5.x → 4.0.x

**Major changes:**
- Removal of legacy SQL configurations
- Changes to `Dataset` API
- Updated Python version requirements

**Migration steps:**
1. **Code changes:**
   ```scala
   // Old
   df.rdd.map(row => ...)

   // New
   df.mapPartitions(iter => ...)
   ```

2. **Config updates:**
   ```yaml
   sparkConf:
     # New AQE defaults
     spark.sql.adaptive.enabled: "true"
     spark.sql.adaptive.skewJoin.enabled: "true"
   ```

3. **Python version:**
   - Requires Python 3.9+
   - Update `pyPackages` accordingly

### 4.0.x → 4.1.x

**Minor changes:**
- New Connect client features
- Improved Delta Lake integration
- Better Kubernetes integration

**Migration steps:**
1. Update image
2. Test Spark Connect
3. Validate Kubernetes scheduling

## Step-by-Step Upgrade

### 1. Prepare Test Environment

```bash
# Create test namespace
kubectl create namespace spark-test

# Deploy test Spark operator
helm install spark-operator-test spark-operator \
  --namespace spark-test \
  --set spark.image.tag="4.1.0"
```

### 2. Build New Image

```dockerfile
FROM apache/spark:4.1.0

# Update Python
RUN apt-get update && \
    apt-get install -y python3.11 python3.11-pip

# Update dependencies
COPY requirements-4.1.txt /tmp/
RUN pip install --no-cache-dir -r /tmp/requirements-4.1.txt

COPY app/ /app/
```

```bash
# Build and push
docker build -t my-registry/spark:4.1.0 .
docker push my-registry/spark:4.1.0
```

### 3. Update Test Jobs

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: test-job
  namespace: spark-test
spec:
  sparkVersion: "4.1.0"
  image: my-registry/spark:4.1.0
  # ... rest of configuration
```

### 4. Run Validation Tests

```bash
# Submit test job
kubectl apply -f test-job.yaml

# Monitor
kubectl logs -f $(kubectl get pods -l spark-app-name=test-job,spark-role=driver -o name)

# Compare results
python scripts/compare_outputs.py \
  --baseline s3a://results/spark-3.5/ \
  --test s3a://results/spark-4.1/
```

### 5. Upgrade Spark Operator

```bash
# Upgrade in production
helm upgrade spark-operator spark-operator \
  --namespace spark-prod \
  --set image.tag="4.1.0" \
  --set spark.image.tag="4.1.0" \
  --wait
```

### 6. Roll Out Gradually

```bash
# Update one namespace at a time
kubectl patch sparkapp -n spark-team-a \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/sparkVersion", "value": "4.1.0"}]'

# Verify before proceeding to next namespace
```

## Common Issues

### Issue 1: Class Not Found

**Symptom:**
```
java.lang.ClassNotFoundException: org.apache.spark.sql.SparkSession
```

**Fix:**
- Rebuild application jars with new Spark version
- Update transitive dependencies

### Issue 2: Serialization Error

**Symptom:**
```
java.io.InvalidClassException: org.apache.spark.sql.Row
```

**Fix:**
- Clear checkpoint data
- Regenerate stream offsets

### Issue 3: Performance Regression

**Symptom:**
- Jobs slower after upgrade

**Fix:**
```yaml
sparkConf:
  # Adjust AQE
  spark.sql.adaptive.enabled: "true"
  spark.sql.adaptive.coalescePartitions.enabled: "true"

  # Adjust shuffle
  spark.sql.shuffle.partitions: "400"
```

### Issue 4: UDF Compatibility

**Symptom:**
- UDFs failing after upgrade

**Fix:**
```python
# Re-register UDFs with new version
from pyspark.sql.functions import udf
from pyspark.sql.types import IntegerType

@udf(IntegerType())
def my_udf(value):
    return int(value) * 2

spark.udf.register("my_udf", my_udf)
```

## Rollback Plan

If upgrade fails:

```bash
# Rollback Spark operator
helm rollback spark-operator spark-prod

# Rollback application images
kubectl patch sparkapp --all \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/image", "value": "my-registry/spark:3.5.0"}]'

# Clear failed checkpoints
kubectl exec -it <checkpoint-pod> -- rm -rf /checkpoints/failed
```

## Validation Tests

```python
# tests/upgrade_validation.py
def validate_spark_version():
    """Validate Spark upgrade."""
    spark = SparkSession.builder \
        .appName("version-test") \
        .getOrCreate()

    # Check version
    version = spark.version
    print(f"Spark version: {version}")

    # Test basic operations
    df = spark.range(100)
    assert df.count() == 100

    # Test SQL
    df.createOrReplaceTempView("test")
    result = spark.sql("SELECT count(*) FROM test")
    assert result.collect()[0][0] == 100

    print("✅ All validation tests passed")
    spark.stop()

if __name__ == "__main__":
    validate_spark_version()
```

## Post-Upgrade Tasks

- [ ] Update documentation
- [ ] Retrain ML models if needed
- [ ] Update CI/CD pipelines
- [ ] Remove legacy configurations
- [ ] Update monitoring dashboards
- [ ] Train team on new features

## Related

- [Compatibility Matrix](https://spark.apache.org/versioning-policy.html)
- [Release Notes](https://spark.apache.org/releases/)
