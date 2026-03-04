# SQL Query Examples

Common SQL patterns for product analytics.

## Basic Queries

```sql
SELECT category, SUM(amount) as total
FROM sales
GROUP BY category
ORDER BY total DESC
LIMIT 10
```

## Date Filtering

```sql
SELECT * FROM events
WHERE event_date >= current_date() - INTERVAL 7 DAYS
```

## Joins

```sql
SELECT u.name, o.total
FROM users u
JOIN orders o ON u.id = o.user_id
```

See [Best Practices](./best-practices.md) for optimization tips.
