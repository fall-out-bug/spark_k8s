# GPU Support Guide for Spark on Kubernetes

This guide covers GPU acceleration for Spark workloads using NVIDIA RAPIDS plugin.

## Overview

Spark K8s Constructor supports GPU acceleration through:
- **NVIDIA RAPIDS Plugin** - GPU-accelerated SQL and DataFrame operations
- **CUDA Support** - NVIDIA GPU computing platform
- **cuDF Integration** - GPU DataFrame library for ETL operations
- **Automatic Fallback** - CPU fallback for unsupported operations

## Prerequisites

### Cluster Requirements

1. **GPU Nodes**: Kubernetes nodes with NVIDIA GPUs
   - AWS: `p3.2xlarge`, `p3.8xlarge`, `g4dn.2xlarge`, etc.
   - GCP: Nodes with `nvidia-tesla-k80`, `nvidia-tesla-v100`, etc.
   - Azure: `Standard_NC6s_v3`, `Standard_NC12s_v3`, etc.

2. **NVIDIA Device Plugin**: Installed on cluster
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
   ```

3. **NVIDIA GPU Operator** (recommended):
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/NVIDIA/gpu-operator/v23.9.1/deploy/gpu-operator.yaml
   ```

### Verification

Verify GPU availability:
```bash
# Check GPU nodes
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'

# Check NVIDIA device plugin
kubectl get pods -n gpu-operator

# Test GPU on a node
kubectl debug node/<gpu-node> --image=nvidia/cuda:12.1.0-base-ubuntu22.04 -- nvidia-smi
```

## Quick Start

### Deploy GPU-Enabled Spark

```bash
helm install spark-gpu charts/spark-4.1 \
  -f charts/spark-4.1/presets/gpu-values.yaml
```

### Build GPU Docker Image

```bash
# Build image with RAPIDS
docker build -f docker/spark-4.1/gpu/Dockerfile \
  -t spark-custom:4.1.0-gpu \
  --build-arg SPARK_VERSION=4.1.0 \
  --build-arg RAPIDS_VERSION=24.02 \
  docker/spark-4.1/gpu/

# Push to registry
docker tag spark-custom:4.1.0-gpu <registry>/spark-custom:4.1.0-gpu
docker push <registry>/spark-custom:4.1.0-gpu
```

### Run GPU Example

```bash
# Using spark-submit
spark-submit \
  --master k8s://https://kubernetes.default.svc:443 \
  --deploy-mode cluster \
  --conf spark.executor.resource.gpu.amount=1 \
  --conf spark.task.resource.gpu.amount=1 \
  --conf spark.executor.resource.gpu.discoveryScript=/opt/spark/gpu-discovery.sh \
  --conf spark.plugins=com.nvidia.spark.SQLPlugin \
  --conf spark.rapids.sql.enabled=true \
  examples/gpu/gpu_operations_notebook.py

# Using PySpark
python examples/gpu/gpu_operations_notebook.py
```

## Configuration

### GPU Resources

Configure GPU resources in values:

```yaml
connect:
  executor:
    gpu:
      enabled: true
      count: "1"           # GPUs per executor
      vendor: "nvidia.com/gpu"
```

### RAPIDS Configuration

```yaml
connect:
  sparkConf:
    # Enable RAPIDS
    "spark.plugins": "com.nvidia.spark.SQLPlugin"
    "spark.rapids.sql.enabled": "true"
    "spark.rapids.sql.python.enabled": "true"

    # Fallback to CPU for unsupported ops
    "spark.rapids.sql.fallback.enabled": "true"
    "spark.rapids.sql.fallback.allowed": "true"

    # GPU memory
    "spark.rapids.memory.gpu.allocFraction": "0.8"
    "spark.rapids.memory.gpu.maxAllocFraction": "0.9"
    "spark.rapids.memory.gpu.minAllocFraction": "0.3"

    # RAPIDS shuffle
    "spark.rapids.shuffle.enabled": "true"
    "spark.sql.shuffle.partitions": "200"

    # Format support
    "spark.rapids.sql.format.parquet.read.enabled": "true"
    "spark.rapids.sql.format.parquet.write.enabled": "true"
    "spark.rapids.sql.format.orc.read.enabled": "true"
    "spark.rapids.sql.format.csv.read.enabled": "true"
```

### GPU Scheduling

```yaml
connect:
  nodeSelector:
    nvidia.com/gpu.present: "true"

  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Exists"
      effect: "NoSchedule"
```

## Supported Operations

### GPU-Accelerated Operations

RAPIDS accelerates these operations on GPU:

| Category | Operations |
|----------|------------|
| **Filters** | =, !=, <, >, <=, >=, IS NULL, IS NOT NULL, IN, AND, OR |
| **Joins** | Inner, left outer, cross join |
| **Aggregates** | Count, sum, avg, max, min |
| **Sort** | Order by |
| **Scan** | Parquet, ORC, CSV, JSON |
| **UDF** | Python UDFs (with cuDF) |
| **Functions** | Cast, mathematical, string operations |

### Operations with CPU Fallback

These operations fall back to CPU:
- Complex window functions
- Certain types of joins (full outer, semi, anti)
- Some data types (binary, complex types)
- Collect operations

## Performance Considerations

### Data Size

GPU acceleration is most effective for:
- Large datasets (>10M rows)
- Batch operations (not streaming)
- CPU-intensive operations (aggregations, joins, sorts)

### Memory

GPU memory considerations:
```yaml
sparkConf:
  # Allocate 80% of GPU memory
  "spark.rapids.memory.gpu.allocFraction": "0.8"

  # Enable pooled memory
  "spark.rapids.memory.pinnedPool.size": "2G"

  # Adjust batch size
  "spark.rapids.sql.batchSizeBytes": "1G"
```

### Partitioning

Optimal partitioning for GPU:
```yaml
sparkConf:
  # More partitions = better GPU utilization
  "spark.sql.shuffle.partitions": "200"

  # Larger batches for GPU
  "spark.rapids.sql.batchSizeBytes": "1G"
```

## Monitoring

### GPU Metrics

Enable GPU monitoring:

```yaml
monitoring:
  gpu:
    enabled: true
    port: 9400
```

### Key Metrics

Monitor these metrics in Grafana:
- `nvidia_gpu_duty_cycle`: GPU utilization
- `nvidia_gpu_memory_used_bytes`: GPU memory usage
- `nvidia_gpu_temperature_gpu`: GPU temperature
- `spark_executor_count`: Active executors

### GPU Dashboard

Use NVIDIA DCGM Exporter for GPU metrics:
```yaml
# Add to values
monitoring:
  serviceMonitor:
    enabled: true
```

## Troubleshooting

### GPUs Not Detected

**Problem:** Spark executors not getting GPU resources

**Solutions:**
1. Verify GPU nodes exist: `kubectl describe nodes | grep nvidia.com/gpu`
2. Check device plugin: `kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset`
3. Verify tolerations match node taints

### Out of Memory Errors

**Problem:** GPU OOM errors

**Solutions:**
```yaml
sparkConf:
  # Reduce GPU memory allocation
  "spark.rapids.memory.gpu.allocFraction": "0.6"

  # Enable spill to disk
  "spark.rapids.memory.gpu.spillStorage": "host"

  # Reduce batch size
  "spark.rapids.sql.batchSizeBytes": "512M"
```

### Poor Performance

**Problem:** GPU slower than CPU

**Solutions:**
1. Check execution plan for Gpu* operators
2. Verify data size is large enough
3. Reduce data transfer overhead
4. Check GPU utilization with `nvidia-smi`

### Operations Not Accelerated

**Problem:** Operations running on CPU

**Solutions:**
1. Check fallback is enabled: `spark.rapids.sql.fallback.enabled=true`
2. Review supported operations list
3. Check explain plan for Gpu* operators
4. Verify RAPIDS plugin loaded

## Best Practices

1. **Use GPU for batch workloads** - not for streaming or small jobs
2. **Enable fallback** - ensures compatibility
3. **Optimize partition count** - 200 partitions for most workloads
4. **Monitor GPU utilization** - aim for >80% GPU duty cycle
5. **Use Parquet format** - best GPU performance
6. **Limit shuffle** - shuffle can be expensive on GPU
7. **Batch small operations** - combine multiple operations
8. **Profile before optimizing** - verify GPU bottlenecks

## Examples

### ETL Pipeline with GPU

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .config("spark.plugins", "com.nvidia.spark.SQLPlugin") \
    .config("spark.rapids.sql.enabled", "true") \
    .getOrCreate()

# Read (GPU-accelerated)
df = spark.read.parquet("s3a://data/large/")

# Transform (GPU-accelerated)
result = df.filter(col("amount") > 100) \
    .groupBy("category") \
    .agg(avg("amount"), sum("amount"))

# Write (GPU-accelerated)
result.write.parquet("s3a://output/processed/")
```

### Join Optimization

```python
# Broadcast small table for GPU join
from pyspark.sql.functions import broadcast

small_df = spark.read.parquet("s3a://data/dimensions/")
large_df = spark.read.parquet("s3a://data/facts/")

# GPU-optimized join
result = large_df.join(
    broadcast(small_df),
    "dimension_key",
    "inner"
)
```

## Further Reading

- [NVIDIA RAPIDS Spark Plugin](https://nvidia.github.io/spark-rapids/)
- [RAPIDS cudf Documentation](https://docs.rapids.ai/api/cudf/stable/)
- [Spark on GPU Best Practices](https://spark.apache.org/docs/latest/hardware-provisioning.html#gpu-scaling)
