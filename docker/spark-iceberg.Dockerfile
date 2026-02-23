# Custom Spark 4.1.0 image with Apache Iceberg support
# Based on apache/spark:4.1.0

FROM apache/spark:4.1.0

# Switch to root for installing packages
USER root

# Copy Iceberg jar (downloaded locally)
COPY docker/iceberg-spark-runtime-4.0_2.13-1.10.0.jar /opt/spark/jars/

# Fix permissions
RUN chown spark:spark /opt/spark/jars/iceberg*.jar

# Verify Iceberg jar is present
RUN ls -lh /opt/spark/jars/iceberg*.jar

# Switch back to spark user
USER spark

ENTRYPOINT ["/opt/entrypoint.sh"]
