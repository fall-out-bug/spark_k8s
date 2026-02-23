# Spark Configuration Reference

Complete reference for Spark configuration properties.

## Execution

### Dynamic Allocation

| Property | Default | Description |
|----------|---------|-------------|
| `spark.dynamicAllocation.enabled` | `false` | Enable dynamic resource allocation |
| `spark.dynamicAllocation.minExecutors` | `1` | Minimum number of executors |
| `spark.dynamicAllocation.maxExecutors` | `infinity` | Maximum number of executors |
| `spark.dynamicAllocation.initialExecutors` | `minExecutors` | Initial number of executors |
| `spark.dynamicAllocation.executorIdleTimeout` | `60s` | Timeout before removing idle executor |
| `spark.dynamicAllocation.schedulerBacklogTimeout` | `5s` | Timeout before requesting new executors |
| `spark.dynamicAllocation.sustainedSchedulerBacklogTimeout` | `60s` | Sustained backlog timeout |
| `spark.shuffle.service.enabled` | `false` | Enable external shuffle service (required for dynamic allocation) |

### Scheduling

| Property | Default | Description |
|----------|---------|-------------|
| `spark.scheduler.mode` | `FIFO` | Scheduler mode (FIFO, FAIR) |
| `spark.task.maxFailures` | `4` | Maximum task failures before giving up |
| `spark.speculation` | `false` | Enable speculative execution of straggling tasks |
| `spark.speculation.multiplier` | `1.5` | Speculative execution multiplier |
| `spark.speculation.quantile` | `0.75` | Percentage of tasks to speculate |

## Memory

### Driver Memory

| Property | Default | Description |
|----------|---------|-------------|
| `spark.driver.memory` | `1g` | Driver memory amount |
| `spark.driver.memoryOverhead` | `driverMemory * 0.10` | Driver off-heap memory (minimum 384m) |
| `spark.driver.memoryOverheadFactor` | `0.10` | Fraction of driver memory for overhead |

### Executor Memory

| Property | Default | Description |
|----------|---------|-------------|
| `spark.executor.memory` | `1g` | Executor memory amount |
| `spark.executor.memoryOverhead` | `executorMemory * 0.10` | Executor off-heap memory (min 384m) |
| `spark.memory.fraction` | `0.8` | Fraction of heap used for execution/storage |
| `spark.memory.storageFraction` | `0.5` | Fraction of memory.fraction for storage |
| `spark.memory.offHeap.enabled` | `false` | Enable off-heap memory usage |

## CPU

| Property | Default | Description |
|----------|---------|-------------|
| `spark.driver.cores` | `1` | Driver CPU cores |
| `spark.executor.cores` | `1` | Executor CPU cores per executor |
| `spark.task.cpus` | `1` | CPU cores per task |
| `spark.speculation` | `false` | Enable speculative execution |

## Shuffle

| Property | Default | Description |
|----------|---------|-------------|
| `spark.sql.shuffle.partitions` | `200` | Number of partitions for shuffle |
| `spark.shuffle.compress` | `true` | Compress shuffle data |
| `spark.shuffle.spill.compress` | `true` | Compress spilled shuffle data |
| `spark.shuffle.file.buffer` | `32k` | File buffer size |
| `spark.shuffle.sync` | `false` | Synchronous shuffle |

## SQL

### Adaptive Query Execution

| Property | Default | Description |
|----------|---------|-------------|
| `spark.sql.adaptive.enabled` | `true` | Enable adaptive query execution (AQE) |
| `spark.sql.adaptive.coalescePartitions.enabled` | `true` | Enable partition coalescing |
| `spark.sql.adaptive.skewJoin.enabled` | `true` | Enable skew join optimization |
| `spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes` | `256MB` | Threshold for skewed partition |
| `spark.sql.adaptive.skewJoin.skewedPartitionFactor` | `5` | Factor for skewed partition detection |

### Join Optimization

| Property | Default | Description |
|----------|---------|-------------|
| `spark.sql.autoBroadcastJoinThreshold` | `10MB` | Threshold for broadcast hash join |
| `spark.sql.broadcastTimeout` | `300s` | Timeout for broadcast join |
| `spark.sql.join.preferSortMergeJoin` | `true` | Prefer sort merge join |

### Other SQL

| Property | Default | Description |
|----------|---------|-------------|
| `spark.sql.caseSensitive` | `true` | Case sensitivity for SQL |
| `spark.sql.sources.parallelism` | `None` | Default parallelism for SQL operations |
| `spark.sql.streaming.schemaInference` | `true` | Enable schema inference for streaming |

## Streaming

### Checkpointing

| Property | Default | Description |
|----------|---------|-------------|
| `spark.sql.streaming.checkpointLocation` | Required | Checkpoint directory |
| `spark.sql.streaming.minBatchesToRetain` | `2` | Minimum batches to retain |

### State Management

| Property | Default | Description |
|----------|---------|-------------|
| `spark.sql.streaming.stateStore.providerClass` | `rocksdb` | State store provider |
| `spark.sql.streaming.stateStore.compression.codec` | `lz4` | State store compression |
| `spark.sql.streaming.stateStore.minDeltasForSnapshot` | `10` | Minimum state updates before snapshot |

## Monitoring

### Metrics

| Property | Default | Description |
|----------|---------|-------------|
| `spark.ui.prometheus.enabled` | `false` | Enable Prometheus metrics |
| `spark.metrics.conf` | - | Metrics configuration |
| `spark.executor.metricsPollingInterval` | `10s` | Metrics polling interval |

### Event Logging

| Property | Default | Description |
|----------|---------|-------------|
| `spark.eventLog.enabled` | `false` | Enable event logging |
| `spark.eventLog.dir` | Required | Event log directory |

## Kubernetes

### Container

| Property | Default | Description |
|----------|---------|-------------|
| `spark.kubernetes.container.image` | Required | Container image |
| `spark.kubernetes.container.image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `spark.kubernetes.driver.podTemplateFile` | - | Driver pod template file |
| `spark.kubernetes.executor.podTemplateFile` | - | Executor pod template file |

### Authentication

| Property | Default | Description |
|----------|---------|-------------|
| `spark.kubernetes.authenticate.caCertFile` | - | CA certificate file |
| `spark.kubernetes.authenticate.clientCertFile` | - | Client certificate file |
| `spark.kubernetes.authenticate.clientKeyFile` | - | Client key file |
| `spark.kubernetes.authenticate.oauthToken` | - | OAuth token |
| `spark.kubernetes.authenticate.driver.serviceAccountName` | - | Driver service account |
| `spark.kubernetes.authenticate.executor.serviceAccountName` | - | Executor service account |

### Networking

| Property | Default | Description |
|----------|---------|-------------|
| `spark.kubernetes.driver.dnsPolicy` | `ClusterFirst` | Driver DNS policy |
| `spark.kubernetes.executor.dnsPolicy` | `ClusterFirst` | Executor DNS policy |
| `spark.kubernetes.driver.hostNetwork` | `false` | Use host network for driver |
| `spark.kubernetes.executor.hostNetwork` | `false` | Use host network for executors |

### Resource Limits

| Property | Default | Description |
|----------|---------|-------------|
| `spark.kubernetes.driver.limit.cores` | - | Driver CPU limit |
| `spark.kubernetes.executor.limit.cores` | - | Executor CPU limit |
| `spark.kubernetes.driver.request.cores` | - | Driver CPU request |
| `spark.kubernetes.executor.request.cores` | - | Executor CPU request |

## Storage

### S3 (S3A)

| Property | Default | Description |
|----------|---------|-------------|
| `spark.hadoop.fs.s3a.access.key` | - | AWS access key |
| `spark.hadoop.fs.s3a.secret.key` | - | AWS secret key |
| `spark.hadoop.fs.s3a.endpoint` | - | S3 endpoint |
| `spark.hadoop.fs.s3a.impl` | `org.apache.hadoop.fs.s3a.S3AFileSystem` | S3A filesystem implementation |
| `spark.hadoop.fs.s3a.fast.upload` | `true` | Enable fast upload |
| `spark.hadoop.fs.s3a.multipart.size` | `104857600` | Multipart size (100MB) |

### GCS (GC)

| Property | Default | Description |
|----------|---------|-------------|
| `spark.hadoop.google.cloud.auth.service.account.enable` | `true` | Enable service account auth |
| `spark.hadoop.google.cloud.auth.service.account.json.keyfile` | - | Service account JSON key file |
| `spark.hadoop.fs.gs.impl` | `com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystem` | GCS filesystem implementation |

### Azure (ABFS)

| Property | Default | Description |
|----------|---------|-------------|
| `spark.hadoop.fs.azure.account.auth.type` | - | Auth type |
| `spark.hadoop.fs.azure.account.oauth.client.id` | - | Azure client ID |
| `spark.hadoop.fs.azure.account.oauth.client.secret` | - | Azure client secret |
| `spark.hadoop.fs.abfs.impl` | `org.apache.hadoop.fs.azurebfs.AzureBlobFileSystem` | ABFS filesystem implementation |

## Related

- [Helm Values Reference](./values-reference.md)
- [CLI Reference](./cli-reference.md)
