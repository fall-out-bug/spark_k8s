# Spark 3.5/4.1 Runtime Images with GPU and Iceberg Support
# Extends custom Spark builds with runtime-specific configurations
#
# After F10 redesign: Uses custom Spark builds directly as base
# No intermediate wrapper layers - runtime images extend base + add runtime features

ARG BASE_IMAGE=spark-k8s:3.5.7-hadoop3.4.2
FROM ${BASE_IMAGE} as spark-base

# Labels for metadata
LABEL maintainer="spark-k8s" \
      description="Apache Spark runtime with GPU and Iceberg support" \
      version="2.0.0"

# Build arguments for variant selection
ARG ENABLE_GPU=false
ARG ENABLE_ICEBERG=false
ARG SPARK_VERSION=3.5.7
ARG SCALA_VERSION=2.12
ARG RAPIDS_VERSION=24.10.0
ARG CUDA_VERSION=12
ARG ICEBERG_VERSION=1.6.1
ARG ICEBERG_SPARK_VERSION=3.5

# Set SPARK_HOME
ENV SPARK_HOME=/opt/spark

# Switch to root for installation
USER root

# GPU Support: Copy RAPIDS JARs from intermediate layer
# The intermediate layer extends the same base image, so we can copy JARs directly
RUN if [ "$ENABLE_GPU" = "true" ]; then \
    echo "Installing RAPIDS plugin for GPU support..." && \
    wget -q https://repo1.maven.org/maven2/com/nvidia/rapids-4-spark_${SCALA_VERSION}/${RAPIDS_VERSION}/rapids-4-spark_${SCALA_VERSION}-${RAPIDS_VERSION}-cuda${CUDA_VERSION}.jar \
        -O ${SPARK_HOME}/jars/rapids-4-spark_${SCALA_VERSION}-${RAPIDS_VERSION}-cuda${CUDA_VERSION}.jar && \
    echo "RAPIDS plugin JAR installed: ${RAPIDS_VERSION} (CUDA ${CUDA_VERSION})"; \
fi

# Iceberg Support: Copy Iceberg JARs from intermediate layer
RUN if [ "$ENABLE_ICEBERG" = "true" ]; then \
    echo "Installing Apache Iceberg for table format support..." && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-${ICEBERG_SPARK_VERSION}_${SCALA_VERSION}/${ICEBERG_VERSION}/iceberg-spark-runtime-${ICEBERG_SPARK_VERSION}_${SCALA_VERSION}-${ICEBERG_VERSION}.jar \
        -O ${SPARK_HOME}/jars/iceberg-spark-runtime.jar && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar \
        -O ${SPARK_HOME}/jars/iceberg-aws-bundle-${ICEBERG_VERSION}.jar && \
    echo "Iceberg runtime JAR installed: ${ICEBERG_VERSION} (Spark ${ICEBERG_SPARK_VERSION})"; \
fi

# Verify JARs were installed (if enabled)
RUN if [ "$ENABLE_GPU" = "true" ]; then \
    ls -la ${SPARK_HOME}/jars/rapids*.jar && \
    echo "RAPIDS JAR verified"; \
fi

RUN if [ "$ENABLE_ICEBERG" = "true" ]; then \
    ls -la ${SPARK_HOME}/jars/iceberg*.jar && \
    echo "Iceberg JARs verified"; \
fi

# Set environment variables based on enabled features
ENV SPARK_RAPIDS_VERSION=${RAPIDS_VERSION} \
    SPARK_RAPIDS_CUDA_VERSION=${CUDA_VERSION} \
    SPARK_ICEBERG_VERSION=${ICEBERG_VERSION}

# Enable Iceberg SQL extensions by default when Iceberg is enabled
RUN if [ "$ENABLE_ICEBERG" = "true" ]; then \
    echo "Enabling Iceberg SQL extensions..."; \
fi

ENV SPARK_SQL_CATALOG_IMPLEMENTATION=org.apache.iceberg.spark.SparkCatalog \
    SPARK_SQL_EXTENSIONS=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions

# Create directories for logs and work
RUN mkdir -p /opt/spark/work-dir /opt/spark/logs /tmp/spark-events && \
    chmod -R 777 /opt/spark/work-dir /opt/spark/logs /tmp/spark-events && \
    chmod g+w /etc/passwd && \
    chmod -R g+rwX /opt/spark && \
    chmod -R a+r /opt/spark/conf

# Switch back to non-root user
USER 185

WORKDIR /opt/spark/work-dir

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD spark-submit --version >/dev/null 2>&1 || exit 1

# Default entrypoint (use base image entrypoint)
ENTRYPOINT ["/opt/spark/bin/spark-shell"]
