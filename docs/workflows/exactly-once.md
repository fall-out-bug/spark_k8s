# Exactly-Once Semantics

Achieve exactly-once processing in Structured Streaming.

## Requirements

1. **Checkpoint** — `spark.sql.streaming.checkpointLocation`
2. **Idempotent sink** — Delta, Iceberg, or custom
3. **Transactional writes** — Commit only after batch success

## Delta Lake

Delta provides ACID transactions. Use `DeltaTable.forPath()` for upserts.

## Verification

Check `spark.sql.streaming.numInputRows` and sink record counts match.
