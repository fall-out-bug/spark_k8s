# Join Strategies

| Strategy | When Used | Pros | Cons |
|----------|-----------|------|------|
| **Broadcast** | Small table (<10MB) | No shuffle | Memory on driver |
| **Sort-Merge** | Default | Scalable | Shuffle cost |
| **Shuffle Hash** | Legacy | — | Deprecated |

## Hints

```sql
SELECT /*+ BROADCAST(small) */ * FROM large l JOIN small s ON l.id = s.id
```

## AQE

`spark.sql.adaptive.enabled=true` — Spark chooses strategy at runtime.
