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

SPARK_CONF="$SPARK_CONF --conf spark.hadoop.fs.s3a.path.style.access=true"
SPARK_CONF="$SPARK_CONF --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem"

# Auto-detect executor mode (K8s sets SPARK_EXECUTOR_ID for executors)
if [ -n "$SPARK_EXECUTOR_ID" ]; then
  SPARK_MODE="executor"
fi

case "${SPARK_MODE:-connect}" in
  connect)
    echo "Starting Spark Connect server..."
    exec /opt/spark/sbin/start-connect-server.sh \
      --packages org.apache.spark:spark-connect_2.13:4.1.0 \
      --conf spark.connect.grpc.binding.port=${SPARK_CONNECT_PORT:-15002} \
      $SPARK_CONF
    ;;
  history)
    echo "Starting Spark History Server..."
    HISTORY_DIR="${SPARK_HISTORY_LOG_DIR:-s3a://spark-logs/4.1/events}"
    export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=$HISTORY_DIR"
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
    JAVA_OPTS_FROM_SPARK=""
    for i in $(seq 0 50); do
      var="SPARK_JAVA_OPT_$i"
      val="${!var}"
      if [ -n "$val" ]; then
        JAVA_OPTS_FROM_SPARK="$JAVA_OPTS_FROM_SPARK $val"
      fi
    done
    export SPARK_EXECUTOR_JAVA_OPTS="$JAVA_OPTS_FROM_SPARK"
    export _SPARK_CMD_USAGE_JAVA_OPTS="$JAVA_OPTS_FROM_SPARK"

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
    EXECUTOR_ARGS="$EXECUTOR_ARGS --hostname $(hostname -i)"
    if [ -n "$SPARK_RESOURCE_PROFILE_ID" ]; then
      EXECUTOR_ARGS="$EXECUTOR_ARGS --resourceProfileId $SPARK_RESOURCE_PROFILE_ID"
    fi
    exec /opt/spark/bin/spark-class org.apache.spark.executor.CoarseGrainedExecutorBackend $EXECUTOR_ARGS
    ;;
  *)
    exec "$@"
    ;;
esac
