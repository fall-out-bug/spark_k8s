# ADR-0009: Spark Listeners — OTEL and OpenLineage Config

## Status

Accepted (2026-03-05 audit)

## Context

Charts referenced non-existent or incorrect Spark listener classes and configs, causing `ClassNotFoundException` or wrong behavior.

## Decision

### OTEL (OpenTelemetry)

- **Do NOT use:** `org.apache.spark.openTelemetry.OpenTelemetryListener` — class does not exist in Spark 3.5.x/4.x
- **Use instead:** Java agent (`opentelemetry-javaagent.jar`) in Connect deployment
- **Remove:** `spark.extraListeners` and `spark.openTelemetry.*` from Airflow presets and DAGs

### OpenLineage

- **Wrong class:** `io.openlineage.spark.OpenLineageSparkListener`
- **Correct class:** `io.openlineage.spark.agent.OpenLineageSparkListener`
- **Wrong config:** `spark.openlineage.host`
- **Correct config:** `spark.openlineage.transport.type=http` + `spark.openlineage.transport.url=<endpoint>`

### Validated (Real)

- `com.nvidia.spark.SQLPlugin` — NVIDIA RAPIDS
- `org.apache.spark.scheduler.ResourceWaitTracker` — custom JAR in repo
- `org.apache.spark.shuffle.celeborn.RssShuffleManager` — Celeborn
- `org.apache.iceberg.*`, `org.apache.hadoop.*` — standard libs

## Consequences

- **Pros:** No ClassNotFoundException; correct OpenLineage integration
- **Cons:** Existing deployments with OTEL config need cleanup

## References

- Chart hallucination audit: `docs/reports/chart-hallucination-audit-2026-03-05.md`
- [OpenLineage Spark config](https://openlineage.io/docs/integrations/spark/configuration/usage/)
