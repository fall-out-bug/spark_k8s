# Advanced SQL Patterns

## Window Functions

```sql
SELECT *, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY ts DESC) as rn
FROM events
```

## CTEs

```sql
WITH ranked AS (
  SELECT *, RANK() OVER (PARTITION BY category ORDER BY amount DESC) as rk
  FROM sales
)
SELECT * FROM ranked WHERE rk <= 10
```

## Optimizations

- Push predicates into subqueries
- Use `CACHE TABLE` for repeated reads
- Enable AQE: `spark.sql.adaptive.enabled=true`
