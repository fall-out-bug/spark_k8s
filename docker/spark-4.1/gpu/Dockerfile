# Spark 4.1.0 with NVIDIA RAPIDS Support
# Multi-stage build for optimized image size

ARG BASE_IMAGE="nvcr.io/nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04"
ARG SPARK_VERSION="4.1.0"
ARG RAPIDS_VERSION="24.02"

FROM ${BASE_IMAGE} AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3-dev \
    openjdk-11-jre-headless \
    curl \
    wget \
    git \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHON_VERSION=3.10
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV SPARK_HOME=/opt/spark
ENV PATH="${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}"
ENV PYTHONPATH="${SPARK_HOME}/python:${PYTHONPATH}"

# Download and install Spark
ARG SPARK_VERSION
ARG SPARK_HADOOP_VERSION="3"

RUN wget -q https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION}.tgz \
    && tar xzf spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION}.tgz -C /opt \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION} ${SPARK_HOME} \
    && rm spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION}.tgz

# Install RAPIDS
ARG RAPIDS_VERSION

# Install cuDF (CUDA DataFrame library)
RUN pip install --no-cache-dir \
    cudf=${RAPIDS_VERSION} \
    cupy-cuda12x \
    pyspark==${SPARK_VERSION} \
    numpy \
    pandas

# Install RAPIDS Spark plugin
ARG RAPIDS_SPARK_VERSION="24.02.0"

RUN wget -q https://repo1.maven.org/maven2/com/nvidia/rapids-4-spark_2.12/${RAPIDS_SPARK_VERSION}/rapids-4-spark_2.12-${RAPIDS_SPARK_VERSION}.jar \
    -O ${SPARK_HOME}/jars/rapids-4-spark_2.12-${RAPIDS_SPARK_VERSION}.jar

# Install additional Python packages for data science
RUN pip install --no-cache-dir \
    jupyter \
    jupyterlab \
    matplotlib \
    seaborn \
    scikit-learn \
    scipy \
    arrow \
    pyarrow

# Create working directory
WORKDIR /workspace

# Copy GPU discovery script
COPY scripts/gpu-discovery.sh /opt/spark/gpu-discovery.sh
RUN chmod +x /opt/spark/gpu-discovery.sh

# Copy Spark configuration
COPY docker/spark-4.1/conf/log4j2.properties ${SPARK_HOME}/conf/log4j2.properties

# Expose Spark ports
EXPOSE 7077 7078 7079 8080 8081 15002 18080

# Set default command
CMD ["/opt/spark/bin/spark-class", "org.apache.spark.deploy.sparksubmit.SparkSubmit", "--help"]

# Build arguments for metadata
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=4.1.0-gpu

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.title="Spark with RAPIDS GPU Support" \
      org.opencontainers.image.description="Apache Spark ${SPARK_VERSION} with NVIDIA RAPIDS for GPU-accelerated data processing" \
      org.opencontainers.image.vendor="Spark K8s Constructor" \
      nvidia.cuda.version="12.1.0" \
      nvidia.cudnn.version="8" \
      rapids.version="${RAPIDS_VERSION}"
