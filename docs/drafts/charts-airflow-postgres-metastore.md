# Зачем в чартах Airflow, PostgreSQL, Metastore

## Shared infra (spark-infra)

При `--shared-infra` матрица использует общие компоненты из spark-infra:

| Компонент | Где | Используется для |
|-----------|-----|------------------|
| **PostgreSQL** | spark-base | Hive Metastore + Airflow (одна БД, разные database) |
| **Hive Metastore** | spark-3.5 | Каталог Spark SQL, Iceberg |
| **MinIO** | spark-base | S3 для warehouse, event logs, spark-jobs |
| **History Server** | spark-3.5 | UI завершённых приложений |

PostgreSQL в shared — единый экземпляр для Metastore и Airflow (demo-full-spark-infra создаёт databases: spark_db, airflow).

## Два Standalone в spark-3.5

1. **sparkStandalone** (parent) — `sparkStandalone.enabled=true`
   - Только master + workers (templates/spark-standalone.yaml)
   - Без Airflow

2. **standalone subchart** — `standalone.enabled=true`
   - Master + workers + Airflow (webserver, scheduler) + Airflow PostgreSQL
   - Для demo (DAG-оркестрация)

Helm: при `condition: standalone.enabled` и отсутствии ключа в values subchart **загружается по умолчанию**. Поэтому run-matrix явно ставит `standalone.enabled=false` для standalone-сценариев.

## Airflow — почему в standalone subchart

Airflow завязан на Standalone исторически: demo-full-pipeline — ETL с DAG'ами, которые через KubernetesPodOperator запускают spark-submit на standalone master. Для матрицы тестов сборки Airflow не нужен. Demo — отдельные чарты/пресеты, к матрице не относятся.

## Матрица тестов

- Матрица использует **sparkStandalone** (parent), subchart отключён (`standalone.enabled=false`)
- С `--shared-infra`: MinIO, History, Metastore, PostgreSQL — из spark-infra
- Airflow в матрице **не поднимается** (run-matrix инжектит standalone.enabled=false)
