# JDBC Drivers Intermediate Layer for Spark K8s
# Extends custom Spark builds to add MySQL and MSSQL JDBC drivers
# Note: Custom builds already include PostgreSQL, Oracle, Vertica drivers

ARG BASE_IMAGE=spark-k8s:3.5.7-hadoop3.4.2
FROM ${BASE_IMAGE}

# Labels for metadata
LABEL maintainer="spark-k8s" \
      description="JDBC drivers layer - adds MySQL, MSSQL to custom builds" \
      version="2.0.0"

# JDBC driver versions (for additional drivers)
ARG MYSQL_DRIVER_VERSION=9.1.0
ARG MSSQL_DRIVER_VERSION=12.4.2.jre11

# Switch to root for installation
USER root

# Install wget and unzip if not available
RUN apt-get update && apt-get install -y wget ca-certificates unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create JDBC directory for convenience symlinks
RUN mkdir -p /opt/jdbc && \
    chown -R spark:spark /opt/jdbc

# Verify existing drivers from custom build
RUN echo "=== Existing JDBC drivers in custom build ===" && \
    ls -la ${SPARK_HOME}/jars/postgresql*.jar && \
    ls -la ${SPARK_HOME}/jars/ojdbc*.jar && \
    ls -la ${SPARK_HOME}/jars/vertica*.jar && \
    echo ""

# Download MySQL driver (not in custom build)
RUN wget -q --tries=3 --timeout=30 \
    https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_DRIVER_VERSION}/mysql-connector-j-${MYSQL_DRIVER_VERSION}.jar \
    -O ${SPARK_HOME}/jars/mysql-connector-j.jar && \
    echo "MySQL JDBC driver ${MYSQL_DRIVER_VERSION} installed"

# Download MSSQL driver (not in custom build)
RUN wget -q --tries=3 --timeout=30 \
    https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/${MSSQL_DRIVER_VERSION}/mssql-jdbc-${MSSQL_DRIVER_VERSION}.jar \
    -O ${SPARK_HOME}/jars/mssql-jdbc.jar && \
    echo "MSSQL JDBC driver ${MSSQL_DRIVER_VERSION} installed"

# Create convenience symlinks in /opt/jdbc
RUN ln -sf ${SPARK_HOME}/jars/mysql-connector-j.jar /opt/jdbc/mysql.jar && \
    ln -sf ${SPARK_HOME}/jars/mssql-jdbc.jar /opt/jdbc/mssql.jar && \
    ln -sf ${SPARK_HOME}/jars/postgresql*.jar /opt/jdbc/postgresql.jar && \
    ln -sf ${SPARK_HOME}/jars/ojdbc*.jar /opt/jdbc/oracle.jar && \
    ln -sf ${SPARK_HOME}/jars/vertica*.jar /opt/jdbc/vertica.jar

# Verify all drivers are present
RUN echo "=== Final JDBC driver inventory ===" && \
    echo "PostgreSQL:" && ls -la ${SPARK_HOME}/jars/postgresql*.jar && \
    echo "Oracle:" && ls -la ${SPARK_HOME}/jars/ojdbc*.jar && \
    echo "Vertica:" && ls -la ${SPARK_HOME}/jars/vertica*.jar && \
    echo "MySQL:" && ls -la ${SPARK_HOME}/jars/mysql*.jar && \
    echo "MSSQL:" && ls -la ${SPARK_HOME}/jars/mssql*.jar && \
    echo ""

# Set environment variables
ENV JDBC_DRIVERS=/opt/jdbc

# Switch back to non-root user (matches custom Spark build)
USER 185

# Health check to verify drivers are accessible
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ls -la ${SPARK_HOME}/jars/*jdbc*.jar ${SPARK_HOME}/jars/mysql*.jar ${SPARK_HOME}/jars/mssql*.jar >/dev/null 2>&1 || exit 1

# Working directory
WORKDIR /opt/spark/work-dir

# Default command (list all JDBC drivers)
CMD ["bash", "-c", "echo '=== JDBC Drivers ===' && ls -la ${SPARK_HOME}/jars/*jdbc*.jar ${SPARK_HOME}/jars/mysql*.jar ${SPARK_HOME}/jars/mssql*.jar 2>/dev/null || echo 'Ready'"]
