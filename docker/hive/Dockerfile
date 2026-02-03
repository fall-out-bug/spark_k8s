# Custom Hive image with PostgreSQL JDBC driver
ARG HIVE_VERSION=4.0.0
FROM apache/hive:${HIVE_VERSION}

# Copy PostgreSQL JDBC driver from local build context
COPY postgresql-jdbc.jar /opt/hive/lib/postgresql-jdbc.jar
RUN ln -s /opt/hive/lib/postgresql-jdbc.jar /opt/hadoop/share/hadoop/common/lib/postgresql-jdbc.jar

# Verify driver is present
RUN ls -la /opt/hive/lib/postgresql-jdbc.jar
