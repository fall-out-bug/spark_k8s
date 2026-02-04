# RAPIDS Plugin JARs Intermediate Layer for Spark K8s
# Provides NVIDIA RAPIDS GPU acceleration JARs for Spark
# This layer builds on Spark core images to add RAPIDS support

ARG BASE_IMAGE=apache/spark:3.5.7-scala2.12-java17-ubuntu
FROM ${BASE_IMAGE}

# Switch to root for installation (base image runs as non-root)
USER root

# Labels for metadata
LABEL maintainer="spark-k8s" \
      description="Spark K8s - RAPIDS Plugin JARs Intermediate Layer" \
      version="1.0.0"

# Build arguments for versioning
ARG RAPIDS_VERSION=24.10.0
ARG CUDA_VERSION=12
ARG SPARK_VERSION=3.5.7
ARG SCALA_VERSION=2.12

# Set SPARK_HOME (same as base image)
ENV SPARK_HOME=/opt/spark

# Download RAPIDS plugin JAR from Maven Central
# The rapids-4-spark JAR includes cudf as a shaded dependency
# Choose CUDA 12 version for modern GPU support
RUN mkdir -p ${SPARK_HOME}/jars && \
    wget -q https://repo1.maven.org/maven2/com/nvidia/rapids-4-spark_${SCALA_VERSION}/${RAPIDS_VERSION}/rapids-4-spark_${SCALA_VERSION}-${RAPIDS_VERSION}-cuda${CUDA_VERSION}.jar \
        -O ${SPARK_HOME}/jars/rapids-4-spark_${SCALA_VERSION}-${RAPIDS_VERSION}-cuda${CUDA_VERSION}.jar && \
    echo "RAPIDS plugin JAR installed: ${RAPIDS_VERSION} (CUDA ${CUDA_VERSION})"

# Verify JAR was downloaded successfully
RUN ls -la ${SPARK_HOME}/jars/rapids*.jar && \
    echo "RAPIDS JAR verified"

# Set RAPIDS environment variables for Spark
ENV SPARK_RAPIDS_VERSION=${RAPIDS_VERSION} \
    SPARK_RAPIDS_CUDA_VERSION=${CUDA_VERSION} \
    SPARK_RAPIDS_JAR=${SPARK_HOME}/jars/rapids-4-spark_${SCALA_VERSION}-${RAPIDS_VERSION}-cuda${CUDA_VERSION}.jar

# Switch back to non-root user (matching base image)
USER 185

# Working directory
WORKDIR /opt/spark/work-dir

# Health check to verify JARs are present
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ls -la ${SPARK_HOME}/jars/rapids*.jar >/dev/null 2>&1 || exit 1

# Default command (verify installation)
CMD ["bash", "-c", "echo 'RAPIDS ${SPARK_RAPIDS_VERSION} installed' && ls -la ${SPARK_RAPIDS_JAR}"]
