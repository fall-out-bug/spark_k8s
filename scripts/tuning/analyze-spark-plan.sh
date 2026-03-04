#!/bin/bash
# Analyze Spark query plan for performance insights
# Usage: analyze-spark-plan.sh <event_log_path> [app_id]

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <event_log_path> [app_id]"
    echo "  event_log_path: Path to Spark event log (local or s3a://)"
    echo "  app_id: Optional Spark application ID to filter"
    exit 1
}

[[ $# -lt 1 ]] && usage

EVENT_LOG="$1"
# Optional: APP_ID="$2" for filtering specific application

# Check for spark-submit or spark-shell
if ! command -v spark-submit &>/dev/null; then
    echo "spark-submit not found. Install Spark or run in Spark environment."
    exit 1
fi

echo "Analyzing plan for: $EVENT_LOG"

# Use Spark's EventLogReader if available, or provide guidance
cat <<'EOF'
To analyze Spark plan from event log:

1. Open Spark UI (History Server) and navigate to the application
2. Check SQL tab for query plans
3. Look for:
   - Exchange (shuffle) nodes
   - SortMergeJoin vs BroadcastJoin
   - Skew in partition sizes
   - Predicate pushdown

4. Or use spark-submit with event log:
   spark-submit --class org.apache.spark.sql.execution.ui.SQLAppStatusListener \
     $SPARK_HOME/jars/spark-sql*.jar $EVENT_LOG

For programmatic analysis, use Spark's SparkSession.read.json() on event log.
EOF

exit 0
