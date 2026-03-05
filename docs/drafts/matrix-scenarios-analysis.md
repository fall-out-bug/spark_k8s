# Матрица сценариев: анализ

## Размерности (dimensions)

| Размерность | Значения | Влияет на helm_values? |
|-------------|----------|------------------------|
| spark_version | 3.5.7, 3.5.8, 4.1.0, 4.1.1 | Да (spark.version) |
| connection_mode | connect, standalone | Да (connect.enabled, standalone.enabled) |
| k8s_mode | native, standalone | **Только при connect=true** |
| gpu | true, false | Да (features.gpu.enabled) |
| iceberg | true, false | Да (features.iceberg.enabled) |
| shuffle_service | true, false | Да (spark.shuffle.service.enabled) |
| openlineage | true, false | Да (openlineage.enabled) |
| platform | k8s, restricted | Да (security.podSecurityStandards) |

## Типы деплоя (4 штуки)

| Тип | connect | k8s_mode | helm | Что поднимается | Сценариев |
|-----|---------|----------|------|-----------------|-----------|
| **A** | true | native | connect.enabled=true, connect.backendMode=k8s | Connect server, executors как K8s pods | 128 |
| **B** | true | standalone | connect.enabled=true, standalone.enabled=true | Connect server + standalone master+workers | 32 |
| **C** | false | native | connect.enabled=false, kubernetes.enabled=true | Submitter pod, spark-submit --master k8s://... | 128 |
| **D** | false | standalone | connect.enabled=false, standalone.enabled=true | Только standalone master+workers | 32 |

## k8s_mode при connect=false — различие

- **native:** Spark native K8s — submitter pod, spark-submit --master k8s://... (driver+executors как K8s pods)
- **standalone:** Spark Standalone — master+workers, spark-submit --master spark://...

## Реальная матрица деплоя

| Фактически | Сценариев |
|------------|-----------|
| Connect + K8s native | 128 |
| Connect + Standalone backend | 32 |
| K8s native (без Connect) | 128 |
| Standalone only | 32 |
| **Итого** | **320** |

## Что тестировать

| Тип | connect pod | k8s-native submitter | standalone master | standalone worker | smoke/e2e/load |
|-----|-------------|----------------------|-------------------|-------------------|----------------|
| A | есть | — | — | — | exec в connect |
| B | есть | — | есть | есть | exec в connect |
| C | — | есть | — | — | exec в submitter, spark-submit --master k8s://... |
| D | — | — | есть | есть | exec в worker, spark-submit --master spark://... |
