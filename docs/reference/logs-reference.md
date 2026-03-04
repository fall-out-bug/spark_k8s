# Log Format Reference

Spark driver/executor logs use JSON format when `spark.logFormat=json`.

## Fields

- `timestamp` — ISO 8601
- `level` — INFO, WARN, ERROR
- `message` — Log message
- `logger` — Logger name

## Query in Loki

```
{app="spark-driver"} |= "ERROR"
```
