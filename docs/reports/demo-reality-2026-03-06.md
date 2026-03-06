# Demo: Реальность vs Декор

**Дата:** 2026-03-06

`check-demo-health.sh` проверяет только **декорации**. Для проверки реальной работоспособности используйте `./scripts/validate-demo-reality.sh` — он проверяет UI, MinIO и данные. — поды Running, сервисы существуют. Он не проверяет, что можно реально нажать и получить результат.

---

## Что проверяет health check (декор)

| Проверка | Что смотрит |
|----------|-------------|
| Namespace exists | kubectl get ns |
| Release deployed | helm list |
| Pods Running | status.phase=Running |
| No CrashLoopBackOff | containerStatuses |
| Services exist | kubectl get svc |

**Не проверяет:** можно ли запустить DAG, выполнить ноутбук, открыть Jupyter, получить данные в Grafana.

---

## Что должно работать по гайду (и что ломается)

| Действие | Ожидание | Реальность |
|----------|----------|------------|
| Airflow → запустить spark_standalone_load_demo | DAG завершается | ✅ Работает (скрипт встроен) |
| Airflow → запустить nyc_taxi_ml_full_pipeline | DAG завершается | ❌ ImagePullBackOff (spark-custom-ml) или нет данных (nyc-taxi/raw) |
| Airflow → запустить citibike_analytics_pipeline | DAG завершается | ❌ Нет sample-данных в citibike/ |
| Airflow → запустить movielens_recommendation_pipeline | DAG завершается | ❌ Нет u.data в movielens/raw/ |
| Jupyter → открыть http://localhost:18888/lab | Jupyter Lab | ⚠️ Port-forward мёртв или 404 |
| Jupyter → выполнить citibike_eda.ipynb | PySpark работает | ❌ ModuleNotFoundError: pyspark |
| Grafana → Explore → Prometheus | Метрики | ⚠️ Если DAG'и не бежали — пусто |
| History Server → приложения | Список job'ов | ⚠️ Только если DAG'и писали event log |

---

## Блокеры (цепочка зависимостей)

1. **Образы** — spark-custom:3.5.7, spark-k8s-jupyter:3.5-3.5.7, spark-k8s/airflow:2.11.0 должны быть в minikube. Без них — ImagePullBackOff.

2. **DAG'и** — используют образ из ConfigMap. Если в репо dags/ был spark-custom-ml, а в chart — spark-custom, то Airflow мог загрузить старый DAG. Нужен restart scheduler после helm upgrade.

3. **Spark-jobs в MinIO** — DAG'и качают скрипты из spark-jobs/dags/spark_jobs/. Без `upload-spark-jobs-to-minio.sh` — FileNotFoundError.

4. **Данные для DAG'ов:**
   - nyc_taxi: нужен `upload-nyc-taxi-sample.sh` (nyc-taxi/raw/*.parquet)
   - movielens: нужен movielens/raw/u.data (нет скрипта загрузки)
   - citibike: citibike_feature_engineering генерирует synthetic data — может работать без предзагрузки

5. **Jupyter** — образ должен иметь PySpark в Python kernel. jupyter/all-spark-notebook:latest — нет. spark-k8s-jupyter:3.5-3.5.7 — есть, но образ нужно собрать и загрузить.

6. **Port-forwards** — nohup в фоне, умирают. После restore/deploy нужно перезапустить `start-ui-portforwards.sh`.

---

## Минимальный рабочий путь (без бутафории)

Чтобы **хотя бы один** сценарий работал от начала до конца:

```bash
# 1. Образы (обязательно)
eval $(minikube docker-env)
docker build -t spark-custom:3.5.7 -f docker/spark-custom/Dockerfile.3.5.7 docker/
docker build -t spark-k8s-jupyter:3.5-3.5.7 -f docker/jupyter/Dockerfile docker/jupyter
docker build -t spark-k8s/airflow:2.11.0 -f docker/optional/airflow/Dockerfile docker/optional/airflow/
minikube image load spark-custom:3.5.7 spark-k8s-jupyter:3.5-3.5.7 spark-k8s/airflow:2.11.0

# 2. Deploy
./scripts/deploy-demo-minikube.sh

# 3. Подготовка данных (обязательно)
./scripts/upload-spark-jobs-to-minio.sh spark-infra
./scripts/upload-nyc-taxi-sample.sh spark-infra

# 4. Restart Airflow scheduler (подхватить DAG с правильным image)
kubectl rollout restart deployment -n spark-infra spark-infra-airflow-scheduler

# 5. Port-forwards
pkill -f "kubectl port-forward" 2>/dev/null || true
./tests/observability/start-ui-portforwards.sh

# 6. Проверка
# Airflow: запустить spark_standalone_load_demo — должен завершиться
# Airflow: запустить nyc_taxi_ml_full_pipeline — должен дойти до feature_engineering
# Jupyter: http://localhost:18888/lab — открыть citibike_eda, выполнить — PySpark должен работать
```

---

## Исправления (2026-03-06)

1. **Порядок шагов** — образы теперь первый шаг (раздел 2 гайда). Без них deploy падал с ImagePullBackOff.
2. **build-and-load-matrix-images.sh** — добавлен Airflow в --quick (раньше не собирался).
3. **deploy-demo-minikube.sh** — pre-check образов перед деплоем; явная ошибка если образов нет.
4. **deploy-observability.sh** — убрано подавление ошибок helm install.

---

## Что нужно для полной работоспособности

1. **check-demo-health.sh** — добавить проверки:
   - curl localhost:18888/lab → 200
   - В MinIO есть spark-jobs/dags/spark_jobs/*.py
   - В MinIO есть nyc-taxi/raw/*.parquet (если DAG nyc_taxi включён)

2. **deploy-demo-minikube.sh** — после деплоя автоматически вызывать upload-spark-jobs и upload-nyc-taxi-sample (или явно писать в вывод "ОБЯЗАТЕЛЬНО выполните шаги 2.4 и 2.5").

3. **Port-forwards** — либо systemd/supervisor, либо явная проверка в health check.

4. **movielens/citibike** — либо добавить скрипты загрузки sample-данных, либо отключить эти DAG'и в demo preset и честно написать в гайде "только spark_standalone_load_demo и nyc_taxi".

5. **Документация** — в начале demo-screencast-guide честно: "Работают: spark_standalone_load_demo, nyc_taxi (после upload-nyc-taxi-sample). movielens, citibike — требуют данных."
