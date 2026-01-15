# Локальная сборка и тестирование JupyterHub+Spark в Kubernetes (kubeadm)

Это руководство описывает процесс сборки образа JupyterHub со Spark 3.5.7 и развертывания в локальном Kubernetes кластере (kubeadm single-node).

## Предварительные требования

- Docker Engine установлен и запущен
- Kubernetes кластер (kubeadm single-node) настроен и работает
- `kubectl` настроен для работы с кластером
- Достаточно ресурсов: минимум 4 CPU, 8 GB RAM

Проверка кластера:
```bash
kubectl cluster-info
kubectl get nodes
```

## Шаг 1: Сборка образа JupyterHub

Перейдите в директорию проекта:
```bash
cd spark_k8s
```

Соберите образ JupyterHub со Spark 3.5.7:
```bash
docker build -t jupyterhub-spark:latest -f jupyterhub/Dockerfile jupyterhub/
```

Проверьте, что образ создан:
```bash
docker images | grep jupyterhub-spark
```

## Шаг 2: Загрузка образа в кластер

Для kubeadm кластера нужно загрузить образ в runtime, используемый кластером.

### Вариант A: containerd (обычно для kubeadm)

Если кластер использует containerd:
```bash
# Сохранить образ в tar
docker save jupyterhub-spark:latest -o jupyterhub-spark.tar

# Загрузить в containerd (на ноде кластера)
sudo ctr -n k8s.io images import jupyterhub-spark.tar

# Проверить
sudo ctr -n k8s.io images list | grep jupyterhub-spark
```

### Вариант B: CRI-O

Если кластер использует CRI-O:
```bash
# Сохранить образ
docker save jupyterhub-spark:latest -o jupyterhub-spark.tar

# Загрузить в CRI-O (на ноде кластера)
sudo podman load -i jupyterhub-spark.tar

# Или через skopeo
sudo skopeo copy docker-archive:jupyterhub-spark.tar containers-storage:jupyterhub-spark:latest
```

### Вариант C: Docker (если кластер использует Docker)

Если кластер использует Docker как runtime:
```bash
# На ноде кластера
docker load < jupyterhub-spark.tar
```

### Вариант D: Использование локального registry (рекомендуется для разработки)

Если в кластере настроен локальный registry:
```bash
# Тегнуть образ для registry
docker tag jupyterhub-spark:latest localhost:5000/jupyterhub-spark:latest

# Запустить локальный registry (если еще не запущен)
docker run -d -p 5000:5000 --name registry registry:2

# Запушить в registry
docker push localhost:5000/jupyterhub-spark:latest

# Обновить imagePullPolicy в манифестах на Always или IfNotPresent
```

## Шаг 3: Развертывание компонентов

Создайте namespace:
```bash
kubectl apply -f local-k8s/namespace.yaml
```

Разверните MinIO (объектное хранилище):
```bash
kubectl apply -f local-k8s/storage/minio-secret.yaml
kubectl apply -f local-k8s/storage/minio-deployment.yaml
kubectl apply -f local-k8s/storage/minio-service.yaml
```

Разверните Spark кластер:
```bash
kubectl apply -f local-k8s/spark/master-deployment.yaml
kubectl apply -f local-k8s/spark/master-service.yaml
kubectl apply -f local-k8s/spark/worker-deployment.yaml
kubectl apply -f local-k8s/spark/worker-service.yaml
```

Разверните JupyterHub:
```bash
kubectl apply -f local-k8s/jupyterhub/serviceaccount.yaml
kubectl apply -f local-k8s/jupyterhub/configmap.yaml
kubectl apply -f local-k8s/jupyterhub/secret.yaml
kubectl apply -f local-k8s/jupyterhub/deployment.yaml
kubectl apply -f local-k8s/jupyterhub/service.yaml
```

Или применить все манифесты сразу:
```bash
kubectl apply -f local-k8s/
```

## Шаг 4: Проверка статуса

Проверьте, что все поды запущены:
```bash
kubectl get pods -n dataops
```

Ожидаемый вывод:
```
NAME                            READY   STATUS    RESTARTS   AGE
jupyterhub-xxxxxxxxxx-xxxxx     1/1     Running   0          2m
minio-xxxxxxxxxx-xxxxx          1/1     Running   0          2m
spark-master-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
spark-worker-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

Проверьте логи JupyterHub:
```bash
kubectl logs -f deployment/jupyterhub -n dataops
```

Проверьте логи Spark Master:
```bash
kubectl logs -f deployment/spark-master -n dataops
```

## Шаг 5: Настройка MinIO (создание bucket)

Получите доступ к MinIO консоли (если настроен NodePort или port-forward):
```bash
# Port-forward для MinIO консоли
kubectl port-forward svc/minio 9001:9001 -n dataops
```

Откройте в браузере: http://localhost:9001
- Username: `minioadmin`
- Password: `minioadmin`

Создайте bucket `data-lake` через консоль или через CLI:
```bash
# Port-forward для MinIO API
kubectl port-forward svc/minio 9000:9000 -n dataops

# В другом терминале
export MC_HOST_local=http://minioadmin:minioadmin@localhost:9000
mc alias set local http://localhost:9000 minioadmin minioadmin
mc mb local/data-lake
mc ls local/
```

## Шаг 6: Доступ к JupyterHub

JupyterHub доступен через NodePort на порту 30080:
```bash
# Получить IP ноды
kubectl get nodes -o wide

# Или использовать port-forward
kubectl port-forward svc/jupyterhub 8000:8000 -n dataops
```

Откройте в браузере: http://localhost:8000 (или http://<node-ip>:30080)

Войдите с любым именем пользователя (DummyAuthenticator для локальной разработки).

## Шаг 7: Smoke-тест для Data Scientists

### Тест 1: Проверка окружения

В JupyterHub создайте новый notebook (JupyterLab откроется автоматически) и выполните:
```python
# Все уже готово! Проверяем окружение
print(f"Spark version: {spark.version}")
print(f"Spark master: {spark.sparkContext.master}")
print(f"Pandas version: {pd.__version__}")
print(f"MLflow tracking URI: {mlflow.get_tracking_uri()}")

# Проверяем доступные объекты
print("\n✨ Pre-configured objects:")
print("  - spark, ps (pyspark.pandas), mlflow, s3_client")
print("  - pd, np, plt, sns, px, go")
```

### Тест 2: Pandas-like работа с Spark DataFrame

```python
from pyspark.sql import Row

# Создаем тестовый DataFrame
test_data = [
    Row(id=1, name="Alice", value=100, category="A"),
    Row(id=2, name="Bob", value=200, category="B"),
    Row(id=3, name="Charlie", value=300, category="A"),
]
df = spark.createDataFrame(test_data)

# Показываем как pandas (красивое отображение)
display_spark_df(df, n=10)

# Pandas-like head() и tail()
display(head(df, n=5))
display(tail(df, n=5))

# Безопасная конвертация в pandas (с лимитом строк)
df_pd = to_pandas_safe(df, max_rows=1000)
df_pd.plot()  # Используем pandas/plotly/seaborn
```

### Тест 3: Работа с S3 и визуализация

```python
# Записываем в S3
write_s3_parquet(df, "s3a://data-lake/bronze/test-data")

# Читаем из S3
df_read = read_s3_parquet(spark, "s3a://data-lake/bronze/test-data")
display_spark_df(df_read)

# Визуализация с plotly (интерактивная)
import plotly.express as px
df_pd = to_pandas_safe(df_read)
fig = px.scatter(df_pd, x="id", y="value", color="category")
fig.show()
```

### Тест 4: MLflow tracking

```python
# Создать эксперимент
with mlflow.start_run(run_name="smoke-test"):
    mlflow.log_param("test_param", "value")
    mlflow.log_metric("test_metric", 42.0)
    print("✅ MLflow tracking works!")
```

### Тест 5: Проверка Spark UI

Spark Master UI доступен через port-forward:
```bash
kubectl port-forward svc/spark-master 8080:8080 -n dataops
```

Откройте в браузере: http://localhost:8080

### Пример notebook

Откройте пример notebook: `examples/01-quickstart-example.ipynb` в JupyterLab.
Он демонстрирует все возможности pandas-like UX.

## Устранение неполадок

### Проблема: Поды не запускаются

Проверьте события:
```bash
kubectl describe pod <pod-name> -n dataops
kubectl get events -n dataops --sort-by='.lastTimestamp'
```

### Проблема: ImagePullBackOff

Убедитесь, что образ загружен в кластер:
```bash
# Для containerd
sudo ctr -n k8s.io images list | grep jupyterhub-spark

# Для Docker
docker images | grep jupyterhub-spark
```

### Проблема: JupyterHub не может создать user pod

Проверьте RBAC:
```bash
kubectl get role,rolebinding -n dataops
kubectl describe rolebinding jupyterhub-spawner -n dataops
```

### Проблема: Spark не подключается к S3

Проверьте переменные окружения:
```bash
kubectl exec -it deployment/jupyterhub -n dataops -- env | grep S3
```

Проверьте доступность MinIO:
```bash
kubectl exec -it deployment/jupyterhub -n dataops -- curl http://minio:9000/minio/health/live
```

### Проблема: JDBC драйверы не найдены

Убедитесь, что драйверы скачаны в образе:
```bash
kubectl exec -it deployment/jupyterhub -n dataops -- ls -la /opt/spark/jars/ | grep -E "(postgres|oracle|vertica)"
```

## Очистка

Удалить все ресурсы:
```bash
kubectl delete -f local-k8s/
kubectl delete namespace dataops
```

## Следующие шаги

- Настройка persistent volumes для MinIO и user home directories
- Настройка Ingress для доступа к сервисам
- Интеграция с MLflow tracking server
- Настройка production-ready аутентификации

