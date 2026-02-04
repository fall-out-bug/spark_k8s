# JDBC Drivers Intermediate Layer for Spark K8s
# Extends JDK 17 base image with common JDBC drivers
# Includes: PostgreSQL, MySQL, Oracle, MSSQL, Vertica

ARG BASE_IMAGE=spark-k8s-jdk-17:latest
FROM ${BASE_IMAGE}

# Labels for metadata
LABEL maintainer="spark-k8s"
LABEL description="JDBC drivers intermediate layer for Spark K8s"
LABEL version="1.0.0"

# JDBC driver versions
ARG POSTGRES_DRIVER_VERSION=42.7.2
ARG MYSQL_DRIVER_VERSION=9.1.0
ARG ORACLE_DRIVER_VERSION=21.11.0.0
ARG MSSQL_DRIVER_VERSION=12.4.2.jre11
ARG VERTICA_DRIVER_VERSION=12.0.4-0

# Switch to root for installation
USER root

# Install wget if not available (for Alpine)
RUN apk add --no-cache wget ca-certificates 2>/dev/null || true

# Create JDBC directory with proper permissions
RUN mkdir -p /opt/jdbc && \
    chown -R spark:spark /opt/jdbc

# Download PostgreSQL driver
RUN wget -q --tries=3 --timeout=30 \
    https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_DRIVER_VERSION}/postgresql-${POSTGRES_DRIVER_VERSION}.jar \
    -O /opt/jdbc/postgresql.jar && \
    echo "PostgreSQL JDBC driver ${POSTGRES_DRIVER_VERSION} installed"

# Download MySQL driver
RUN wget -q --tries=3 --timeout=30 \
    https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_DRIVER_VERSION}/mysql-connector-j-${MYSQL_DRIVER_VERSION}.jar \
    -O /opt/jdbc/mysql.jar && \
    echo "MySQL JDBC driver ${MYSQL_DRIVER_VERSION} installed"

# Download Oracle driver (ojdbc11 for Java 17)
RUN wget -q --tries=3 --timeout=30 \
    https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc11/${ORACLE_DRIVER_VERSION}/ojdbc11-${ORACLE_DRIVER_VERSION}.jar \
    -O /opt/jdbc/oracle.jar && \
    echo "Oracle JDBC driver ${ORACLE_DRIVER_VERSION} installed"

# Download MSSQL driver (mssql-jdbc)
RUN wget -q --tries=3 --timeout=30 \
    https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/${MSSQL_DRIVER_VERSION}/mssql-jdbc-${MSSQL_DRIVER_VERSION}.jar \
    -O /opt/jdbc/mssql.jar && \
    echo "MSSQL JDBC driver ${MSSQL_DRIVER_VERSION} installed"

# Download Vertica driver
RUN wget -q --tries=3 --timeout=30 \
    https://repo1.maven.org/maven2/com/vertica/jdbc/vertica-jdbc/${VERTICA_DRIVER_VERSION}/vertica-jdbc-${VERTICA_DRIVER_VERSION}.jar \
    -O /opt/jdbc/vertica.jar && \
    echo "Vertica JDBC driver ${VERTICA_DRIVER_VERSION} installed"

# Verify all drivers are present and set permissions
RUN ls -la /opt/jdbc/*.jar && \
    chmod 644 /opt/jdbc/*.jar && \
    chown spark:spark /opt/jdbc/*.jar && \
    echo "JDBC drivers installed successfully"

# Set environment variables
ENV JDBC_DRIVERS=/opt/jdbc
ENV CLASSPATH="/opt/jdbc/postgresql.jar:/opt/jdbc/mysql.jar:/opt/jdbc/oracle.jar:/opt/jdbc/mssql.jar:/opt/jdbc/vertica.jar"

# Switch back to non-root user
USER spark

# Health check to verify drivers are accessible
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ls -la /opt/jdbc/*.jar >/dev/null 2>&1 || exit 1

# Working directory
WORKDIR /opt

# Default command
CMD ["/bin/bash"]
