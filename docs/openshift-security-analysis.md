# OpenShift Security Analysis

## Обзор

Анализ требований безопасности для деплоев в OpenShift в текущих Helm чартах Spark.

**Дата анализа:** 2026-02-01
**Статус:** ⚠️ Требуется внимания

---

## Текущее состояние

### ✅ Что работает корректно

#### 1. Pod Security Context (spark-base)

**Файл:** `charts/spark-base/templates/_helpers.tpl`

```yaml
{{- define "spark-base.podSecurityContext" -}}
runAsNonRoot: true
{{- with .Values.security.runAsUser }}
runAsUser: {{ . }}
{{- end }}
{{- with .Values.security.runAsGroup }}
runAsGroup: {{ . }}
{{- end }}
{{- with .Values.security.fsGroup }}
fsGroup: {{ . }}
{{- end }}
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{- define "spark-base.containerSecurityContext" -}}
allowPrivilegeEscalation: false
{{- if hasKey .Values.security "readOnlyRootFilesystem" }}
readOnlyRootFilesystem: {{ .Values.security.readOnlyRootFilesystem }}
{{- end }}
capabilities:
  drop:
    - ALL
{{- end }}
```

**Комментарий:** Этот шаблон **ПОЛНОСТЬЮ СОВМЕСТИМ** с Pod Security Standards `restricted`.

#### 2. RBAC Configuration

**Файлы:**
- `charts/spark-3.5/templates/rbac.yaml`
- `charts/spark-4.1/templates/rbac.yaml`

- ✅ ServiceAccount создаются
- ✅ Role/RoleBinding настроены
- ✅ Правила для Kubernetes API доступны

#### 3. Environment-specific overrides

**Файлы:**
- `charts/spark-3.5/environments/prod/values.yaml` - `podSecurityStandards: true`
- `charts/spark-3.5/environments/staging/values.yaml` - `podSecurityStandards: true`
- `charts/spark-3.5/environments/dev/values.yaml` - `podSecurityStandards: false`

**Комментарий:** Правильные значения для prod/staging, но требуется явно указывать environment.

---

### ⚠️ Что было утеряно (по сравнению со spark-3.5-old)

#### 1. Namespace template с PSS labels

**Был в:** `charts/spark-3.5-old/charts/spark-standalone/templates/namespace.yaml`

```yaml
{{- if .Values.security.createNamespace }}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Release.Namespace }}
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
{{- end }}
```

**Текущее состояние:** ❌ Нет namespace.yaml в spark-3.5 и spark-4.1

**Влияние:** OpenShift не будет автоматически применять PSS политики к namespace.

#### 2. OpenShift UID ranges комментарий

**Был в:** `charts/spark-3.5-old/charts/spark-standalone/values.yaml:172`

```yaml
security:
  # Use numeric UID/GID for PSS runAsNonRoot (override for OpenShift UID ranges).
  runAsUser: 1000
  runAsGroup: 1000
```

**Текущее состояние:** Комментарий отсутствует

**Влияние:** Меньше документации для OpenShift пользователей.

#### 3. PostgreSQL relaxed mode

**Был в:** `charts/spark-3.5-old/charts/spark-standalone/values.yaml:274`

```yaml
security:
  postgresql:
    relaxed: true  # postgres:16-alpine не совместим с strict PSS restricted
```

**Текущее состояние:** Отсутствует

**Влияние:** PostgreSQL может не работать в strict PSS режиме.

#### 4. Default podSecurityStandards: true

**Был в:** `charts/spark-3.5-old/charts/spark-standalone/values.yaml:269`

```yaml
security:
  podSecurityStandards: true
```

**Текущее состояние:** `podSecurityStandards: false` (в values.yaml)

**Влияние:** Безопасность не включена по умолчанию.

---

## OpenShift Pod Security Standards Requirements

### PSS Restricted Profile

Для соответствия OpenShift PSS `restricted` профилью, Pod **ДОЛЖЕН** иметь:

| Требование | Статус | Шаблон |
|-----------|--------|--------|
| `runAsNonRoot: true` | ✅ | spark-base.podSecurityContext |
| `runAsUser` / `runAsGroup` (numeric) | ✅ | Значения из values.yaml |
| `fsGroup` (numeric) | ✅ | Значения из values.yaml |
| `seccompProfile.type: RuntimeDefault` | ✅ | spark-base.podSecurityContext |
| `allowPrivilegeEscalation: false` | ✅ | spark-base.containerSecurityContext |
| `capabilities.drop: ALL` | ✅ | spark-base.containerSecurityContext |
| Namespace labels (enforce=restricted) | ❌ | Нет namespace.yaml |

**Вердикт:** Pod security context корректен, но отсутствует namespace labeling.

---

## OpenShift SCC (Security Context Constraints)

### OpenShift SCC Requirements

OpenShift использует SCC вместо стандартного Kubernetes Pod Security Standards:

| SCC级别 | runAsUser | FSGroup | Capabilities |
|---------|-----------|---------|--------------|
| `restricted` | Must be range | Must be range | Drop ALL |
| `anyuid` | Any | Any | Drop ALL |
| `nonroot` | Non-root UID | Any | Drop ALL |

### Текущая конфигурация vs SCC

**Текущие значения:**
```yaml
security:
  runAsUser: 185    # Non-root ✅
  runAsGroup: 185   # ✅
  fsGroup: 185      # ✅
```

**Проблема:** UID 185 может не быть в разрешённом range для SCC `restricted`.

**OpenShift default UID ranges:**
- `restricted`: 1000000000-1000099999 (huge range)
- Но может быть настроен индивидуально для кластера

**Решение:** Для production OpenShift нужно:
1. Узнать разрешённый UID range в кластере
2. Настроить `runAsUser/runAsGroup/fsGroup` в этом range
3. Или использовать SCC `anyuid` (менее безопасно)

---

## Рекомендации

### Критические (должны быть исправлены)

1. **Добавить namespace.yaml template** в spark-3.5 и spark-4.1
   - Создать `templates/namespace.yaml` с PSS labels
   - Добавить `security.createNamespace: false` в values.yaml

2. **Включить podSecurityStandards по умолчанию**
   - Изменить `security.podSecurityStandards: false` на `true` в values.yaml
   - Или хотя бы добавить warning в документацию

3. **Документировать OpenShift UID ranges**
   - Добавить комментарий про необходимость настройки UID для конкретного кластера
   - Пример: `# For OpenShift: use cluster-specific UID range from `oc get namespace`)

### Важные (рекомендуются)

4. **Добавить OpenShift preset**
   - Создать `charts/spark-*/presets/openshift-values.yaml`
   - С правильными UID ranges и SCC настройками

5. **Добавить security validation test**
   - Проверять PSS compliance при деплое
   - Проверять SCC compatibility в OpenShift

6. **PostgreSQL relaxed mode**
   - Добавить `security.postgresql.relaxed: true` для embedded PostgreSQL
   - Или документировать необходимость внешнего PostgreSQL для strict PSS

### Желательные (улучшения)

7. **Network Policies**
   - Включить `security.networkPolicies.enabled: true` для production
   - Добавить правила для Spark-K8s communication

8. **OpenShift SCC integration**
   - Добавить documentation для настройки SCC
   - Создать скрипт для проверки SCC compatibility

---

## Action Items

### Phase 1: Critical (День 1)

- [ ] Создать `templates/namespace.yaml` в spark-3.5
- [ ] Создать `templates/namespace.yaml` в spark-4.1
- [ ] Обновить `values.yaml` с `security.createNamespace` опцией
- [ ] Изменить default `podSecurityStandards: false` на `true`

### Phase 2: Documentation (День 1-2)

- [ ] Добавить OpenShift UID ranges комментарий
- [ ] Создать `presets/openshift-values.yaml` для обеих версий
- [ ] Обновить README.md с OpenShift deployment instructions

### Phase 3: Testing (День 2)

- [ ] Создать security validation test
- [ ] Проверить PSS compliance на реальном кластере
- [ ] Проверить SCC compatibility на OpenShift

### Phase 4: Hardening (День 3+)

- [ ] Включить Network Policies по умолчанию для prod
- [ ] Добавить PostgreSQL relaxed mode
- [ ] Создать OpenShift deployment guide

---

## Сравнительная таблица

| Функция | spark-3.5-old | spark-3.5 / spark-4.1 | Статус |
|---------|---------------|----------------------|--------|
| PSS-compatible podSecurityContext | ✅ | ✅ | Ок |
| PSS-compatible containerSecurityContext | ✅ | ✅ | Ок |
| Namespace template с PSS labels | ✅ | ❌ | **Потеряно** |
| Default podSecurityStandards: true | ✅ | ❌ (false) | **Потеряно** |
| OpenShift UID documentation | ✅ | ❌ | **Потеряно** |
| PostgreSQL relaxed mode | ✅ | ❌ | **Потеряно** |
| Environment-specific overrides | ❌ | ✅ | Улучшено |
| Network Policies | ❌ | ❌ | Нет |
| OpenShift presets | ❌ | ❌ | Нет |

---

## Заключение

**Текущий статус:** ⚠️ Частично совместимо с OpenShift

**Критические проблемы:**
1. Отсутствует namespace labeling для PSS
2. Безопасность отключена по умолчанию

**Хорошая новость:**
- Pod security context корректен
- Есть environment overrides для prod/staging

**Необходимые действия:**
- Восстановить namespace.yaml template
- Включить podSecurityStandards по умолчанию
- Документировать OpenShift-specific требования

---

## Last updated

2026-02-01 14:00 - Initial analysis
