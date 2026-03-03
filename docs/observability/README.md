# Observability — spark_k8s Constructor

Единая точка входа для observability: рецепты по персонам, инвентарь, примеры.

---

## Персоны → Рецепты

| Персона | 5-min Guide | Назначение |
|---------|--------------|------------|
| **DevOps** | [devops-5min](recipes/devops-5min.md) | Система в порядке? |
| **DataOps** | [dataops-5min](recipes/dataops-5min.md) | Трейсы и даши по джобам |
| **Tech Lead** | [techlead-5min](recipes/techlead-5min.md) | Состояние пайплайнов |
| **Data Engineer** | [data-engineer-5min](recipes/data-engineer-5min.md) | Прослеживаемость данных |
| **Data Scientist** | [ds-5min](recipes/ds-5min.md) | Чтоб работало |

---

## Документы

| Документ | Описание |
|----------|----------|
| [INVENTORY](INVENTORY.md) | Инвентарь: dashboards, метрики, логи, демо |
| [Examples](examples/README.md) | Примеры алертов и отчётов |

---

## Runbooks

- [demo-runbook-shared-infra](../../tests/demo-runbook-shared-infra.md) — развёртывание observability
- [Runbook Index](../operations/portal/runbook-index.md) — все runbooks проекта

---

## Deploy

```bash
./scripts/tests/minikube/deploy-observability.sh
```

См. [INVENTORY](INVENTORY.md) § Deploy Order.
