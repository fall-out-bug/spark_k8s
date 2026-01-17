## WS-020-04: Jupyter 4.1.0 Docker Image (Minimal Wrapper)

### 🎯 Goal

**What should WORK after WS completion:**
- Dockerfile for Jupyter with PySpark 4.1.0 exists, using official `apache/spark-py:4.1.0` as base
- Image includes JupyterLab and Spark Connect client configuration
- Image builds successfully and is loadable into Minikube
- Jupyter can connect to Spark Connect 4.1.0 server

**Acceptance Criteria:**
- [ ] `docker/jupyter-4.1/Dockerfile` exists (minimal, ~30 LOC)
- [ ] `docker/jupyter-4.1/spark_config.py` provides pre-configured Spark Connect client
- [ ] `docker/jupyter-4.1/notebooks/00_spark_connect_guide.ipynb` demonstrates connection
- [ ] Image builds: `docker build -t jupyter-spark:4.1.0 docker/jupyter-4.1`
- [ ] Image loaded into Minikube: `minikube image load jupyter-spark:4.1.0`

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 requires a Jupyter image for Data Scientists to use Spark 4.1.0 via Spark Connect. Unlike the 3.5.7 custom image, this uses the official Apache PySpark 4.1.0 base with minimal customization (JupyterLab + config).

### Dependency

Independent (can run in parallel with WS-020-03)

### Input Files

**Reference:**
- `docker/jupyter/Dockerfile` — Existing Jupyter 3.5.7 image (for comparison)
- `docker/jupyter/spark_config.py` — Spark Connect client config pattern
- `docker/jupyter/notebooks/00_spark_connect_guide.ipynb` — Example notebook to adapt

### Steps

1. **Create directory structure:**
   ```bash
   mkdir -p docker/jupyter-4.1/notebooks
   ```

2. **Create `docker/jupyter-4.1/Dockerfile`:**
   ```dockerfile
   FROM apache/spark-py:4.1.0
   
   # Install JupyterLab
   USER root
   RUN pip install --no-cache-dir \
       jupyterlab==4.0.0 \
       pyspark==4.1.0 \
       pandas>=2.0.0 \
       pyarrow>=10.0.0 \
       matplotlib \
       seaborn
   
   # Copy Spark Connect client config
   COPY spark_config.py /opt/spark/conf/
   
   # Copy example notebooks
   COPY notebooks/ /home/spark/notebooks/
   
   # Set working directory
   WORKDIR /home/spark/notebooks
   
   # Switch to non-root user
   USER 185
   
   # Expose JupyterLab port
   EXPOSE 8888
   
   # Start JupyterLab
   CMD ["jupyter", "lab", \
        "--ip=0.0.0.0", \
        "--port=8888", \
        "--no-browser", \
        "--allow-root", \
        "--NotebookApp.token=''", \
        "--NotebookApp.password=''"]
   ```

3. **Create `docker/jupyter-4.1/spark_config.py`:**
   ```python
   """Pre-configured Spark Connect client for Jupyter."""
   import os
   from pyspark.sql import SparkSession
   
   def get_spark_session(app_name="JupyterSparkConnect"):
       """
       Create Spark session connected to Spark Connect server.
       
       Environment variables:
       - SPARK_CONNECT_URL: Spark Connect server URL (default: sc://spark-connect:15002)
       """
       connect_url = os.getenv("SPARK_CONNECT_URL", "sc://spark-connect:15002")
       
       spark = SparkSession.builder \
           .appName(app_name) \
           .remote(connect_url) \
           .config("spark.sql.execution.arrow.pyspark.enabled", "true") \
           .getOrCreate()
       
       return spark
   
   # Auto-create session if imported
   if __name__ != "__main__":
       spark = get_spark_session()
       print(f"✓ Spark Connect session created: {spark.version}")
   ```

4. **Create `docker/jupyter-4.1/notebooks/00_spark_connect_guide.ipynb`:**
   
   Adapt from existing `docker/jupyter/notebooks/00_spark_connect_guide.ipynb`:
   ```json
   {
     "cells": [
       {
         "cell_type": "markdown",
         "source": "# Spark Connect 4.1.0 Quickstart\n\nThis notebook demonstrates connecting to Spark 4.1.0 via Spark Connect."
       },
       {
         "cell_type": "code",
         "source": "import sys\nsys.path.append('/opt/spark/conf')\nfrom spark_config import get_spark_session\n\nspark = get_spark_session()\nprint(f\"Spark version: {spark.version}\")"
       },
       {
         "cell_type": "code",
         "source": "# Test DataFrame creation\ndf = spark.range(100)\ndf.count()"
       },
       {
         "cell_type": "code",
         "source": "# Test SQL\nspark.sql(\"SELECT 1 AS test\").show()"
       }
     ]
   }
   ```

5. **Build and test image:**
   ```bash
   cd docker/jupyter-4.1
   docker build -t jupyter-spark:4.1.0 .
   
   # Load into Minikube
   minikube image load jupyter-spark:4.1.0
   
   # Test locally (without Spark Connect server, should show import error gracefully)
   docker run --rm -p 8888:8888 jupyter-spark:4.1.0
   # Access http://localhost:8888
   ```

6. **Validate notebook execution:**
   - Deploy Spark Connect 4.1.0 server (in later WS)
   - Run Jupyter pod
   - Execute `00_spark_connect_guide.ipynb`
   - Verify Spark version shows `4.1.0`

### Expected Result

```
docker/jupyter-4.1/
├── Dockerfile                                  # ~35 LOC
├── spark_config.py                             # ~30 LOC
└── notebooks/
    ├── 00_spark_connect_guide.ipynb            # ~80 LOC (JSON)
    ├── 01_dataframe_operations.ipynb           # ~100 LOC (copy from docker/jupyter/notebooks)
    └── 02_pandas_api.ipynb                     # ~100 LOC (copy from docker/jupyter/notebooks)
```

### Scope Estimate

- Files: 5 created
- Lines: ~345 LOC (SMALL)
- Tokens: ~1400
- Build time: ~3-5 minutes

### Completion Criteria

```bash
# Build image
docker build -t jupyter-spark:4.1.0 docker/jupyter-4.1

# Verify image size (<1.5GB preferred)
docker images jupyter-spark:4.1.0

# Test JupyterLab starts
docker run --rm -d --name test-jupyter -p 8888:8888 jupyter-spark:4.1.0
sleep 5
curl -s http://localhost:8888/lab | grep "JupyterLab"
docker stop test-jupyter

# Load into Minikube
minikube image load jupyter-spark:4.1.0
minikube image ls | grep jupyter-spark:4.1.0
```

### Constraints

- DO NOT build custom Spark distribution (use official Apache image)
- DO NOT include heavy ML libraries by default (add in chart values if needed)
- USE official `apache/spark-py:4.1.0` as base (minimal customization)
- ENSURE non-root user (uid 185)
- Token/password disabled for local dev (secure in production via chart)
