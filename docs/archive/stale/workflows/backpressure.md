# Backpressure Handling

Structured Streaming applies backpressure automatically.

## Configuration

- `spark.sql.streaming.maxFilesPerTrigger` — Limit files per micro-batch
- `spark.sql.streaming.minBatchesToRetain` — Checkpoint retention

## Kafka Source

- `maxOffsetsPerTrigger` — Limit records per batch
- Monitor `recordsPerBatch` metric

## Tuning

If batches lag, reduce `maxFilesPerTrigger` or increase executor count.
