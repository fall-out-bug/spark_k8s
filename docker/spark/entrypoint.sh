#!/bin/bash

set -e

# OpenShift compatibility - add current user to passwd
if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    echo "${USER_NAME:-spark}:x:$(id -u):0:${USER_NAME:-spark}:/opt/spark:/bin/bash" >> /etc/passwd
  fi
fi

# Set environment from secrets if available
if [ -f /etc/spark-secrets/s3-access-key ]; then
  export AWS_ACCESS_KEY_ID=$(cat /etc/spark-secrets/s3-access-key)
fi

if [ -f /etc/spark-secrets/s3-secret-key ]; then
  export AWS_SECRET_ACCESS_KEY=$(cat /etc/spark-secrets/s3-secret-key)
fi

# Build Spark configuration from environment
SPARK_CONF=""

if [ -n "$S3_ENDPOINT" ]; then
  SPARK_CONF="$SPARK_CONF --conf spark.hadoop.fs.s3a.endpoint=$S3_ENDPOINT"
fi

if [ -n "$AWS_ACCESS_KEY_ID" ]; then
  SPARK_CONF="$SPARK_CONF --conf spark.hadoop.fs.s3a.access.key=$AWS_ACCESS_KEY_ID"
fi

if [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
  SPARK_CONF="$SPARK_CONF --conf spark.hadoop.fs.s3a.secret.key=$AWS_SECRET_ACCESS_KEY"
fi

# Auto-detect executor mode (K8s sets SPARK_EXECUTOR_ID for executors)
if [ -n "$SPARK_EXECUTOR_ID" ]; then
  SPARK_MODE="executor"
fi

# Main entry point
case "${SPARK_MODE:-driver}" in
  master)
    echo "Starting Spark Master..."
    export SPARK_MASTER_HOST=$(hostname -i)
    export SPARK_MASTER_PORT=${SPARK_MASTER_PORT:-7077}
    export SPARK_MASTER_WEBUI_PORT=${SPARK_MASTER_WEBUI_PORT:-8080}
    # HA recovery via FILESYSTEM (supports s3a:// paths)
    if [ -n "$SPARK_RECOVERY_DIR" ]; then
      export SPARK_DAEMON_JAVA_OPTS="-Dspark.deploy.recoveryMode=FILESYSTEM -Dspark.deploy.recoveryDirectory=$SPARK_RECOVERY_DIR"
    fi
    exec /opt/spark/bin/spark-class org.apache.spark.deploy.master.Master \
      --host "$SPARK_MASTER_HOST" \
      --port "$SPARK_MASTER_PORT" \
      --webui-port "$SPARK_MASTER_WEBUI_PORT"
    ;;
  worker)
    echo "Starting Spark Worker..."
    export SPARK_WORKER_PORT=${SPARK_WORKER_PORT:-7078}
    export SPARK_WORKER_WEBUI_PORT=${SPARK_WORKER_WEBUI_PORT:-8081}
    # Wait for master to be ready
    until nc -z "${SPARK_MASTER_HOST:-spark-master}" "${SPARK_MASTER_PORT:-7077}"; do
      echo "Waiting for Spark Master..."
      sleep 2
    done
    exec /opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker \
      "spark://${SPARK_MASTER_HOST:-spark-master}:${SPARK_MASTER_PORT:-7077}" \
      --port "$SPARK_WORKER_PORT" \
      --webui-port "$SPARK_WORKER_WEBUI_PORT" \
      --cores "${SPARK_WORKER_CORES:-2}" \
      --memory "${SPARK_WORKER_MEMORY:-2g}"
    ;;
  shuffle)
    echo "Starting External Shuffle Service..."
    export SPARK_SHUFFLE_SERVICE_PORT=${SPARK_SHUFFLE_SERVICE_PORT:-7337}
    exec /opt/spark/bin/spark-class org.apache.spark.deploy.ExternalShuffleService
    ;;
  connect)
    echo "Starting Spark Connect server..."
    exec /opt/spark/bin/spark-submit \
      --class org.apache.spark.sql.connect.service.SparkConnectServer \
      $SPARK_CONF \
      --conf spark.connect.grpc.binding.port=15002 \
      local:///opt/spark/jars/spark-connect_2.12-*.jar
    ;;
  metastore)
    echo "Starting Hive Metastore..."
    # Initialize schema if needed (first run)
    /opt/spark/bin/spark-class org.apache.hadoop.hive.metastore.tools.MetastoreSchemaTool \
      -dbType postgres -initSchema --verbose 2>/dev/null || true
    # Start metastore service
    exec /opt/spark/bin/spark-class org.apache.hadoop.hive.metastore.HiveMetaStore
    ;;
  history)
    echo "Starting Spark History Server..."
    # History server uses SPARK_HISTORY_OPTS for configuration
    export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=s3a://spark-logs/events"
    if [ -n "$S3_ENDPOINT" ]; then
      export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS -Dspark.hadoop.fs.s3a.endpoint=$S3_ENDPOINT"
    fi
    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
      export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS -Dspark.hadoop.fs.s3a.access.key=$AWS_ACCESS_KEY_ID"
    fi
    if [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
      export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS -Dspark.hadoop.fs.s3a.secret.key=$AWS_SECRET_ACCESS_KEY"
    fi
    export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS -Dspark.hadoop.fs.s3a.path.style.access=true"
    export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS -Dspark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem"
    exec /opt/spark/bin/spark-class org.apache.spark.deploy.history.HistoryServer
    ;;
  driver)
    echo "Starting Spark driver..."
    exec /opt/spark/bin/spark-submit $SPARK_CONF "$@"
    ;;
  executor)
    echo "Starting Spark executor..."
    # Build Java options from SPARK_JAVA_OPT_* environment variables (set by Spark K8s)
    JAVA_OPTS_FROM_SPARK=""
    for i in $(seq 0 50); do
      var="SPARK_JAVA_OPT_$i"
      val="${!var}"
      if [ -n "$val" ]; then
        JAVA_OPTS_FROM_SPARK="$JAVA_OPTS_FROM_SPARK $val"
      fi
    done
    # Export for spark-class to pick up
    export SPARK_EXECUTOR_JAVA_OPTS="$JAVA_OPTS_FROM_SPARK"
    export _SPARK_CMD_USAGE_JAVA_OPTS="$JAVA_OPTS_FROM_SPARK"

    # Build executor arguments from environment variables (set by Spark K8s)
    EXECUTOR_ARGS=""
    if [ -n "$SPARK_DRIVER_URL" ]; then
      EXECUTOR_ARGS="$EXECUTOR_ARGS --driver-url $SPARK_DRIVER_URL"
    fi
    if [ -n "$SPARK_EXECUTOR_ID" ]; then
      EXECUTOR_ARGS="$EXECUTOR_ARGS --executor-id $SPARK_EXECUTOR_ID"
    fi
    if [ -n "$SPARK_EXECUTOR_CORES" ]; then
      EXECUTOR_ARGS="$EXECUTOR_ARGS --cores $SPARK_EXECUTOR_CORES"
    fi
    if [ -n "$SPARK_APPLICATION_ID" ]; then
      EXECUTOR_ARGS="$EXECUTOR_ARGS --app-id $SPARK_APPLICATION_ID"
    fi
    # Get hostname for executor binding
    EXECUTOR_ARGS="$EXECUTOR_ARGS --hostname $(hostname -i)"
    if [ -n "$SPARK_RESOURCE_PROFILE_ID" ]; then
      EXECUTOR_ARGS="$EXECUTOR_ARGS --resourceProfileId $SPARK_RESOURCE_PROFILE_ID"
    fi
    exec /opt/spark/bin/spark-class org.apache.spark.executor.CoarseGrainedExecutorBackend $EXECUTOR_ARGS
    ;;
  shell)
    echo "Starting PySpark shell..."
    exec /opt/spark/bin/pyspark $SPARK_CONF "$@"
    ;;
  *)
    # Run custom command
    exec "$@"
    ;;
esac
