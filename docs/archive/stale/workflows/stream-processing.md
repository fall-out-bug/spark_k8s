# Stream Processing

See [Streaming Tutorial](../tutorials/workflows/streaming.md) for the full guide.

## Key Concepts

- **Structured Streaming** — DataFrame API for streaming
- **Checkpoints** — Fault tolerance via checkpoint location
- **Watermarks** — Late data handling

## Exactly-Once Semantics

Use `spark.sql.streaming.checkpointLocation` and idempotent sinks (Delta, Iceberg).

## Backpressure

Spark throttles read rate automatically. Tune `spark.sql.streaming.maxFilesPerTrigger`.
