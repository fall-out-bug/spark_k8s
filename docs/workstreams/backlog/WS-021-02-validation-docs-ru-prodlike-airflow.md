## WS-021-02: Update validation docs (RU) for prod-like Airflow vars

### 🎯 Goal

**What should WORK after WS completion:**
- RU validation and chart guides mirror EN updates for prod-like Airflow Variables.
- RU docs explain the same env overrides and failure modes.

**Acceptance Criteria:**
- [ ] `docs/guides/ru/validation.md` documents auto variable setup and env overrides
- [ ] `docs/guides/ru/validation.md` includes scheduler restart troubleshooting
- [ ] `docs/guides/ru/charts/spark-standalone.md` explains Airflow Variables for DAGs
- [ ] RU wording matches EN meaning (no missing options)

**⚠️ WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

RU operator documentation must be consistent with EN after changes to
`scripts/test-prodlike-airflow.sh`.

### Dependency

WS-021-01

### Input Files

- `docs/guides/en/validation.md` — reference for updates
- `docs/guides/en/charts/spark-standalone.md` — reference for updates
- `docs/guides/ru/validation.md` — to update
- `docs/guides/ru/charts/spark-standalone.md` — to update

### Steps

1. Translate EN updates into RU validation runbook.
2. Align RU chart guide with EN notes about Airflow Variables.
3. Ensure examples and env names are identical to EN.

### Code

```bash
# Example snippet for RU docs (same envs as EN)
export SET_AIRFLOW_VARIABLES=true
export FORCE_SET_VARIABLES=false
export SPARK_NAMESPACE_VALUE=spark-sa-prodlike
export SPARK_MASTER_VALUE=spark://spark-prodlike-spark-standalone-master:7077
export S3_ENDPOINT_VALUE=http://minio:9000
```

### Expected Result

- RU validation runbook and chart guide match EN behavior.
- RU readers can run prod-like DAG tests without manual variable setup.

### Scope Estimate

- Files: ~0 created, ~2 modified
- Lines: ~80-140 (SMALL)
- Tokens: ~500-900

### Completion Criteria

```bash
rg "SET_AIRFLOW_VARIABLES|FORCE_SET_VARIABLES|spark_namespace" docs/guides/ru/validation.md
rg "Airflow Variables|SPARK_MASTER_VALUE|s3_endpoint" docs/guides/ru/charts/spark-standalone.md
```

### Constraints

- DO NOT change test scripts in this WS
- Keep RU text concise and aligned with EN meaning

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-19

#### 🎯 Goal Status

- [x] AC1: `docs/guides/ru/validation.md` documents auto variable setup and env overrides — ✅
- [x] AC2: `docs/guides/ru/validation.md` includes scheduler restart troubleshooting — ✅
- [x] AC3: `docs/guides/ru/charts/spark-standalone.md` explains Airflow Variables for DAGs — ✅
- [x] AC4: RU wording matches EN meaning (no missing options) — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `docs/guides/ru/validation.md` | modified | +48 |
| `docs/guides/ru/charts/spark-standalone.md` | modified | +34 |

**Total:** 2 files modified, ~82 LOC added

#### Completed Steps

- [x] Step 1: Translated EN updates into RU validation runbook (auto variable setup, env overrides, scheduler restart troubleshooting)
- [x] Step 2: Aligned RU chart guide with EN notes about Airflow Variables (explanation and troubleshooting)
- [x] Step 3: Ensured examples and env names are identical to EN

#### Self-Check Results

```bash
$ grep -E "SET_AIRFLOW_VARIABLES|FORCE_SET_VARIABLES|spark_namespace" docs/guides/ru/validation.md
- `SET_AIRFLOW_VARIABLES` — Автоматически заполнять Airflow Variables (по умолчанию: `true`)
- `FORCE_SET_VARIABLES` — Перезаписывать существующие переменные (по умолчанию: `false`)
3. Airflow Variables автоматически заполняются (если `SET_AIRFLOW_VARIABLES=true`)
Скрипт автоматически устанавливает Airflow Variables, требуемые DAG (`spark_image`, `spark_namespace`, `spark_standalone_master`, `s3_endpoint`, `s3_access_key`, `s3_secret_key`), на основе:

$ grep -E "Airflow Variables|SPARK_MASTER_VALUE|s3_endpoint" docs/guides/ru/charts/spark-standalone.md
**Airflow Variables:**
- `spark_standalone_master` — URL Spark Master (по умолчанию: `spark://<release>-spark-standalone-master:7077`)
- `s3_endpoint` — URL S3 endpoint (по умолчанию: `http://minio:9000`)
  airflow variables set spark_standalone_master spark://<release>-spark-standalone-master:7077
  airflow variables set s3_endpoint http://minio:9000

$ wc -l docs/guides/ru/validation.md docs/guides/ru/charts/spark-standalone.md
  248 docs/guides/ru/validation.md
  227 docs/guides/ru/charts/spark-standalone.md
```

#### Issues

None

### Review Result

**Status:** READY
