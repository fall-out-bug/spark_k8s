# ISSUE-034: Jupyter image missing grpcio for Spark Connect 4.1

## Status
OPEN

## Severity
P1 - Blocks E2E tests

## Description

Jupyter image for Spark 4.1 is missing the `grpcio` Python package, which is required for Spark Connect client connectivity in PySpark 4.1.

## Error Message

```
ModuleNotFoundError: No module named 'grpc'

pyspark.errors.exceptions.base.PySparkImportError: [PACKAGE_NOT_INSTALLED] grpcio >= 1.48.1 must be installed; however, it was not found.
```

## Reproduction

```bash
helm install spark charts/spark-4.1 -n spark \
  --set connect.enabled=true \
  --set jupyter.enabled=true

# Connect to Jupyter and run:
from pyspark.sql import SparkSession
spark = SparkSession.builder.remote("sc://spark-connect:15002").getOrCreate()
# Error occurs
```

## Root Cause

The Jupyter Dockerfile for Spark 4.1 (`docker/jupyter-4.1/Dockerfile`) does not include `grpcio` in the pip install requirements.

Spark Connect 4.1 requires:
- PySpark 4.1.0
- grpcio >= 1.48.1

## Solution

Update `docker/jupyter-4.1/Dockerfile` to include grpcio:

```dockerfile
# Add to pip install line
RUN pip install --no-cache-dir \
    jupyterlab==4.0.0 \
    pyspark==4.1.0 \
    grpcio>=1.48.1 \
    pandas>=2.0.0 \
    pyarrow>=10.0.0 \
    matplotlib \
    seaborn
```

Or add to `docker/jupyter-4.1/deps/requirements.txt`:
```
jupyterlab==4.0.0
pyspark==4.1.0
grpcio>=1.48.1
pandas>=2.0.0
pyarrow>=10.0.0
matplotlib
seaborn
```

## Impact

- Cannot use Jupyter with Spark Connect 4.1
- Blocks E2E tests for Spark 4.1
- Affects development workflow

## Workaround

Install grpcio in the running pod:
```bash
kubectl exec -n spark <jupyter-pod> -- pip install grpcio>=1.48.1
```

## Related

- docker/jupyter-4.1/Dockerfile
- docker/jupyter-4.1/deps/requirements.txt
- Spark 4.1 Connect requirements
- ISSUE-033: RBAC configmaps create permission
