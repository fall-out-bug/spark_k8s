#!/bin/bash
# Break down Spark job costs by component
#
# Usage:
#   ./cost-breakdown.sh --job-id <id> --start <timestamp> --end <timestamp>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Configuration
JOB_ID=""
START_TIME=""
END_TIME=""
PROMETHEUS_URL=${PROMETHEUS_URL:-"http://prometheus:9090"}

# Cost rates (USD)
CPU_RATE_ONDEMAND=0.192  # per CPU hour (m5.xlarge)
MEMORY_RATE_ONDEMAND=0.002  # per GB hour
CPU_RATE_SPOT=0.058
MEMORY_RATE_SPOT=0.001
STORAGE_RATE=0.023  # per GB month
NETWORK_RATE=0.09  # per GB

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --job-id)
            JOB_ID="$2"
            shift 2
            ;;
        --start)
            START_TIME="$2"
            shift 2
            ;;
        --end)
            END_TIME="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$JOB_ID" || -z "$START_TIME" || -z "$END_TIME" ]]; then
    log_error "Usage: $0 --job-id <id> --start <timestamp> --end <timestamp>"
    exit 1
fi

log_info "=== Cost Breakdown for Job: ${JOB_ID} ==="
log_info "Start: ${START_TIME}"
log_info "End: ${END_TIME}"

# Convert timestamps to Unix epoch
START_EPOCH=$(date -d "$START_TIME" +%s)
END_EPOCH=$(date -d "$END_TIME" +%s)
DURATION_SECONDS=$((END_EPOCH - START_EPOCH))
DURATION_HOURS=$(echo "scale=2; $DURATION_SECONDS / 3600" | bc)

log_info "Duration: ${DURATION_HOURS} hours"

# Query Prometheus for metrics
log_info "Querying Prometheus metrics..."

# Driver CPU usage (seconds)
DRIVER_CPU_QUERY="sum(rate(container_cpu_usage_seconds_total{job_name=\"${JOB_ID}\",spark_role=\"driver\"}[${DURATION_SECONDS}s]))"

# Driver memory usage (GB-hours)
DRIVER_MEM_QUERY="avg(container_memory_working_set_bytes{job_name=\"${JOB_ID}\",spark_role=\"driver\"}) / 1024 / 1024 / 1024"

# Executor CPU usage (seconds)
EXEC_CPU_QUERY="sum(rate(container_cpu_usage_seconds_total{job_name=\"${JOB_ID}\",spark_role=\"executor\"}[${DURATION_SECONDS}s]))"

# Executor memory usage (GB-hours)
EXEC_MEM_QUERY="avg(container_memory_working_set_bytes{job_name=\"${JOB_ID}\",spark_role=\"executor\"}) / 1024 / 1024 / 1024"

# Spot vs on-demand
SPOT_QUERY="count(kube_pod_labels{label_spark_node_selector=\"spot\"}) or count(kube_pod_labels{label_spark_node_selector=\"on-demand\"})"

# Execute queries
DRIVER_CPU_SECONDS=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${DRIVER_CPU_QUERY}" | jq -r '.data.result[0].value[1]' || echo "0")
DRIVER_MEM_GB=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${DRIVER_MEM_QUERY}" | jq -r '.data.result[0].value[1]' || echo "0")
EXEC_CPU_SECONDS=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${EXEC_CPU_QUERY}" | jq -r '.data.result[0].value[1]' || echo "0")
EXEC_MEM_GB=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${EXEC_MEM_QUERY}" | jq -r '.data.result[0].value[1]' || echo "0")

# Calculate costs
DRIVER_CPU_COST=$(echo "scale=2; $DRIVER_CPU_SECONDS / 3600 * $CPU_RATE_ONDEMAND" | bc)
DRIVER_MEM_COST=$(echo "scale=2; $DRIVER_MEM_GB * $DURATION_HOURS * $MEMORY_RATE_ONDEMAND" | bc)
EXEC_CPU_COST=$(echo "scale=2; $EXEC_CPU_SECONDS / 3600 * $CPU_RATE_ONDEMAND" | bc)
EXEC_MEM_COST=$(echo "scale=2; $EXEC_MEM_GB * $DURATION_HOURS * $MEMORY_RATE_ONDEMAND" | bc)

# Storage cost (estimate)
STORAGE_GB=100  # Placeholder - should query from S3/MinIO
STORAGE_COST=$(echo "scale=2; $STORAGE_GB * $STORAGE_RATE / 30 * ($DURATION_HOURS / 720)" | bc)  # Monthly rate pro-rated

# Network cost (estimate)
NETWORK_GB=10  # Placeholder
NETWORK_COST=$(echo "$NETWORK_GB * $NETWORK_RATE" | bc)

# Total cost
TOTAL_COST=$(echo "scale=2; $DRIVER_CPU_COST + $DRIVER_MEM_COST + $EXEC_CPU_COST + $EXEC_MEM_COST + $STORAGE_COST + $NETWORK_COST" | bc)

# Output breakdown
cat <<EOF
=== Cost Breakdown ===

Driver:
  CPU:    \$${DRIVER_CPU_COST} (${DRIVER_CPU_SECONDS}s)
  Memory: \$${DRIVER_MEM_COST} (${DRIVER_MEM_GB}GB × ${DURATION_HOURS}h)
  Subtotal: \$$(echo "scale=2; $DRIVER_CPU_COST + $DRIVER_MEM_COST" | bc)

Executors:
  CPU:    \$${EXEC_CPU_COST} (${EXEC_CPU_SECONDS}s)
  Memory: \$${EXEC_MEM_COST} (${EXEC_MEM_GB}GB × ${DURATION_HOURS}h)
  Subtotal: \$$(echo "scale=2; $EXEC_CPU_COST + $EXEC_MEM_COST" | bc)

Storage:
  Cost:   \$${STORAGE_COST} (${STORAGE_GB}GB)

Network:
  Cost:   \$${NETWORK_COST} (${NETWORK_GB}GB)

=== Total: \$${TOTAL_COST} ===
EOF

# Export as JSON
JSON_OUTPUT="{
  \"job_id\": \"${JOB_ID}\",
  \"start_time\": \"${START_TIME}\",
  \"end_time\": \"${END_TIME}\",
  \"duration_hours\": ${DURATION_HOURS},
  \"driver_cpu_cost\": ${DRIVER_CPU_COST},
  \"driver_mem_cost\": ${DRIVER_MEM_COST},
  \"executor_cpu_cost\": ${EXEC_CPU_COST},
  \"executor_mem_cost\": ${EXEC_MEM_COST},
  \"storage_cost\": ${STORAGE_COST},
  \"network_cost\": ${NETWORK_COST},
  \"total_cost\": ${TOTAL_COST}
}"

echo "$JSON_OUTPUT" | jq .

exit 0
