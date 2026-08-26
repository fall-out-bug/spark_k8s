# Custom Hive image with PostgreSQL JDBC 42.7+ (supports SCRAM-SHA-256, Postgres 15+)
ARG HIVE_VERSION=3.1.3

# Stage: download JDBC driver (no curl in apache/hive image)
FROM alpine:3.19 AS jdbc
ARG PGJDBC_URL=https://jdbc.postgresql.org/download/postgresql-42.7.10.jar
RUN wget -q -O /postgresql-jdbc.jar "${PGJDBC_URL}"

FROM apache/hive:${HIVE_VERSION}
USER root
COPY --from=jdbc /postgresql-jdbc.jar /opt/hive/lib/postgresql-jdbc.jar
# The base image ships postgresql-9.4.1208.jre7.jar; it sorts before
# postgresql-jdbc.jar on the classpath, shadowing the SCRAM-capable 42.7
# driver (metastore then fails with "authentication type 10 is not supported").
# rm needs root: the base jar is root-owned.
RUN rm -f /opt/hive/lib/postgresql-9.4.1208.jre7.jar && \
    ln -sf /opt/hive/lib/postgresql-jdbc.jar /opt/hadoop/share/hadoop/common/lib/postgresql-jdbc.jar && \
    ls -la /opt/hive/lib/postgresql-jdbc.jar
USER hive
