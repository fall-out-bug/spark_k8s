# Spark Custom Images

Кастомные образы Apache Spark с полным стеком зависимостей для продакшена.

## Состав

### Компоненты
- **Spark**: 3.5.7 / 4.1.0
- **Hadoop**: 3.4.2 (фиксированная версия для обеих веток)
- **Java**: 17 (OpenJDK)
- **Python**: 3.11 с PySpark

### JDBC Драйверы
- **PostgreSQL**: 42.7.4
- **Oracle**: 23.5 (ojdbc11)
- **Vertica**: 12.0.4
- **Kafka**: 3.7.1

### Дополнительно
- AWS SDK Bundle 1.12.795 (S3/MinIO поддержка)
- Kubernetes Python клиент
- Python библиотеки: pandas, numpy, pyarrow, matplotlib, seaborn

## Сборка

### Локальный registry
```bash
cd docker/spark-custom
make build-3.5.7
make build-4.1.0
```

### Удалённый registry
```bash
make build-3.5.7 REGISTRY=registry.example.com IMAGE_NAME=spark-k8s
make push-3.5.7 REGISTRY=registry.example.com IMAGE_NAME=spark-k8s
```

### Все версии сразу
```bash
make all          # Сборка всех образов
make push         # Сборка и пуш всех образов
```

## Использование

### В values.yaml
```yaml
connect:
  image:
    repository: localhost:5000/spark-custom
    tag: "3.5.7"
```

### Lokiload для minikube
```bash
# Сборка
make build-3.5.7

# Загрузка в minikube
minikube image load localhost:5000/spark-custom:3.5.7
```

### Для OpenShift
```bash
# Сборка для internal registry
make build-3.5.7 REGISTRY=image-registry.openshift-image-registry.svc:5000/my-project
```

## Структура образов

```
/opt/spark/
├── bin/          # CLI утилиты
├── sbin/         # Управляющие скрипты
├── jars/         # Spark + Hadoop + JDBC драйверы
├── python/       # PySpark
├── work/         # Рабочая директория
├── events/       # Event logs
└── logs/         # Логи
```

## Переменные окружения

| Переменная | Значение |
|------------|----------|
| SPARK_HOME | /opt/spark |
| JAVA_HOME | /usr/lib/jvm/java-17-openjdk-amd64 |
| PYTHONPATH | /opt/spark/python |

## Порты

| Порт | Описание |
|------|----------|
| 4040 | Spark Web UI |
| 6066 | REST API |
| 7077 | Cluster Manager |
| 7078 | Driver |
| 7079 | Block Manager |
| 8080 | Shuffle Service |
| 8081 | Worker |
| 15002 | Spark Connect |
| 18080 | History Server |

## Размеры образов

- spark-custom:3.5.7 ~ 1.2 GB
- spark-custom:4.1.0 ~ 1.3 GB

## Troubleshooting

### Проверка версии Hadoop в образе
```bash
docker run --rm localhost:5000/spark-custom:3.5.7 ls -la /opt/spark/jars/hadoop-common*.jar
```

### Проверка JDBC драйверов
```bash
docker run --rm localhost:5000/spark-custom:3.5.7 ls -la /opt/spark/jars/*.jar
```

### Тестовый запуск
```bash
docker run --rm -it localhost:5000/spark-custom:3.5.7 /opt/spark/bin/spark-shell --version
```
