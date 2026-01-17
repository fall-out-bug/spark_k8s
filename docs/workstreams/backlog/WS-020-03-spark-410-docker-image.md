## WS-020-03: Spark 4.1.0 Docker Image (Multi-Stage Build)

### 🎯 Goal

**What should WORK after WS completion:**
- Dockerfile for Spark 4.1.0 exists with multi-stage build (builder + runtime)
- Image includes Spark Connect, Kubernetes, Hadoop, Hive profiles
- Dependencies (Celeborn client, hadoop-aws) are packaged via Maven
- Image builds successfully and is loadable into Minikube
- Image supports modes: `connect`, `driver`, `executor`, `history`

**Acceptance Criteria:**
- [ ] `docker/spark-4.1/Dockerfile` exists with builder and runtime stages
- [ ] `docker/spark-4.1/deps/pom.xml` defines Maven dependencies (spark-connect, celeborn, hadoop-aws)
- [ ] `docker/spark-4.1/deps/requirements.txt` defines Python dependencies (pyspark 4.1.0, pandas, pyarrow)
- [ ] `docker/spark-4.1/entrypoint.sh` supports modes: `connect`, `driver`, `executor`, `history`
- [ ] `docker/spark-4.1/conf/` contains Spark configuration templates
- [ ] Image builds: `docker build -t spark-custom:4.1.0 docker/spark-4.1`
- [ ] Image loaded into Minikube: `minikube image load spark-custom:4.1.0`

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 requires a Spark 4.1.0 image to support:
1. **Spark Connect** server (gRPC)
2. **Kubernetes native executors** (driver + executor modes)
3. **Optional Celeborn** shuffle client
4. **History Server** (reuse existing entrypoint logic)

Build strategy is inspired by [aagumin/spark-connect-kubernetes](https://github.com/aagumin/spark-connect-kubernetes), using multi-stage Docker build.

### Dependency

Independent (can run in parallel with WS-020-01, WS-020-02)

### Input Files

**Reference:**
- `/home/fall_out_bug/projects/spark-connect-kubernetes/docker/Dockerfile` — Multi-stage build pattern
- `/home/fall_out_bug/projects/spark-connect-kubernetes/deps/pom.xml` — Maven dependencies
- `/home/fall_out_bug/projects/spark-connect-kubernetes/deps/requirements.txt` — Python dependencies
- `docker/spark/Dockerfile` — Existing Spark 3.5.7 image for comparison
- `docker/spark/entrypoint.sh` — Existing entrypoint to adapt

### Steps

1. **Create directory structure:**
   ```bash
   mkdir -p docker/spark-4.1/{conf,deps}
   ```

2. **Create `docker/spark-4.1/Dockerfile`:**

   **Stage 1: Builder**
   ```dockerfile
   FROM eclipse-temurin:17 AS builder
   
   ARG SPARK_VERSION=4.1.0
   WORKDIR /build
   
   # Install build tools
   RUN apt-get update && apt-get install -y \
       wget curl git maven && \
       rm -rf /var/lib/apt/lists/*
   
   # Download Spark
   RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}.tgz && \
       tar -xzf spark-${SPARK_VERSION}.tgz && \
       mv spark-${SPARK_VERSION} /opt/spark
   
   WORKDIR /opt/spark
   
   # Build Spark with profiles
   RUN ./dev/make-distribution.sh \
       -Pconnect \
       -Pkubernetes \
       -Phadoop-3 \
       -Phadoop-cloud \
       -Phive \
       -DskipTests
   
   # Copy built distribution
   RUN mkdir -p /opt/spark-dist && \
       cp -r /opt/spark/dist/* /opt/spark-dist/
   ```

   **Stage 2: Runtime**
   ```dockerfile
   FROM python:3.10-slim-bookworm
   
   # Install runtime dependencies
   RUN apt-get update && apt-get install -y \
       openjdk-17-jre-headless \
       tini \
       procps \
       && rm -rf /var/lib/apt/lists/*
   
   # Copy Spark from builder
   COPY --from=builder /opt/spark-dist /opt/spark
   
   # Set environment
   ENV SPARK_HOME=/opt/spark
   ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
   ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-*.zip
   
   # Copy Maven dependencies descriptor
   COPY deps/pom.xml /tmp/deps/
   RUN apt-get update && apt-get install -y maven && \
       mvn dependency:copy-dependencies \
           -f /tmp/deps/pom.xml \
           -DoutputDirectory=$SPARK_HOME/jars && \
       apt-get remove -y maven && apt-get autoremove -y && \
       rm -rf /var/lib/apt/lists/* /root/.m2
   
   # Install Python dependencies
   COPY deps/requirements.txt /tmp/
   RUN pip install --no-cache-dir -r /tmp/requirements.txt
   
   # Copy configuration and entrypoint
   COPY conf/* $SPARK_HOME/conf/
   COPY entrypoint.sh /opt/
   RUN chmod +x /opt/entrypoint.sh
   
   # Create non-root user
   RUN groupadd -g 185 spark && \
       useradd -u 185 -g 185 -d /home/spark -m spark && \
       chown -R spark:spark /opt/spark
   
   # Create writable directories (PSS compliance)
   RUN mkdir -p /tmp/spark-events /tmp/spark-logs && \
       chown spark:spark /tmp/spark-events /tmp/spark-logs
   
   USER 185
   WORKDIR /home/spark
   
   ENTRYPOINT ["/usr/bin/tini", "--", "/opt/entrypoint.sh"]
   ```

3. **Create `docker/spark-4.1/deps/pom.xml`:**
   ```xml
   <project xmlns="http://maven.apache.org/POM/4.0.0">
     <modelVersion>4.0.0</modelVersion>
     <groupId>org.apache.spark</groupId>
     <artifactId>spark-dependencies</artifactId>
     <version>1.0</version>
     
     <dependencies>
       <!-- Spark Connect -->
       <dependency>
         <groupId>org.apache.spark</groupId>
         <artifactId>spark-connect_2.12</artifactId>
         <version>4.1.0</version>
       </dependency>
       
       <!-- Celeborn Shuffle Client -->
       <dependency>
         <groupId>org.apache.celeborn</groupId>
         <artifactId>celeborn-client-spark-3-shaded_2.12</artifactId>
         <version>0.6.1</version>
       </dependency>
       
       <!-- Hadoop AWS (S3A support) -->
       <dependency>
         <groupId>org.apache.hadoop</groupId>
         <artifactId>hadoop-aws</artifactId>
         <version>3.4.2</version>
       </dependency>
     </dependencies>
   </project>
   ```

4. **Create `docker/spark-4.1/deps/requirements.txt`:**
   ```
   pyspark==4.1.0
   pandas>=2.0.0
   pyarrow>=10.0.0
   numpy>=1.24.0
   grpcio>=1.56.0
   grpcio-status>=1.56.0
   ```

5. **Create `docker/spark-4.1/entrypoint.sh`:**
   
   Adapt from `docker/spark/entrypoint.sh`:
   ```bash
   #!/bin/bash
   set -e
   
   SPARK_MODE="${SPARK_MODE:-connect}"
   
   case "$SPARK_MODE" in
     connect)
       exec /opt/spark/sbin/start-connect-server.sh \
         --packages org.apache.spark:spark-connect_2.12:4.1.0 \
         --conf spark.plugins=org.apache.spark.sql.connect.SparkConnectPlugin
       ;;
     driver)
       exec /opt/spark/bin/spark-submit "$@"
       ;;
     executor)
       exec /opt/spark/bin/spark-class org.apache.spark.executor.CoarseGrainedExecutorBackend "$@"
       ;;
     history)
       export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=${SPARK_HISTORY_LOG_DIR:-s3a://spark-logs/events}"
       exec /opt/spark/sbin/start-history-server.sh
       ;;
     *)
       exec "$@"
       ;;
   esac
   ```

6. **Create `docker/spark-4.1/conf/spark-defaults.conf`:**
   ```properties
   spark.master                     k8s://https://kubernetes.default.svc.cluster.local:443
   spark.kubernetes.authenticate.driver.serviceAccountName=spark
   spark.hadoop.fs.s3a.impl         org.apache.hadoop.fs.s3a.S3AFileSystem
   spark.hadoop.fs.s3a.path.style.access  true
   spark.eventLog.enabled           true
   spark.eventLog.dir               s3a://spark-logs/4.1/events
   ```

7. **Build and test image:**
   ```bash
   cd docker/spark-4.1
   docker build -t spark-custom:4.1.0 .
   
   # Load into Minikube
   minikube image load spark-custom:4.1.0
   
   # Test entrypoint modes
   docker run --rm spark-custom:4.1.0 spark-submit --version
   ```

### Expected Result

```
docker/spark-4.1/
├── Dockerfile              # ~120 LOC
├── entrypoint.sh           # ~60 LOC
├── conf/
│   ├── spark-defaults.conf # ~20 LOC
│   └── log4j2.properties   # ~30 LOC (copy from docker/spark/conf/)
└── deps/
    ├── pom.xml             # ~30 LOC
    └── requirements.txt    # ~10 LOC
```

### Scope Estimate

- Files: 6 created
- Lines: ~270 LOC (SMALL)
- Tokens: ~1200
- Build time: ~15-20 minutes

### Completion Criteria

```bash
# Build image
docker build -t spark-custom:4.1.0 docker/spark-4.1

# Verify image size (<2GB preferred)
docker images spark-custom:4.1.0

# Test entrypoint modes
docker run --rm spark-custom:4.1.0 spark-submit --version | grep "4.1.0"
docker run --rm -e SPARK_MODE=history spark-custom:4.1.0 echo "History mode OK"

# Load into Minikube
minikube image load spark-custom:4.1.0
minikube image ls | grep spark-custom:4.1.0
```

### Constraints

- DO NOT include Hive Metastore binaries (separate image)
- DO NOT bundle example JARs (reduce image size)
- USE non-root user (uid 185)
- ENSURE PSS `restricted` compatibility (writable paths via emptyDir in K8s)
- Pin all dependency versions (no `latest` tags)
