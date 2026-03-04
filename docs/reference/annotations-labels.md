# Annotations and Labels

## Pod Labels

| Label | Purpose |
|-------|---------|
| `app.kubernetes.io/name` | Component name |
| `app.kubernetes.io/instance` | Release name |
| `spark-role` | driver, executor |

## Annotations

| Annotation | Purpose |
|------------|---------|
| `prometheus.io/scrape` | Enable scraping |
| `prometheus.io/port` | Metrics port |

See Helm values for customization.
