# Build ResourceWaitTracker SparkListener
FROM eclipse-temurin:17-jdk-alpine AS builder

# Install SBT
RUN apk add --no-cache sbt

# Set working directory
WORKDIR /app

# Copy project files
COPY build.sbt .
COPY project/build.properties project/
COPY project/plugins.sbt project/
COPY src/main/scala/*.scala src/main/scala/

# Build JAR with SBT
RUN sbt clean assembly

# Final stage - copy JAR only
FROM eclipse-temurin:17-jre-alpine

WORKDIR /opt/spark/jars

# Copy JAR from builder
COPY --from=builder /app/target/scala-2.12/resource-wait-tracker.jar .

# Set permissions
RUN chmod 644 /opt/spark/jars/*.jar

# Verify
RUN ls -la /opt/spark/jars/

ENTRYPOINT ["java"]
CMD ["-cp", "/opt/spark/jars/resource-wait-tracker.jar", "org.apache.spark.scheduler.ResourceWaitTracker"]
