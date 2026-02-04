# Python Dependencies Intermediate Layer for Spark K8s
# Extends custom Spark builds or JDK base with Python packages
# Supports base, GPU, and Iceberg variants via build args

ARG BASE_IMAGE=localhost/spark-k8s:3.5.7-hadoop3.4.2
FROM ${BASE_IMAGE}

# Labels for metadata
LABEL maintainer="spark-k8s" \
      description="Python dependencies intermediate layer for Spark K8s" \
      version="1.0.0"

# Build arguments for variant selection
ARG BUILD_GPU_DEPS=false
ARG BUILD_ICEBERG_DEPS=false
ARG PYTHON_VERSION=3.11

# Switch to root for installation
USER root

# Set pip configuration for faster installs
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1

# Install base dependencies (if not already in base image)
COPY requirements-base.txt /tmp/
RUN if ! pip3 show pyspark >/dev/null 2>&1; then \
        pip3 install --no-cache-dir -r /tmp/requirements-base.txt; \
    else \
        echo "PySpark already installed in base image"; \
    fi && \
    rm /tmp/requirements-base.txt

# Install GPU dependencies if requested
COPY requirements-gpu.txt /tmp/
RUN if [ "$BUILD_GPU_DEPS" = "true" ]; then \
        echo "Installing GPU dependencies..." && \
        pip3 install --no-cache-dir -r /tmp/requirements-gpu.txt && \
        echo "GPU dependencies installed: cudf, cuml, cupy"; \
    else \
        echo "Skipping GPU dependencies"; \
    fi && \
    rm /tmp/requirements-gpu.txt

# Install Iceberg dependencies if requested
COPY requirements-iceberg.txt /tmp/
RUN if [ "$BUILD_ICEBERG_DEPS" = "true" ]; then \
        echo "Installing Iceberg dependencies..." && \
        pip3 install --no-cache-dir -r /tmp/requirements-iceberg.txt && \
        echo "Iceberg dependencies installed: pyiceberg, fsspec"; \
    else \
        echo "Skipping Iceberg dependencies"; \
    fi && \
    rm /tmp/requirements-iceberg.txt

# Verify installations
RUN python3 -c "import pyspark; print(f'PySpark {pyspark.__version__} OK')" && \
    if [ "$BUILD_GPU_DEPS" = "true" ]; then \
        python3 -c "import cudf; print(f'cuDF {cudf.__version__} OK')"; \
    fi && \
    if [ "$BUILD_ICEBERG_DEPS" = "true" ]; then \
        python3 -c "import pyiceberg; print(f'PyIceberg {pyiceberg.__version__} OK')"; \
    fi

# Switch back to non-root user (matches custom Spark build)
USER 185

# Working directory
WORKDIR /opt/spark/work-dir

# Health check to verify Python packages
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import pyspark, pandas, numpy" || exit 1

# Default command (show installed packages)
CMD ["bash", "-c", "pip3 list | grep -E 'pyspark|pandas|numpy|cudf|pyiceberg' || echo 'Python deps layer ready'"]
