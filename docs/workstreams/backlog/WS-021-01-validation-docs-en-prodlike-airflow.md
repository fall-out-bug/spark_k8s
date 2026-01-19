## WS-021-01: Update validation docs (EN) for prod-like Airflow vars

### 🎯 Goal

**What should WORK after WS completion:**
- Operators understand how `test-prodlike-airflow.sh` now auto-sets Airflow Variables.
- Validation and chart guides explain how DAGs get Spark/S3 settings in prod-like runs.

**Acceptance Criteria:**
- [ ] `docs/guides/en/validation.md` documents auto variable setup and env overrides
- [ ] `docs/guides/en/validation.md` includes troubleshooting for scheduler restart after cluster outage
- [ ] `docs/guides/en/charts/spark-standalone.md` explains required Airflow Variables for DAGs
- [ ] Docs reference current script flags/envs without outdated names

**⚠️ WS is NOT complete until Goal is achieved (all AC checked).**

---

### Context

`scripts/test-prodlike-airflow.sh` now auto-populates Airflow Variables for DAGs based on namespace/release
and the `s3-credentials` secret. The docs must reflect this behavior to keep prod-like validation deterministic.

### Dependency

Independent

### Input Files

- `scripts/test-prodlike-airflow.sh` — source of new envs and behavior
- `docs/guides/en/validation.md` — validation runbook to update
- `docs/guides/en/charts/spark-standalone.md` — chart guide for Airflow DAG guidance

### Steps

1. Update validation runbook with:
   - auto variable setup behavior
   - environment overrides (SET/FORCE + SPARK/S3 values)
   - note about `s3-credentials` fallback
2. Add a short troubleshooting note for scheduler restart after cluster outage.
3. Update standalone chart guide with Airflow Variables required by DAGs.

### Code

```bash
# Example snippet for docs (prod-like Airflow vars)
export SET_AIRFLOW_VARIABLES=true
export FORCE_SET_VARIABLES=false
export SPARK_NAMESPACE_VALUE=spark-sa-prodlike
export SPARK_STANDALONE_MASTER_VALUE=spark://spark-prodlike-spark-standalone-master:7077
export S3_ENDPOINT_VALUE=http://minio:9000
```

### Expected Result

- EN validation runbook and chart guide match current test script behavior.
- Operators can run prod-like DAG tests without manual variable setup.

### Scope Estimate

- Files: ~0 created, ~2 modified
- Lines: ~80-140 (SMALL)
- Tokens: ~500-900

### Completion Criteria

```bash
rg "SET_AIRFLOW_VARIABLES|FORCE_SET_VARIABLES|spark_namespace" docs/guides/en/validation.md
rg "Airflow Variables|spark_standalone_master|s3_endpoint" docs/guides/en/charts/spark-standalone.md
```

### Constraints

- DO NOT change test scripts in this WS
- Keep language concise and operator-focused

---

### Execution Report

**Executed by:** Auto (agent)  
**Date:** 2026-01-19

#### 🎯 Goal Status

- [x] AC1: `docs/guides/en/validation.md` documents auto variable setup and env overrides — ✅
- [x] AC2: `docs/guides/en/validation.md` includes troubleshooting for scheduler restart after cluster outage — ✅
- [x] AC3: `docs/guides/en/charts/spark-standalone.md` explains required Airflow Variables for DAGs — ✅
- [x] AC4: Docs reference current script flags/envs without outdated names — ✅

**Goal Achieved:** ✅ YES

#### Modified Files

| File | Action | LOC |
|------|--------|-----|
| `docs/guides/en/validation.md` | modified | +47 |
| `docs/guides/en/charts/spark-standalone.md` | modified | +33 |

**Total:** 2 files modified, ~80 LOC added

#### Completed Steps

- [x] Step 1: Updated validation runbook with auto variable setup behavior, environment overrides, and `s3-credentials` fallback
- [x] Step 2: Added troubleshooting note for scheduler restart after cluster outage
- [x] Step 3: Updated standalone chart guide with Airflow Variables explanation and troubleshooting

#### Self-Check Results

```bash
$ grep -E "SET_AIRFLOW_VARIABLES|FORCE_SET_VARIABLES|spark_namespace" docs/guides/en/validation.md
- `SET_AIRFLOW_VARIABLES` — Auto-populate Airflow Variables (default: `true`)
- `FORCE_SET_VARIABLES` — Overwrite existing variables (default: `false`)
3. Airflow Variables are auto-populated (if `SET_AIRFLOW_VARIABLES=true`)
The script automatically sets Airflow Variables required by DAGs (`spark_image`, `spark_namespace`, `spark_standalone_master`, `s3_endpoint`, `s3_access_key`, `s3_secret_key`) based on:

$ grep -E "Airflow Variables|spark_standalone_master|s3_endpoint" docs/guides/en/charts/spark-standalone.md
**Airflow Variables:**
- `spark_standalone_master` — Spark Master URL (default: `spark://<release>-spark-standalone-master:7077`)
- `s3_endpoint` — S3 endpoint URL (default: `http://minio:9000`)
  airflow variables set spark_standalone_master spark://<release>-spark-standalone-master:7077
  airflow variables set s3_endpoint http://minio:9000

$ wc -l docs/guides/en/validation.md docs/guides/en/charts/spark-standalone.md
  247 docs/guides/en/validation.md
  225 docs/guides/en/charts/spark-standalone.md
```

#### Issues

None

### Review Result

**Status:** READY
