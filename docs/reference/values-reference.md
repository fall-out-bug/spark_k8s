# Helm Values Reference

Complete reference for Spark on Kubernetes Helm chart values.

## Global Values

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `global.imageRegistry` | string | `""` | Global image registry override |
| `global.imagePullSecrets` | list | `[]` | Global image pull secrets |
| `global.namespace` | string | `spark-prod` | Default namespace for Spark applications |

## SparkApplication Values

### Metadata

```yaml
metadata:
  name: my-app                    # Required: Application name
  namespace: spark-prod            # Optional: Defaults to release namespace
  labels:                          # Optional: Additional labels
    app: my-app
    team: data-science
  annotations:                     # Optional: Additional annotations
    prometheus.io/scrape: "true"
```

### Type and Mode

```yaml
spec:
  type: Python                    # Required: Python, Scala, Java, R
  mode: cluster                    # Required: cluster or client
  image: my-registry/spark:3.5.0  # Required: Application image
```

### Main Application

```yaml
spec:
  mainClass: com.example.MyApp   # Required for Java/Scala
  mainApplicationFile:            # Required: Path to main file
    local:///app/jobs/my_job.py   #   - local:// for container files
    #   s3a://bucket/jobs.py      #   - s3a://, gs://, abfs:// for remote
  arguments:                      # Optional: Command line arguments
    - --input
    - s3a://data/input
    - --output
    - s3a://data/output
```

### Spark Version

```yaml
spec:
  sparkVersion: "3.5.0"           # Required: Spark version
```

### Driver Configuration

```yaml
spec:
  driver:
    cores: 2                       # Number of CPU cores (1-8)
    memory: "4g"                   # Memory amount (e.g., 512m, 2g, 4g)
    memoryOverhead: "1g"           # Off-heap memory overhead
    coreLimit: "1200m"             # Optional: CPU limit (m millicores)
    memoryOverhead: "1g"           # Optional: Memory overhead
    serviceAccount: spark          # Optional: Service account
    env:                           # Optional: Environment variables
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: aws-credentials
            key: access-key-id
    envVars:                       # Deprecated: Use env instead
      AWS_REGION: us-west-2
    envSecretKeyRefs:              # Optional: Secret key references
      - name: DATABASE_URL
        secret: db-credentials
        key: url
    labels:                        # Optional: Pod labels
      app: my-app-driver
    annotations:                   # Optional: Pod annotations
      prometheus.io/scrape: "true"
      prometheus.io/port: "4040"
    selector:                      # Optional: Node selector
      node.kubernetes.io/instance-type: "on-demand"
    tolerations:                   # Optional: Tolerations
      - key: "spot"
        operator: "Exists"
        effect: "NoSchedule"
    affinity:                      # Optional: Affinity rules
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values: [spark-executor]
    resources:                     # Optional: Resource requests/limits
      requests:
        cpu: "2"
        memory: "4g"
      limits:
        cpu: "4"
        memory: "8g"
    volumeMounts:                  # Optional: Volume mounts
      - name: data-volume
        mountPath: /data
    podName: spark-driver           # Optional: Custom pod name
```

### Executor Configuration

```yaml
spec:
  executor:
    cores: 4                       # Number of CPU cores per executor
    instances: 10                  # Number of executors (or dynamic)
    memory: "8g"                   # Memory per executor
    memoryOverhead: "1g"           # Memory overhead per executor
    coreLimit: "4000m"             # Optional: CPU limit per executor
    serviceAccount: spark          # Optional: Service account
    env:                           # Optional: Environment variables (same as driver)
      - name: JAVA_OPTS
        value: "-XX:+UseG1GC"
    labels:                        # Optional: Pod labels (same as driver)
      app: my-app-executor
    annotations:                   # Optional: Pod annotations
    selector:                      # Optional: Node selector (same as driver)
      node.kubernetes.io/instance-type: "spot"
    tolerations:                   # Optional: Tolerations (same as driver)
    affinity:                      # Optional: Affinity rules (same as driver)
    resources:                     # Optional: Resource requests/limits
      requests:
        cpu: "4"
        memory: "8g"
      limits:
        cpu: "8"
        memory: "16g"
    volumeMounts:                  # Optional: Volume mounts (same as driver)
    deleteOnTermination: false     # Optional: Keep pods after completion
```

### Dynamic Allocation

```yaml
spec:
  dynamicAllocation:
    enabled: true                  # Enable dynamic allocation
    initialExecutors: 5            # Initial number of executors
    minExecutors: 2                # Minimum number of executors
    maxExecutors: 20               # Maximum number of executors
    executorIdleTimeout: 60s       # Idle timeout before removing executor
    cachedExecutorIdleTime: 300s   # Idle timeout for cached data executors
    shuffleTrackingEnabled: true   # Enable shuffle tracking
```

### Restart Policy

```yaml
spec:
  restartPolicy:
    type: OnFailure                # Always, OnFailure, Never
    onFailureRetries: 3            # Number of retries on failure
    onFailureRetryInterval: 60     # Seconds between retries
    onSubmissionFailureRetries: 5  # Number of retries on submission failure
    onSubmissionFailureRetryInterval: 60
```

### Dependencies

```yaml
spec:
  deps:
    jars:                          # Optional: JAR dependencies
      - local:///app/libs/lib.jar
      - s3a://bucket/lib.jar
    packages:                      # Optional: Maven packages
      - org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0
    pyPackages:                    # Optional: Python packages
      - boto3==1.28.0
      - requests==2.31.0
    files:                         # Optional: File dependencies
      - local:///app/config.json
    archives:                      # Optional: Archive dependencies
      - local:///app/lib.tar.gz
```

### Spark Configuration

```yaml
spec:
  sparkConf:
    # SQL configurations
    spark.sql.adaptive.enabled: "true"
    spark.sql.adaptive.coalescePartitions.enabled: "true"
    spark.sql.shuffle.partitions: "200"

    # Dynamic allocation
    spark.dynamicAllocation.enabled: "true"
    spark.dynamicAllocation.initialExecutors: "5"
    spark.dynamicAllocation.minExecutors: "2"
    spark.dynamicAllocation.maxExecutors: "20"

    # Shuffle
    spark.shuffle.compress: "true"
    spark.shuffle.spill.compress: "true"

    # Memory
    spark.memory.fraction: "0.8"
    spark.memory.storageFraction: "0.3"

    # Monitoring
    spark.ui.prometheus.enabled: "true"
    spark.metrics.conf: "*"
```

### Monitoring

```yaml
spec:
  monitoring:
    exposeDriverMetrics: true      # Expose driver metrics
    exposeExecutorMetrics: true     # Expose executor metrics
    metricsProperties: |            # Custom metrics configuration
      *.sink.prometheus.class=org.apache.spark.metrics.sink.PrometheusSink
      *.sink.prometheus.period=5s
    prometheus:
      port: 4040                    # Prometheus metrics port
      scrapingInterval: 5s          # Scrape interval
```

### Volumes

```yaml
spec:
  volumes:
    - name: data-volume
      persistentVolumeClaim:
        claimName: spark-data-pvc
    - name: config-volume
      configMap:
        name: spark-config
    - name: secret-volume
      secret:
        secretName: spark-secrets
```

### Schedule

```yaml
spec:
  schedule: "0 2 * * *"            # Cron expression for periodic execution
  concurrency: "Allow"              # Concurrency policy: Allow, Forbid, Replace
  successfulRunHistory: 3           # Number of successful runs to keep
  failedRunHistory: 1               # Number of failed runs to keep
```

### Time Limit

```yaml
spec:
  timeLimit: 3600                  # Maximum run time in seconds
```

### Checkpoint

```yaml
spec:
  sparkCheckpointPath: s3a://checkpoints/my-app/
```

### Python Configuration

```yaml
spec:
  pythonVersion: "3"                # Python version: 2, 3
```

### R Configuration

```yaml
spec:
  r:
    # R-specific configurations
    spark.r.command: /usr/bin/Rscript
```

## Related

- [Helm Chart](../../../charts/spark-3.5/)
- [Configuration Reference](./config-reference.md)
- [Metrics Reference](./metrics-reference.md)
