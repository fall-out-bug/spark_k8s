# Заметки по совместимости с OpenShift

**Тестировалось на:** Minikube  
**Подготовлено для:** Ограничений OpenShift (PSS `restricted` / SCC `restricted`)

## Обзор

Чарты в этом репозитории **подготовлены** для ограничений безопасности OpenShift (Pod Security Standards `restricted` / SecurityContextConstraints `restricted`), но **тестировались только на Minikube**.

## Усиление безопасности

### Pod Security Standards (PSS) `restricted`

Когда `security.podSecurityStandards: true` в values, чарты применяют настройки, совместимые с PSS `restricted`:

- **`runAsNonRoot: true`** — Поды запускаются от пользователя не-root
- **`seccompProfile.type: RuntimeDefault`** — Профиль seccomp по умолчанию
- **`allowPrivilegeEscalation: false`** — Без повышения привилегий
- **`capabilities.drop: ALL`** — Все capabilities удалены
- **`readOnlyRootFilesystem: true`** — Корневая файловая система только для чтения (записываемые пути монтируются через `emptyDir`/PVC)

### Что настраивается

#### Ослабление PostgreSQL

Встроенный PostgreSQL (для Hive Metastore, Airflow, MLflow) может работать в "ослабленном" режиме для локального тестирования:

```yaml
security:
  podSecurityStandards: true
  postgresql:
    relaxed: true  # Позволяет postgres работать с ослабленным PSS (только для local/test)
```

**Примечание:** В продакшене используйте внешнюю базу данных PostgreSQL. Встроенный PostgreSQL предназначен только для локальных/тестовых окружений.

#### UID/GID пользователей

Вы можете настроить UID/GID для подов:

```yaml
security:
  podSecurityStandards: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
```

Настройте эти значения в соответствии с требованиями вашего кластера OpenShift.

## Что было протестировано

### Тестировалось на Minikube

- Кластер Spark Standalone (master + workers) с включённым PSS hardening
- Airflow с KubernetesExecutor (поды с PSS hardening)
- Выполнение задания SparkPi
- Запуски DAG Airflow (`example_bash_operator`, `spark_etl_synthetic`)
- Инициализация бакетов MinIO
- Spark Master HA с восстановлением на PVC

### Не валидировалось на OpenShift

Следующее **не** было валидировано на реальном кластере OpenShift:

- Применение SCC `restricted` (тестировалась только эмуляция PSS)
- Специфичные для OpenShift network policies
- Конфигурация OpenShift routes (Ingress является общим)
- OpenShift image streams (чарты используют стандартные Docker образы)
- Интеграция с OpenShift service mesh (если включена)

## Известные ограничения

### Совместимость образа PostgreSQL

Официальный образ `postgres:16-alpine` не полностью совместим со строгим PSS `restricted` во многих настройках. Чарт предоставляет "ослабленный" режим для встроенного PostgreSQL:

```yaml
security:
  postgresql:
    relaxed: true  # Рекомендуется для local/test
```

**Рекомендация для продакшена:** Используйте внешнюю базу данных PostgreSQL, управляемую вашей платформенной командой.

### Storage Classes

Чарты используют StorageClass по умолчанию для PVC. В OpenShift вам может потребоваться:

1. Указать StorageClass явно:
```yaml
sparkMaster:
  ha:
    persistence:
      storageClass: "gp3"  # Пример: AWS EBS
```

2. Убедиться, что StorageClass существует и доступен в вашем namespace.

### Права ServiceAccount

Чарты создают ServiceAccount с правами RBAC для:
- Создания/удаления подов (для Spark executors, Airflow workers)
- Чтения ConfigMaps/Secrets

В OpenShift убедитесь, что ваш namespace имеет достаточные права, или настройте RBAC по необходимости.

## Чеклист деплоя для OpenShift

Перед деплоем в OpenShift:

- [ ] Просмотрите и настройте `security.runAsUser`/`runAsGroup`/`fsGroup` в соответствии с вашим кластером
- [ ] Установите `security.postgresql.relaxed: false` если используете встроенный PostgreSQL (или используйте внешнюю БД)
- [ ] Настройте StorageClass для PVC (Spark Master HA, MinIO, PostgreSQL)
- [ ] Проверьте, что ServiceAccount имеет необходимые права
- [ ] Протестируйте в непродакшенном namespace сначала
- [ ] Просмотрите network policies (если включены в вашем кластере)

## Устранение неполадок

### Поды зависли в `Pending`

**Проверка:**
```bash
kubectl describe pod <pod-name> -n <namespace>
```

**Частые причины:**
- StorageClass недоступен
- Недостаточно ресурсов (CPU/память)
- Нарушения SecurityContext (проверьте SCC/PSS)

### Ошибки Permission Denied

**Симптомы:** `Operation not permitted`, `Permission denied`

**Проверка:**
```bash
# Проверка security context
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.securityContext}'

# Проверка SCC (OpenShift)
oc describe scc restricted
```

**Исправление:** Настройте `security.runAsUser`/`runAsGroup` или используйте `security.postgresql.relaxed: true` для встроенного PostgreSQL.

## Справочник

- **Гайд по валидации:** [`docs/guides/ru/validation.md`](validation.md)
- **Гайды по чартам:** [`docs/guides/ru/charts/`](charts/)
- **Карта репозитория:** [`docs/PROJECT_MAP.md`](../../PROJECT_MAP.md)
- **English version:** [`docs/guides/en/openshift-notes.md`](../../en/openshift-notes.md)
