# ISSUE-028: Jupyter Image Missing Spark Connect Dependencies

## Status
FIXED

## Resolution
Modified `charts/spark-3.5/templates/jupyter.yaml` to:
1. Add lifecycle postStart hook to install grpcio and other dependencies when connect.enabled=true
2. Add `extraPipPackages` option in values.yaml for custom packages

## Severity
P1 - High (Blocks Spark Connect usage from Jupyter)

## Component
charts/spark-3.5/templates/jupyter/jupyter-deployment.yaml

## Description
Spark Connect fails from Jupyter with error:
```
ImportError: grpcio >= 1.48.1 must be installed; however, it was not found.
```

The `jupyter/all-spark-notebook:spark-3.5.0` image does not include the `grpcio` package required for Spark Connect client.

## Root Cause
The base Jupyter image includes Spark but not the additional Python dependencies required for Spark Connect:
- `grpcio >= 1.48.1`
- `grpcio-status`
- `googleapis-common-protos`

## Solution
Add initContainer or postStart hook to install required packages:
1. Option A: Add initContainer that runs `pip install grpcio grpcio-status googleapis-common-protos`
2. Option B: Use a custom image with pre-installed dependencies
3. Option C: Add pip install to the deployment via command/args

## Files to Modify
- `charts/spark-3.5/templates/jupyter/jupyter-deployment.yaml`
- `charts/spark-3.5/values.yaml` (add pipPackages option)

## Workaround (Manual)
```bash
kubectl exec -n spark-35-jupyter-sa <jupyter-pod> -- \
  pip install grpcio grpcio-status googleapis-common-protos boto3 prometheus_client
```

## Test Case
1. Deploy scenario1 with Jupyter and Spark Connect
2. Execute in Jupyter:
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()
spark.range(10).count()  # Should return 10
```

## Additional Missing Packages
- `boto3` - Required for S3/MinIO access
- `prometheus_client` - Required for metrics export
