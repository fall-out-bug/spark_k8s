# Executor Sizing Guide

This guide helps you properly size Spark executors for optimal performance and cost-efficiency.

## Overview

Proper executor sizing is critical for:
- Maximizing resource utilization
- Minimizing cost
- Avoiding out-of-memory errors
- Reducing shuffle overhead

## Key Concepts

### Executor Components

```
┌─────────────────────────────────────────────┐
│         Executor Container Memory           │
│  ┌───────────────────────────────────────┐  │
│  │         Spark Memory (80%)            │  │
│  │  ┌────────────┬  ┌─────────────────┐  │  │
│  │  │  Storage  │  │  Execution      │  │  │
│  │  │  (30%)    │  │  (60%)          │  │  │
│  │  └────────────┴  └─────────────────┘  │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │         Memory Overhead (20%)         │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Key Formulas

```
Total Executor Memory = Spark Memory + Memory Overhead
Spark Memory = Storage Memory + Execution Memory
Execution Memory = Shuffle + Join + Aggregation
```

## Sizing Methodology

### Step 1: Determine Data Size

Calculate your working set size:

```python
# Estimate data size per partition
data_size_gb = total_rows * avg_row_size / 1e9
partitions = num_executors * cores_per_executor
bytes_per_partition = data_size_gb * 1e9 / partitions
```

### Step 2: Calculate Executor Memory

```python
def calculate_executor_memory(data_size_gb, cores=4):
    """Calculate optimal executor memory."""

    # Each core needs ~2-4GB for most workloads
    memory_per_core = 3  # GB

    # Base memory for cores
    spark_memory = cores * memory_per_core

    # Add 20% overhead
    total_memory = spark_memory * 1.2

    # Round to standard sizes (4, 8, 16, 32, 64GB)
    standard_sizes = [4, 8, 16, 32, 64]
    for size in standard_sizes:
        if total_memory <= size:
            return size

    return 64  # Max out at 64GB

# Examples
print(calculate_executor_memory(100, cores=4))   # 8GB
print(calculate_executor_memory(500, cores=4))   # 16GB
print(calculate_executor_memory(1000, cores=8))  # 32GB
```

### Step 3: Calculate Executor Count

```python
def calculate_executor_count(data_size_gb, executor_memory_gb, cores_per_executor=4):
    """Calculate optimal number of executors."""

    # Total cores needed (1 core processes ~2GB)
    total_cores = data_size_gb / 2

    # Executors needed
    executors = int(total_cores / cores_per_executor)

    # Add buffer for stragglers
    executors = int(executors * 1.2)

    # Min/max bounds
    return max(2, min(executors, 100))
```

## Configuration Examples

### Small Workload (< 50GB)

```yaml
driver:
  cores: 1
  memory: "2g"
  memoryOverhead: "512m"

executor:
  cores: 2
  instances: 5
  memory: "4g"
  memoryOverhead: "1g"
```

### Medium Workload (50-500GB)

```yaml
driver:
  cores: 2
  memory: "4g"
  memoryOverhead: "1g"

executor:
  cores: 4
  instances: 10
  memory: "8g"
  memoryOverhead: "1g"
```

### Large Workload (500GB-5TB)

```yaml
driver:
  cores: 4
  memory: "8g"
  memoryOverhead: "2g"

executor:
  cores: 4
  instances: 20
  memory: "16g"
  memoryOverhead: "2g"
```

### Very Large Workload (> 5TB)

```yaml
driver:
  cores: 4
  memory: "16g"
  memoryOverhead: "2g"

executor:
  cores: 8
  instances: 50
  memory: "32g"
  memoryOverhead: "4g"
```

## Dynamic Allocation

Enable dynamic allocation for variable workloads:

```python
config = {
    "spark.dynamicAllocation.enabled": "true",
    "spark.dynamicAllocation.minExecutors": "2",        # Minimum executors
    "spark.dynamicAllocation.maxExecutors": "20",       # Maximum executors
    "spark.dynamicAllocation.initialExecutors": "5",    # Starting executors
    "spark.dynamicAllocation.executorIdleTimeout": "60s",
    "spark.dynamicAllocation.schedulerBacklogTimeout": "5s",
    "spark.shuffle.service.enabled": "true",            # Required for dynamic allocation
}
```

## Memory Fractions

Tune memory allocation for your workload:

```python
# Cache-heavy workload
spark.memory.fraction = 0.8
spark.memory.storageFraction = 0.5

# Shuffle-heavy workload
spark.memory.fraction = 0.8
spark.memory.storageFraction = 0.2

# Balanced (default)
spark.memory.fraction = 0.8
spark.memory.storageFraction = 0.3
```

## Common Issues and Solutions

### Out of Memory: Java Heap Space

**Symptoms:**
```
java.lang.OutOfMemoryError: Java heap space
```

**Solutions:**
1. Increase executor memory
2. Reduce `spark.executor.memory` overhead
3. Increase `spark.memory.fraction`
4. Reduce shuffle partitions

### Out of Memory: GC Overhead

**Symptoms:**
```
java.lang.OutOfMemoryError: GC overhead limit exceeded
```

**Solutions:**
1. Increase executor memory significantly
2. Reduce cache size
3. Use `StorageLevel.MEMORY_AND_DISK_SER`
4. Tune GC settings

### Container Killed

**Symptoms:**
```
Container killed by YARN for exceeding memory limits
```

**Solutions:**
1. Increase `spark.executor.memoryOverhead`
2. Reduce memory usage (less caching)
3. Fix memory leaks in UDFs

### Slow Processing

**Symptoms:**
- Executors not fully utilized
- Long task durations

**Solutions:**
1. Increase executor count
2. Increase cores per executor
3. Check for data skew
4. Increase shuffle partitions

## Tuning Checklist

- [ ] Calculate data size
- [ ] Determine optimal executor memory
- [ ] Calculate executor count
- [ ] Set memory fractions appropriately
- [ ] Enable dynamic allocation for variable workloads
- [ ] Test with sample data
- [ ] Monitor metrics in production
- [ ] Adjust based on actual usage

## Reference

- [Spark Memory Management](https://spark.apache.org/docs/latest/tuning.html#memory-management-overview)
- [Dynamic Allocation](https://spark.apache.org/docs/latest/job-scheduling.html#dynamic-resource-allocation)
