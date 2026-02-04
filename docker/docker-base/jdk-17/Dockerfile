# JDK 17 Base Image for Spark K8s
# Uses eclipse-temurin:17-jre-alpine for minimal size
# Includes bash, curl, and ca-certificates for common operations

FROM eclipse-temurin:17-jre-alpine

# Labels for metadata
LABEL maintainer="spark-k8s"
LABEL description="JDK 17 base image for Spark K8s"
LABEL version="1.0.0"

# Install runtime utilities in a single layer
RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Set environment variables
ENV JAVA_HOME=/opt/java/openjdk \
    PATH="${JAVA_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Set working directory
WORKDIR /workspace

# Create non-root user for OpenShift compatibility
RUN addgroup -g 1000 -S spark && \
    adduser -u 1000 -S spark -G spark -h /workspace -s /bin/bash && \
    chown -R spark:spark /workspace

# Health check to verify Java runtime
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD java -version || exit 1

# Switch to non-root user
USER spark

# Default command
CMD ["/bin/bash"]
