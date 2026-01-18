# Быстрый старт Spark 4.1.0 (5 минут)

Развертывание Apache Spark 4.1.0 с Spark Connect и Jupyter в Minikube.

## Требования

- Запущенный Minikube
- Установленный Helm 3.x
- Собранные Docker-образы:
  - `spark-custom:4.1.0`
  - `jupyter-spark:4.1.0`

Быстрая проверка:

```bash
minikube status
helm version
docker images | grep -E 'spark-custom|jupyter-spark'
```

## 1. Установка Spark 4.1.0

```bash
helm install spark-41 charts/spark-4.1 \
  --set spark-base.enabled=true \
  --set connect.enabled=true \
  --set jupyter.enabled=true \
  --set hiveMetastore.enabled=true \
  --set historyServer.enabled=true \
  --wait
```

## 2. Проверка развертывания

```bash
kubectl get pods -l app.kubernetes.io/instance=spark-41
# Все поды должны быть Running/Ready
```

## 3. Доступ к Jupyter

```bash
kubectl port-forward svc/spark-41-spark-41-jupyter 8888:8888
# Откройте http://localhost:8888
```

## 4. Первое задание Spark

В Jupyter создайте новый notebook и выполните:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("Quickstart") \
    .remote("sc://spark-41-spark-41-connect:15002") \
    .getOrCreate()

df = spark.range(1000000).selectExpr("id", "id * 2 as doubled")
df.show(5)

print(f"Версия Spark: {spark.version}")
```

## 5. (Опционально) History Server

```bash
kubectl port-forward svc/spark-41-spark-41-history 18080:18080
# Откройте http://localhost:18080
```

## Дальнейшие шаги

- [Производственное развертывание](SPARK-4.1-PRODUCTION-RU.md)
- [Интеграция с Celeborn](CELEBORN-GUIDE.md)
- [Spark Operator](SPARK-OPERATOR-GUIDE.md)
