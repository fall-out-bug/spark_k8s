# Spark 3.5.7 with S3 API v2 (AWS SDK v2), JDBC drivers, Hive Metastore
# Optimized for OpenShift (non-root user)
ARG SPARK_VERSION=3.5.7
ARG SCALA_VERSION=2.12
ARG JAVA_VERSION=17

FROM apache/spark:${SPARK_VERSION}-scala${SCALA_VERSION}-java${JAVA_VERSION}-python3-ubuntu

USER root

# Re-declare ARGs needed after FROM (ARGs before FROM are only available in FROM)
ARG SCALA_VERSION=2.12
ARG SPARK_VERSION=3.5.7

# Versions - Hadoop 3.4.1 with AWS SDK v2
ARG HADOOP_VERSION=3.4.1
ARG AWS_SDK_V2_VERSION=2.25.11
ARG VERTICA_JDBC_VERSION=24.4.0-0
ARG ORACLE_JDBC_VERSION=23.6.0.24.10
ARG POSTGRES_JDBC_VERSION=42.7.3
ARG HIVE_VERSION=3.1.3
# DataNucleus versions must match Hive Metastore expectations.
# Hive 3.1.x is compatible with DataNucleus 5.1.x; newer 5.2.x can break at runtime.
ARG DATANUCLEUS_API_JDO_VERSION=5.1.2
ARG DATANUCLEUS_CORE_VERSION=5.1.2
ARG DATANUCLEUS_RDBMS_VERSION=5.1.2

# Install additional tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    netcat-openbsd \
    procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/spark

# Remove old Hadoop AWS JARs from base image (3.3.4)
RUN rm -f /opt/spark/jars/hadoop-aws-*.jar \
          /opt/spark/jars/aws-java-sdk-bundle-*.jar \
          /opt/spark/jars/hadoop-client-api-*.jar \
          /opt/spark/jars/hadoop-client-runtime-*.jar 2>/dev/null || true

# Download Hadoop 3.4.1 with AWS SDK v2 support
RUN wget -q -P /opt/spark/jars/ \
    "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar" && \
    wget -q -P /opt/spark/jars/ \
    "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-client-api/${HADOOP_VERSION}/hadoop-client-api-${HADOOP_VERSION}.jar" && \
    wget -q -P /opt/spark/jars/ \
    "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-client-runtime/${HADOOP_VERSION}/hadoop-client-runtime-${HADOOP_VERSION}.jar" && \
    wget -q -P /opt/spark/jars/ \
    "https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/${AWS_SDK_V2_VERSION}/bundle-${AWS_SDK_V2_VERSION}.jar"

# JDBC Drivers
# Vertica
RUN wget -q -P /opt/spark/jars/ \
    "https://repo1.maven.org/maven2/com/vertica/jdbc/vertica-jdbc/${VERTICA_JDBC_VERSION}/vertica-jdbc-${VERTICA_JDBC_VERSION}.jar"

# Oracle
RUN wget -q -P /opt/spark/jars/ \
    "https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc11/${ORACLE_JDBC_VERSION}/ojdbc11-${ORACLE_JDBC_VERSION}.jar"

# PostgreSQL (also used for Hive Metastore backend)
RUN wget -q -P /opt/spark/jars/ \
    "https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_JDBC_VERSION}/postgresql-${POSTGRES_JDBC_VERSION}.jar"

# Spark Connect server JAR
RUN wget -q -P /opt/spark/jars/ \
    "https://repo1.maven.org/maven2/org/apache/spark/spark-connect_${SCALA_VERSION}/${SPARK_VERSION}/spark-connect_${SCALA_VERSION}-${SPARK_VERSION}.jar"

# Spark Hadoop Cloud module for S3A committer support
RUN wget -q -P /opt/spark/jars/ \
    "https://repo1.maven.org/maven2/org/apache/spark/spark-hadoop-cloud_${SCALA_VERSION}/${SPARK_VERSION}/spark-hadoop-cloud_${SCALA_VERSION}-${SPARK_VERSION}.jar"

# Hive Metastore standalone JARs
# NOTE: keep them separate from Spark jars to avoid classpath conflicts.
ARG DISRUPTOR_VERSION=3.4.4
ARG GUAVA_VERSION=27.0-jre
RUN mkdir -p /opt/hive-metastore/lib && \
    wget -q -P /opt/hive-metastore/lib/ \
      "https://repo1.maven.org/maven2/org/apache/hive/hive-standalone-metastore/${HIVE_VERSION}/hive-standalone-metastore-${HIVE_VERSION}.jar" && \
    wget -q -P /opt/hive-metastore/lib/ \
      "https://repo1.maven.org/maven2/org/apache/hive/hive-exec/${HIVE_VERSION}/hive-exec-${HIVE_VERSION}.jar" && \
    wget -q -P /opt/hive-metastore/lib/ \
      "https://repo1.maven.org/maven2/org/datanucleus/datanucleus-api-jdo/${DATANUCLEUS_API_JDO_VERSION}/datanucleus-api-jdo-${DATANUCLEUS_API_JDO_VERSION}.jar" && \
    wget -q -P /opt/hive-metastore/lib/ \
      "https://repo1.maven.org/maven2/org/datanucleus/datanucleus-core/${DATANUCLEUS_CORE_VERSION}/datanucleus-core-${DATANUCLEUS_CORE_VERSION}.jar" && \
    wget -q -P /opt/hive-metastore/lib/ \
      "https://repo1.maven.org/maven2/org/datanucleus/datanucleus-rdbms/${DATANUCLEUS_RDBMS_VERSION}/datanucleus-rdbms-${DATANUCLEUS_RDBMS_VERSION}.jar" && \
    wget -q -P /opt/hive-metastore/lib/ \
      "https://repo1.maven.org/maven2/org/datanucleus/javax.jdo/3.2.0-m3/javax.jdo-3.2.0-m3.jar" && \
    wget -q -P /opt/hive-metastore/lib/ \
      "https://repo1.maven.org/maven2/com/lmax/disruptor/${DISRUPTOR_VERSION}/disruptor-${DISRUPTOR_VERSION}.jar" && \
    wget -q -P /opt/hive-metastore/lib/ \
      "https://repo1.maven.org/maven2/com/google/guava/guava/${GUAVA_VERSION}/guava-${GUAVA_VERSION}.jar"

# Install Python packages for pandas API and Spark Connect dependencies
# PySpark is already in the base image, we just need connect extras
RUN pip install --no-cache-dir \
    pyarrow>=14.0.0 \
    pandas>=2.0.0 \
    numpy>=1.24.0 \
    boto3>=1.34.0 \
    grpcio>=1.60.0 \
    grpcio-status>=1.60.0 \
    googleapis-common-protos>=1.56.4

# Copy default configurations (with proper permissions)
COPY --chmod=644 conf/spark-defaults.conf /opt/spark/conf/spark-defaults.conf
COPY --chmod=644 conf/log4j2.properties /opt/spark/conf/log4j2.properties
COPY --chmod=755 conf/spark-env.sh /opt/spark/conf/spark-env.sh

# Entrypoint script for flexible startup
COPY --chmod=755 entrypoint.sh /opt/spark/entrypoint.sh

# Create directories for logs and work + set all permissions
RUN mkdir -p /opt/spark/work-dir /opt/spark/logs /tmp/spark-events && \
    chmod -R 777 /opt/spark/work-dir /opt/spark/logs /tmp/spark-events && \
    chmod g+w /etc/passwd && \
    chmod -R 755 /opt/spark/conf && \
    chmod -R g+rwX /opt/spark && \
    chmod 755 /opt/spark/entrypoint.sh && \
    chmod 644 /opt/spark/conf/spark-defaults.conf /opt/spark/conf/log4j2.properties && \
    chmod -R a+r /opt/spark/conf

# Set environment variables
ENV SPARK_HOME=/opt/spark
ENV PATH="${SPARK_HOME}/bin:${PATH}"
ENV PYTHONPATH="${SPARK_HOME}/python:${SPARK_HOME}/python/lib/py4j-0.10.9.7-src.zip:${PYTHONPATH}"

# Default user for OpenShift (non-root)
USER 185

WORKDIR /opt/spark/work-dir

ENTRYPOINT ["/opt/spark/entrypoint.sh"]
