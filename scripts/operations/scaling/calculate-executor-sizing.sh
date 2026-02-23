#!/bin/bash
# Executor Sizing Calculator
# Calculates optimal executor sizing based on workload characteristics

set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Calculate optimal Spark executor sizing.

OPTIONS:
    -j, --concurrent-jobs NUM      Number of concurrent jobs (default: 10)
    -p, --parallelism NUM          Total parallelism (default: 1000)
    -d, --data-size SIZE           Data size (e.g., 1TB, 500GB) (default: 1TB)
    -m, --job-memory GB            Memory per job (default: auto)
    -c, --cores-per-executor NUM   Cores per executor (default: 2)
    -h, --help                     Show this help

EXAMPLES:
    $(basename "$0") --concurrent-jobs 20 --parallelism 2000 --data-size 5TB
    $(basename "$0") -j 5 -p 500 -d 500GB
EOF
    exit 1
}

# Defaults
CONCURRENT_JOBS=10
PARALLELISM=1000
DATA_SIZE="1TB"
JOB_MEMORY=""
CORES_PER_EXECUTOR=2
MEMORY_OVERHEAD_RATIO=0.15  # 15% overhead

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -j|--concurrent-jobs)
                CONCURRENT_JOBS="$2"
                shift 2
                ;;
            -p|--parallelism)
                PARALLELISM="$2"
                shift 2
                ;;
            -d|--data-size)
                DATA_SIZE="$2"
                shift 2
                ;;
            -m|--job-memory)
                JOB_MEMORY="$2"
                shift 2
                ;;
            -c|--cores-per-executor)
                CORES_PER_EXECUTOR="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

parse_data_size() {
    local size="$1"
    local num=$(echo "$size" | tr -d 'A-Za-z')
    local unit=$(echo "$size" | tr -d '0-9.')

    case "$unit" in
        TB|T)
            echo $(echo "$num * 1024" | bc)
            ;;
        GB|G)
            echo "$num"
            ;;
        MB|M)
            echo $(echo "$num / 1024" | bc)
            ;;
        *)
            echo "Invalid size unit: $unit"
            exit 1
            ;;
    esac
}

calculate_memory_per_partition() {
    local data_gb="$1"
    local parallelism="$2"
    # Assume 3x data size for shuffle
    local total_memory_needed=$(echo "$data_gb * 3" | bc)
    echo $(echo "scale=2; $total_memory_needed / $parallelism" | bc)
}

main() {
    parse_args "$@"

    echo "=== Spark Executor Sizing Calculator ==="
    echo ""
    echo "Input Parameters:"
    echo "  Concurrent Jobs: $CONCURRENT_JOBS"
    echo "  Total Parallelism: $PARALLELISM"
    echo "  Data Size: $DATA_SIZE"
    echo "  Cores per Executor: $CORES_PER_EXECUTOR"
    echo ""

    # Convert data size to GB
    local data_gb=$(parse_data_size "$DATA_SIZE")
    echo "Data Size (GB): $data_gb"

    # Calculate memory per partition
    local memory_per_partition=$(calculate_memory_per_partition "$data_gb" "$PARALLELISM")
    echo "Memory per Partition (GB): $memory_per_partition"

    # Calculate total executors needed
    local parallelism_per_job=$((PARALLELISM / CONCURRENT_JOBS))
    local executors_per_job=$(((parallelism_per_job + CORES_PER_EXECUTOR - 1) / CORES_PER_EXECUTOR))
    local total_executors=$((executors_per_job * CONCURRENT_JOBS))

    echo ""
    echo "=== Sizing Recommendations ==="
    echo ""
    echo "1. Executor Configuration:"
    echo "   - Cores per Executor: $CORES_PER_EXECUTOR"
    echo "   - Memory per Executor: $(calculate_executor_memory "$memory_per_partition")GB"
    echo "   - Memory Overhead: $(calculate_overhead "$memory_per_partition")GB"
    echo "   - Total Memory per Executor: $(calculate_total_executor_memory "$memory_per_partition")GB"
    echo ""

    echo "2. Dynamic Allocation Settings:"
    echo "   - initialExecutors: $((executors_per_job / 2))"
    echo "   - minExecutors: 1"
    echo "   - maxExecutors: $((executors_per_job * 2))"
    echo "   - executorAllocationRatio: 0.5"
    echo ""

    echo "3. Cluster Requirements:"
    echo "   - Total Executors: $total_executors"
    echo "   - Total Cores Needed: $((total_executors * CORES_PER_EXECUTOR))"
    echo "   - Total Memory Needed: $(calculate_cluster_memory "$total_executors" "$memory_per_partition")GB"
    echo "   - Driver Cores: $CONCURRENT_JOBS (1 per job)"
    echo "   - Driver Memory: $(calculate_driver_memory "$JOB_MEMORY")GB each"
    echo ""

    echo "4. Node Pool Configuration:"
    local node_cores=16  # Assuming r5.4xlarge
    local nodes_needed=$(((total_executors * CORES_PER_EXECUTOR + CONCURRENT_JOBS + node_cores - 1) / node_cores))
    echo "   - Min Nodes: $((nodes_needed / 3))"
    echo "   - Max Nodes: $((nodes_needed * 2))"
    echo "   - Recommended Node Type: r5.4xlarge (16 cores, 128GB)"
    echo ""

    echo "5. Example SparkApplication Spec:"
    generate_spark_spec

    echo ""
    echo "=== Cost Estimation ==="
    echo ""
    local cost_per_vcpu_hour=0.0252  # AWS r5.4xlarge on-demand
    local cost_per_gb_hour=0.008
    local total_vcpus=$((total_executors * CORES_PER_EXECUTOR))
    local total_mem=$(calculate_cluster_memory "$total_executors" "$memory_per_partition")
    local hourly_cost=$(echo "scale=2; ($total_vcpus * $cost_per_vcpu_hour) + ($total_mem * $cost_per_gb_hour)" | bc)
    local monthly_cost=$(echo "scale=2; $hourly_cost * 730" | bc)

    echo "   - Hourly Cost (On-Demand): \$$hourly_cost"
    echo "   - Monthly Cost (On-Demand): \$$monthly_cost"
    echo "   - Monthly Cost (Spot, 70% off): \$(echo "scale=2; $monthly_cost * 0.3" | bc)"
    echo ""
}

calculate_executor_memory() {
    local mem_per_partition="$1"
    # At least 4GB or enough for 4 partitions with overhead
    local min_mem=4
    local calculated=$(echo "scale=0; ($mem_per_partition * 4 * (1 + $MEMORY_OVERHEAD_RATIO)) / 1" | bc)
    if [[ $calculated -lt $min_mem ]]; then
        echo $min_mem
    else
        # Round to nearest GB
        echo $(( (calculated + 512) / 1024 ))
    fi
}

calculate_overhead() {
    local executor_mem="$1"
    echo $((executor_mem / 8 + 1))  # Max of 384MB or 10% of executor memory
}

calculate_total_executor_memory() {
    local mem_per_partition="$1"
    local executor_mem=$(calculate_executor_memory "$mem_per_partition")
    local overhead=$(calculate_overhead "$executor_mem")
    echo $((executor_mem + overhead))
}

calculate_cluster_memory() {
    local executors="$1"
    local mem_per_partition="$2"
    local executor_mem=$(calculate_executor_memory "$mem_per_partition")
    local overhead=$(calculate_overhead "$executor_mem")
    echo $((executors * (executor_mem + overhead)))
}

calculate_driver_memory() {
    local job_mem="$1"
    if [[ -n "$job_mem" ]]; then
        echo "$job_mem"
    else
        echo "2"  # Default 2GB
    fi
}

generate_spark_spec() {
    cat <<'SPEC'
spec:
  driver:
    cores: 1
    coreLimit: "1200m"
    memory: "2g"
    memoryOverhead: 512m
  executor:
    cores: 2
    coreLimit: "2000m"
    memory: "4g"
    memoryOverhead: 1g
    instances: 2
  dynamicAllocation:
    enabled: true
    initialExecutors: 2
    minExecutors: 1
    maxExecutors: 10
    executorAllocationRatio: 0.5
    shuffleTrackingEnabled: true
SPEC
}

main "$@"
