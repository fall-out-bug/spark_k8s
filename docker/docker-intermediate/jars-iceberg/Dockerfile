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
ARG SCALA_VERSION=2.12

# Set SPARK_HOME (same as base image)
ENV SPARK_HOME=/opt/spark

# Download Apache Iceberg JARs from Maven Central
# Iceberg requires the runtime JAR for Spark integration
RUN mkdir -p ${SPARK_HOME}/jars && \
    wget -q https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}/${ICEBERG_VERSION}/iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}-${ICEBERG_VERSION}.jar \
        -O ${SPARK_HOME}/jars/iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}-${ICEBERG_VERSION}.jar && \
    echo "Iceberg runtime JAR installed: ${ICEBERG_VERSION}"

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

# Working directory
WORKDIR /opt/spark/work-dir

# Health check to verify JARs are present
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ls -la ${SPARK_HOME}/jars/iceberg*.jar >/dev/null 2>&1 || exit 1

# Default command (verify installation)
CMD ["bash", "-c", "echo 'Apache Iceberg ${SPARK_ICEBERG_VERSION} installed' && ls -la ${SPARK_HOME}/jars/iceberg*.jar"]
