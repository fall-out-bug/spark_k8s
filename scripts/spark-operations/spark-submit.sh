#!/bin/bash
# ===================================================================
# Spark Job Submit Helper
# ===================================================================
# Simplified Spark job submission with common configurations
#
# Usage:
#   ./spark-submit.sh <job-file> [preset] [options]
#
# Examples:
#   ./spark-submit.sh examples/ml/regression.py ml-regression
#   ./spark-submit.sh examples/streaming/file_stream.py streaming --timeout 300
# ===================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHARTS_DIR="$(dirname "$SCRIPT_DIR")/charts/spark-3.5"

JOB_FILE="${1:-}"
PRESET="${2:-default}"
shift 2 2>/dev/null || true
EXTRA_OPTS="$@"

MASTER="${SPARK_MASTER:-spark://airflow-sc-standalone-master:7077}"
NAMESPACE="${K8S_NAMESPACE:-spark-airflow}"

SPARK_HOME="${SPARK_HOME:-/opt/spark}"

SPARK_SUBMIT="$SPARK_HOME/bin/spark-submit"

declare -A PRESET_CONFIGS

PRESET_CONFIGS[default]="--conf spark.sql.shuffle.partitions=20"
PRESET_CONFIGS[etl]="--conf spark.sql.shuffle.partitions=50 --conf spark.sql.adaptive.enabled=true"
PRESET_CONFIGS[streaming]="--conf spark.streaming.backpressure.enabled=true --conf spark.sql.streaming.checkpointLocation=/tmp/checkpoints"
PRESET_CONFIGS[ml-regression]="--conf spark.memory.fraction=0.6 --conf spark.sql.shuffle.partitions=20"
PRESET_CONFIGS[ml-classification]="--conf spark.memory.fraction=0.6 --conf spark.sql.execution.arrow.pyspark.enabled=true"
PRESET_CONFIGS[small]="--executor-memory 2g --conf spark.sql.shuffle.partitions=10"
PRESET_CONFIGS[large]="--executor-memory 8g --conf spark.sql.shuffle.partitions=100"

if [[ -z "$JOB_FILE" ]]; then
    echo "Usage: $0 <job-file> [preset] [options]"
    echo ""
    echo "Available presets:"
    for preset in "${!PRESET_CONFIGS[@]}"; do
        echo "  - $preset"
    done
    exit 1
fi

if [[ ! -f "$JOB_FILE" ]]; then
    echo "Error: Job file not found: $JOB_FILE"
    exit 1
fi

PRESET_OPTS="${PRESET_CONFIGS[$PRESET]:-${PRESET_CONFIGS[default]}}"

echo "=============================================="
echo "Spark Job Submission"
echo "=============================================="
echo "Job file:     $JOB_FILE"
echo "Preset:       $PRESET"
echo "Master:       $MASTER"
echo "Extra opts:   $EXTRA_OPTS"
echo ""

CMD="$SPARK_SUBMIT \
    --master $MASTER \
    $PRESET_OPTS \
    $EXTRA_OPTS \
    $JOB_FILE"

echo "Executing: $CMD"
echo ""

exec $CMD
