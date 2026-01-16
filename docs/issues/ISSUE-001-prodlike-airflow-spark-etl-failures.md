## ISSUE-001: Prod-like Airflow DAG failures (KubernetesExecutor + Spark Standalone)

### Symptoms

- Airflow scheduler/webserver crash under PSS due to writes to `/opt/airflow/airflow.cfg`.
- DAG discovery errors: “Detected recursive loop when walking DAG directory …”.
- KubernetesExecutor worker pods started with the wrong image (`spark-custom`) and failed running `airflow …`.
- `spark_etl_synthetic` failed:
  - Variables could not decrypt → fell back to default namespace
  - KubernetesPodOperator hit RBAC 403 in `default`
  - Spark job requested 4Gi executors (image defaults) while workers had 2Gi → app stuck WAITING

### Root Causes

- Missing shared `AIRFLOW__CORE__FERNET_KEY` across pods.
- DAGs mounted from ConfigMap are symlinks; Airflow can treat them as loops.
- KubernetesExecutor worker image must be Airflow image.
- Spark image `spark-defaults.conf` sets large `spark.executor.memory=4g`; DAG must override for small local clusters.

### Fix / Mitigation

- Add Airflow pod template and DAG sync initContainer (`cp -LR`) to avoid symlink loop.
- Inject fixed Fernet key via Secret to all Airflow pods.
- Ensure KubernetesExecutor worker image is Airflow image and uses the shared pod template.
- In `spark_etl_synthetic` use explicit `spark-submit --conf` for:
  - `spark.driver.host/bindAddress`
  - S3A credentials/endpoint
  - executor sizing compatible with worker capacity

### Verification

- In `spark-sa-prodlike` namespace:
  - `spark_etl_synthetic` DAG run reaches `success`

