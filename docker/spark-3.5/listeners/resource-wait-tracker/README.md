# ResourceWaitTracker SparkListener

Custom SparkListener that tracks the time gap between application start and first executor registration. This metric represents Kubernetes scheduling delay and resource wait time.

## Building the JAR

### Option 1: Using SBT (Recommended)

```bash
cd docker/spark-3.5/listeners/resource-wait-tracker
sbt clean assembly
```

The JAR will be created at `target/scala-2.12/resource-wait-tracker.jar`

### Option 2: Using Docker

```bash
cd docker/spark-3.5/listeners/resource-wait-tracker
docker build -t resource-wait-tracker:build .
```

Extract the JAR from the container:
```bash
docker create --name temp-container resource-wait-tracker:build
docker cp temp-container:/opt/spark/jars/resource-wait-tracker.jar ./resource-wait-tracker.jar
docker rm temp-container
```

## Usage in Spark Connect

### Enable in values.yaml

```yaml
connect:
  extraLibraries:
    resource-wait-tracker:
      enabled: true
      jar: "local:///opt/spark/jars/resource-wait-tracker.jar"
      className: "org.apache.spark.scheduler.ResourceWaitTracker"
```

### Verify

After starting Spark Connect, check logs for:
```
[ResourceWaitTracker] Application started at ...
[ResourceWaitTracker] First executor registered at ...
[ResourceWaitTracker] Resource wait time: X.XX seconds
```

## Metric Exposed

- `spark_resource_wait_seconds`: Time in seconds from application start to first executor registration

## Integration

This listener integrates with:
- **Job Phase Timeline Dashboard**: Shows "Resource Wait" phase as a separate bar
- **Resource Wait Long Recipe**: Troubleshooting guide for high resource wait times

## JAR Delivery (WS-025-12 AC3)

The JAR is **not published** to an external artifact repository. It is:

1. **Built locally**: `sbt clean assembly` or via the Dockerfile in this directory.
2. **Delivered in image**: When using this listener, the Spark Connect image must include `resource-wait-tracker.jar` at `/opt/spark/jars/` (e.g. by building a custom image that COPYs the JAR from the `resource-wait-tracker:build` image, or by mounting the JAR).
3. **Optional**: By default `connect.extraLibraries.resource-wait-tracker.enabled` is `false`. For resource-wait metrics without this JAR, you can rely on Spark's native metrics and the **Job Phase Timeline** dashboard (time-to-first-executor is available from Spark UI / Prometheus when using the standard stack).
