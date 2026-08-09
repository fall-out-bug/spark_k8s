# State Management in Streaming

## Checkpoint Location

```python
spark.conf.set("spark.sql.streaming.checkpointLocation", "s3a://bucket/checkpoints/app")
```

## Stateful Operations

- `mapGroupsWithState` — Custom state
- `flatMapGroupsWithState` — State with timeout
- `session_window` — Session-based windows

## State Store

State stored in checkpoint. Clean up old checkpoints with retention policy.
