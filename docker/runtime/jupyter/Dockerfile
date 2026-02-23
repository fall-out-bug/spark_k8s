# Jupyter Runtime Images with Spark Integration
# Extends Spark runtime images with JupyterLab and PySpark

ARG SPARK_RUNTIME_IMAGE=spark-k8s-runtime:3.5-3.5.7-baseline
FROM ${SPARK_RUNTIME_IMAGE} as spark-runtime

# Labels for metadata
LABEL maintainer="spark-k8s" \
      description="JupyterLab with PySpark and Spark Connect support" \
      version="2.0.0"

# Build arguments
ARG SPARK_VERSION=3.5.7
ARG ENABLE_GPU=false
ARG ENABLE_ICEBERG=false

# Switch to root for installation
USER root

# Install additional system packages for Jupyter
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create Jupyter user (if not exists)
RUN useradd -m -s /bin/bash -u 1000 jupyter || true

# Install Python packages for Jupyter
# Use pip from the base image
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir \
    jupyterlab>=4.0.0 \
    jupyterlab-git>=0.50.0 \
    jupyterhub>=4.0.0 \
    ipywidgets>=8.0.0 \
    pyspark==${SPARK_VERSION} \
    findspark \
    pyarrow>=14.0.0 \
    pandas>=2.0.0 \
    numpy>=1.24.0 \
    polars>=0.20.0 \
    plotly>=5.18.0 \
    seaborn>=0.13.0 \
    matplotlib>=3.8.0 \
    scikit-learn>=1.4.0 \
    mlflow>=2.10.0 \
    boto3>=1.34.0 \
    s3fs>=2024.2.0 \
    sqlalchemy>=2.0.0 \
    psycopg2-binary>=2.9.0 \
    python-dotenv>=1.0.0

# GPU-specific packages (RAPIDS)
RUN if [ "$ENABLE_GPU" = "true" ]; then \
    echo "Installing RAPIDS for GPU support in Jupyter..." && \
    pip3 install --no-cache-dir \
        cudf-cu12 \
        cuml-cu12 \
        cupy-cuda12x \
        rapids-dask-dependency; \
fi

# Iceberg-specific packages
RUN if [ "$ENABLE_ICEBERG" = "true" ]; then \
    echo "Installing Iceberg dependencies for Jupyter..."; \
fi

# Create Jupyter directories
RUN mkdir -p /home/jupyter/notebooks \
    /home/jupyter/.jupyter \
    /home/jupyter/.ipython/profile_default/startup && \
    chown -R jupyter:jupyter /home/jupyter

# Set up Jupyter configuration
ENV JUPYTER_ENABLE_LAB=yes \
    PYARROW_IGNORE_TIMEZONE=1 \
    SPARK_HOME=/opt/spark \
    PYTHONPATH="/opt/spark/python:/opt/spark/python/lib/py4j-*.zip:/home/jupyter:${PYTHONPATH}"

# Copy startup script for PySpark initialization
COPY jupyter_startup.py /home/jupyter/.ipython/profile_default/startup/00-spark.py
RUN chown jupyter:jupyter /home/jupyter/.ipython/profile_default/startup/00-spark.py

# Copy example notebooks
COPY notebooks/ /home/jupyter/notebooks/
RUN chown -R jupyter:jupyter /home/jupyter/notebooks

# Expose Jupyter port
EXPOSE 8888 4040

# Switch to Jupyter user
USER jupyter
WORKDIR /home/jupyter

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8888/health || exit 1

# Start JupyterLab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root", "--NotebookApp.token=''", "--NotebookApp.password=''"]
