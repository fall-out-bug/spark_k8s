# Apache Iceberg JARs Intermediate Layer for Spark K8s
# Provides Apache Iceberg table format JARs for Spark
# Extends custom Spark builds (not Apache distros)

ARG BASE_IMAGE=localhost/spark-k8s:3.5.7-hadoop3.4.2
FROM ${BASE_IMAGE}

# Labels for metadata
LABEL maintainer="spark-k8s" \
      description="Apache Iceberg JARs for table format support" \
      version="2.0.0"

# Build arguments for versioning
ARG ICEBERG_VERSION=1.6.1
ARG SPARK_VERSION=3.5.7
# Iceberg uses major Spark version (3.5 for Spark 3.5.x, 4.0 for Spark 4.1.x)
ARG ICEBERG_SPARK_VERSION=3.5
ARG SCALA_VERSION=2.12

# Set SPARK_HOME (same as base image)
ENV SPARK_HOME=/opt/spark

# Switch to root for installation
USER root

# Download Apache Iceberg JARs from Maven Central
# Iceberg uses major Spark version (3.5 for Spark 3.5.x, 4.0 for Spark 4.1.x)
# Note: Iceberg doesn't have specific builds for patch versions like 3.5.7 or 4.1.0
RUN mkdir -p ${SPARK_HOME}/jars && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-${ICEBERG_SPARK_VERSION}_${SCALA_VERSION}/${ICEBERG_VERSION}/iceberg-spark-runtime-${ICEBERG_SPARK_VERSION}_${SCALA_VERSION}-${ICEBERG_VERSION}.jar \
        -O ${SPARK_HOME}/jars/iceberg-spark-runtime.jar && \
    echo "Iceberg runtime JAR installed: ${ICEBERG_VERSION} (Spark ${ICEBERG_SPARK_VERSION})"

# Download Iceberg AWS bundle (for S3 catalog support)
RUN wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar \
        -O ${SPARK_HOME}/jars/iceberg-aws-bundle-${ICEBERG_VERSION}.jar || \
    echo "AWS bundle download failed (optional for non-S3 deployments)"

# Verify JARs were downloaded successfully
RUN ls -la ${SPARK_HOME}/jars/iceberg*.jar && \
    echo "Iceberg JARs verified"

# Set Iceberg environment variables for Spark
# These enable Iceberg catalog and SQL extensions
ENV SPARK_SQL_CATALOG_IMPLEMENTATION=org.apache.iceberg.spark.SparkCatalog \
    SPARK_SQL_EXTENSIONS=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
    SPARK_ICEBERG_VERSION=${ICEBERG_VERSION}

# Switch back to non-root user
USER 185

# Working directory
WORKDIR /opt/spark/work-dir

# Health check to verify JARs are present
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ls -la ${SPARK_HOME}/jars/iceberg*.jar >/dev/null 2>&1 || exit 1

# Default command (verify installation)
CMD ["bash", "-c", "echo 'Apache Iceberg ${SPARK_ICEBERG_VERSION} installed' && ls -la ${SPARK_HOME}/jars/iceberg*.jar"]
