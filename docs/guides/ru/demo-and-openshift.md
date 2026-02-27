# Демо NYC Taxi: запуск и внедрение (включая OpenShift)

Пошаговый гайд по двум задачам:

1. Как быстро запустить и проверить демо-пайплайн NYC Taxi (Airflow + Spark Standalone + MinIO).
2. Как перенести этот же подход в свою инфраструктуру, с акцентом на OpenShift.

---

## 1) Что именно считается "демо"

В этом репозитории сейчас есть два практических режима:

- **Полный demo-стенд**: `charts/spark-3.5/values-demo-full-pipeline.yaml`
  - Поднимает много компонентов (включая Jupyter/Connect/monitoring).
  - Удобен для презентации и end-to-end показа платформы.
- **Сфокусированный NYC Taxi ML pipeline**: `charts/spark-3.5/values-airflow-sc-final.yaml`
  - Под NYC Taxi DAG через Airflow + Spark Standalone.
  - Проще и стабильнее для воспроизводимых прогонов DAG.

Для рабочих smoke/e2e проверок NYC Taxi лучше использовать второй вариант.

---

## 2) Быстрый запуск демо на Kubernetes (Minikube/обычный K8s)

### 2.1. Пререквизиты

- Kubernetes-кластер (локальный или удаленный).
- `kubectl`, `helm`.
- Доступные образы:
  - `spark-custom:3.5.7`
  - `spark-k8s/airflow:2.11.0`
- Ресурсы (минимум для стабильного NYC Taxi demo):
  - 6 vCPU
  - 12+ Gi RAM (лучше 16+ Gi)

### 2.2. Деплой

```bash
kubectl create namespace spark-airflow

helm dependency build charts/spark-3.5

helm upgrade --install airflow-sc charts/spark-3.5 \
  -n spark-airflow \
  -f charts/spark-3.5/values-airflow-sc-final.yaml
```

Проверка rollout:

```bash
kubectl rollout status -n spark-airflow deploy/airflow-sc-standalone-airflow-scheduler
kubectl rollout status -n spark-airflow deploy/airflow-sc-standalone-airflow-webserver
kubectl rollout status -n spark-airflow deploy/airflow-sc-standalone-worker
```

### 2.3. Проверка, что DAG действительно подхватился из чарта

```bash
kubectl exec -n spark-airflow deploy/airflow-sc-standalone-airflow-scheduler -- \
  airflow dags list
```

Ожидаемо: `nyc_taxi_ml_full_pipeline`.

### 2.4. Прогон end-to-end

```bash
kubectl exec -n spark-airflow deploy/airflow-sc-standalone-airflow-scheduler -- \
  airflow dags test nyc_taxi_ml_full_pipeline 2026-02-27
```

Проверка статуса:

```bash
kubectl exec -n spark-airflow deploy/airflow-sc-standalone-airflow-scheduler -- \
  airflow dags state nyc_taxi_ml_full_pipeline 2026-02-27
```

Ожидаемо: `success`.

---

## 3) Что и где настраивать под свою инфраструктуру

### 3.1. Слои конфигурации

- **Базовый чарт**: `charts/spark-3.5`
- **Целевые values**:
  - для "тяжелого" полного демо: `charts/spark-3.5/values-demo-full-pipeline.yaml`
  - для NYC Taxi pipeline: `charts/spark-3.5/values-airflow-sc-final.yaml`
- **DAG в chart-пакете**:
  - `charts/spark-3.5/charts/spark-standalone/dags/nyc_taxi_ml_full_pipeline.py`

### 3.2. Что менять в первую очередь

- **Образы**: перевести на ваш registry (`image.repository`, `image.tag`, `imagePullSecrets`).
- **Ресурсы**: под ваш quota/limits (`standalone.master/worker`, `standalone.airflow.*.resources`).
- **Storage/S3**: endpoint/credentials, либо внешний объектный стор.
- **Секреты**: убрать дефолтные пароли в values, использовать SealedSecret/ExternalSecret/Vault.
- **Имена namespace/release**: под ваши naming-правила.

### 3.3. Рекомендуемый подход

Не редактировать базовые values "в лоб", а держать отдельные overlays:

- `values-dev.yaml`
- `values-stage.yaml`
- `values-prod.yaml`
- `values-openshift.yaml`

И ставить их через `-f` цепочкой:

```bash
helm upgrade --install airflow-sc charts/spark-3.5 \
  -n spark-airflow \
  -f charts/spark-3.5/values-airflow-sc-final.yaml \
  -f ./overlays/values-stage.yaml
```

---

## 4) OpenShift: практический сценарий внедрения

## 4.1. Базовые отличия OpenShift

- Жесткие SCC/PSS ограничения (особенно `restricted`).
- Часто обязательный внутренний registry и pull secrets.
- Предпочтение Route вместо Ingress.
- Более строгие quota/limitRange в namespace.

См. также: `docs/guides/ru/openshift-notes.md`.

### 4.2. Выбор профиля безопасности

В репозитории есть готовые пресеты:

- `charts/spark-3.5/presets/openshift/restricted.yaml` (рекомендуется)
- `charts/spark-3.5/presets/openshift/anyuid.yaml` (только для edge-cases)

Важно: эти пресеты ориентированы на сценарий Spark Connect + внешние сервисы. Для NYC Taxi Airflow+Standalone берите их как шаблон по security-части и накладывайте на ваш values-файл.

### 4.3. Минимальный checklist перед деплоем в OpenShift

1. Подготовить namespace и rights.
2. Назначить SCC сервисным аккаунтам, если этого требует политика кластера.
3. Перенести образы в ваш registry и настроить `imagePullSecrets`.
4. Вынести секреты (S3/PostgreSQL) в Secret-менеджмент.
5. Проверить StorageClass и PVC стратегию.

Пример команд:

```bash
oc new-project spark-airflow

# Пример: дать restricted SCC сервисным аккаунтам релиза
oc adm policy add-scc-to-user restricted -z spark-standalone -n spark-airflow
oc adm policy add-scc-to-user restricted -z spark -n spark-airflow
```

### 4.4. Деплой NYC Taxi demo в OpenShift (практичный путь)

1. Скопируйте `charts/spark-3.5/values-airflow-sc-final.yaml` в свой overlay, например `overlays/values-openshift-nyc.yaml`.
2. В overlay задайте:
   - registry/imagePullSecrets
   - `security.*` (runAsUser/runAsGroup/fsGroup по требованиям кластера)
   - внешние endpoint/credentials
   - ресурсы под quotas
3. Выполните деплой:

```bash
helm upgrade --install airflow-sc charts/spark-3.5 \
  -n spark-airflow \
  -f charts/spark-3.5/values-airflow-sc-final.yaml \
  -f overlays/values-openshift-nyc.yaml
```

### 4.5. Публикация UI через Route

```bash
oc expose svc/airflow-sc-standalone-airflow-webserver -n spark-airflow
oc get route -n spark-airflow
```

При необходимости добавьте TLS termination и policy согласно стандартам платформенной команды.

### 4.6. Внешние сервисы (рекомендуется для stage/prod)

Для прод-контуров обычно отключают встроенные stateful-компоненты и используют managed сервисы:

- внешний S3/MinIO
- внешний PostgreSQL

Это уменьшает риск с SCC/volume permissions и упрощает сопровождение.

---

## 5) Операционная модель (после внедрения)

### 5.1. Регрессия после каждого изменения values/DAG

Минимум:

1. `helm template` (проверка рендера)
2. rollout status всех ключевых deployment
3. `airflow dags list`
4. `airflow dags test nyc_taxi_ml_full_pipeline <date>`

### 5.2. Типовые причины падений

- **OOM/Exit 137**: слишком агрессивные ресурсы executor/worker.
- **KPO transient 404**: гонка на удалении pod; в DAG уже включено `reattach_on_restart=False`.
- **ImagePullBackOff на ML задачах**: образ `spark-custom-ml:3.5.7` не загружен в cluster runtime.
  - Для minikube: `minikube image load spark-custom-ml:3.5.7`
  - Для OpenShift/prod: пуш образа в доступный registry + `imagePullSecrets`.
- **S3 path mismatch**: разные пути фичей/моделей между job-скриптами.
- **Python deps mismatch**: Airflow/Spark image без нужных библиотек.

### 5.3. Проверенный baseline для стабильного прогона

- DAG: `dags/nyc_taxi_ml_full_pipeline.py`.
- KPO задачи используют:
  - `image="spark-custom-ml:3.5.7"`
  - `namespace=CONFIG["namespace"]`
  - `random_name_suffix=True`
  - `reattach_on_restart=False`
  - `on_finish_action="keep_pod"`
  - `is_delete_operator_pod=False`
- Для chart-пакета синхронная копия DAG должна быть обновлена:
  - `charts/spark-3.5/charts/spark-standalone/dags/nyc_taxi_ml_full_pipeline.py`

---

## 6) Рекомендуемая стратегия внедрения по этапам

1. **Dev (локально/тестовый k8s)**: добиться стабильного `dags test`.
2. **OpenShift non-prod**: включить ограничения SCC/PSS и quota, прогнать end-to-end.
3. **Stage**: внешние S3/PostgreSQL + real secrets + observability.
4. **Prod**: GitOps-процесс, change windows, rollback plan, SLO/alerts.

---

## 7) Полезные ссылки в репозитории

- Основной demo readme: `charts/spark-3.5/README-demo-full-pipeline.md`
- Финальные values для NYC Taxi pipeline: `charts/spark-3.5/values-airflow-sc-final.yaml`
- OpenShift presets: `charts/spark-3.5/presets/openshift/README.md`
- OpenShift notes (RU): `docs/guides/ru/openshift-notes.md`
- Валидация (RU): `docs/guides/ru/validation.md`

---

## 8) Завершение сессии без потери данных

### 8.1. Что можно безопасно останавливать

- Для локальной отладки в minikube используйте **остановку**, а не удаление кластера:

```bash
minikube stop
```

Это сохраняет состояние диска minikube (включая PVC/PV и данные MinIO/PostgreSQL).

### 8.2. Чего не делать, если важны данные

- Не выполнять `minikube delete`.
- Не удалять namespace с PVC (`kubectl delete ns spark-airflow`), пока не сделан backup.

### 8.3. Рекомендованный pre-stop checklist

1. Проверить, что нет активных task pod в `Running`.
2. Зафиксировать статус последнего прогона:

```bash
kubectl exec -n spark-airflow deploy/airflow-sc-standalone-airflow-scheduler -- \
  airflow dags state nyc_taxi_ml_full_pipeline 2026-02-24
```

3. Сохранить артефакты логов (если нужно для отчета).
4. Остановить cluster: `minikube stop`.

### 8.4. Быстрый старт после паузы

```bash
minikube start
kubectl get pods -n spark-airflow
```

Если локальный образ очищен runtime-ом, повторно загрузить:

```bash
minikube image load spark-custom-ml:3.5.7
```
