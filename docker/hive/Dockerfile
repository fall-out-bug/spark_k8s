# Custom Hive image with PostgreSQL JDBC 42.7+ (supports SCRAM-SHA-256, Postgres 15+)
ARG HIVE_VERSION=3.1.3

# Stage: download JDBC driver (no curl in apache/hive image)
FROM alpine:3.19 AS jdbc
ARG PGJDBC_URL=https://jdbc.postgresql.org/download/postgresql-42.7.10.jar
RUN wget -q -O /postgresql-jdbc.jar "${PGJDBC_URL}"

FROM apache/hive:${HIVE_VERSION}
COPY --from=jdbc /postgresql-jdbc.jar /opt/hive/lib/postgresql-jdbc.jar
RUN ln -sf /opt/hive/lib/postgresql-jdbc.jar /opt/hadoop/share/hadoop/common/lib/postgresql-jdbc.jar && \
    ls -la /opt/hive/lib/postgresql-jdbc.jar
