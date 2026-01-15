# JupyterLab with Spark Connect - pure pip, no conda
FROM python:3.11-slim-bookworm

ARG SPARK_VERSION=3.5.7
ARG JAVA_VERSION=17

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-${JAVA_VERSION}-jre-headless \
    curl \
    git \
    gcc \
    g++ \
    libkrb5-dev \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Create non-root user
RUN useradd -m -s /bin/bash -u 1000 jupyter
WORKDIR /home/jupyter

# Install uv for fast package management
RUN pip install --no-cache-dir uv

# Install Python packages with uv (much faster than pip)
# Note: Comments must NOT be inline with package specs (causes uv bug creating garbage files)
RUN uv pip install --system --no-cache \
    "pyspark[connect,sql,pandas_on_spark]==${SPARK_VERSION}" \
    "pyarrow>=14.0.0" \
    "pandas>=2.0.0" \
    "numpy>=1.24.0" \
    "polars>=0.20.0" \
    "grpcio>=1.60.0" \
    "grpcio-status>=1.60.0" \
    "jupyterlab>=4.0.0" \
    "jupyterhub>=4.0.0" \
    "jupyterlab-git>=0.50.0" \
    "ipywidgets>=8.0.0" \
    "plotly>=5.18.0" \
    "seaborn>=0.13.0" \
    "matplotlib>=3.8.0" \
    "scikit-learn>=1.4.0" \
    "mlflow>=2.10.0" \
    "boto3>=1.34.0" \
    "s3fs>=2024.2.0" \
    "sqlalchemy>=2.0.0" \
    "psycopg2-binary>=2.9.0" \
    "python-dotenv>=1.0.0"

# Set PyArrow timezone fix
ENV PYARROW_IGNORE_TIMEZONE=1

# Spark Connect environment
ENV SPARK_REMOTE="sc://spark-connect:15002"
ENV PYSPARK_PYTHON=python3

# Add home to PYTHONPATH so spark_config is importable from notebooks
ENV PYTHONPATH="/home/jupyter:${PYTHONPATH}"

# Copy notebooks and config
COPY --chown=jupyter:jupyter notebooks/ /home/jupyter/notebooks/
COPY --chown=jupyter:jupyter spark_config.py /home/jupyter/

# Create IPython profile directory
RUN mkdir -p /home/jupyter/.ipython/profile_default/startup && \
    chown -R jupyter:jupyter /home/jupyter

# Copy startup script
COPY --chown=jupyter:jupyter jupyter_startup.py /home/jupyter/.ipython/profile_default/startup/00-spark.py

USER jupyter

EXPOSE 8888

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--NotebookApp.token=''", "--NotebookApp.password=''"]
