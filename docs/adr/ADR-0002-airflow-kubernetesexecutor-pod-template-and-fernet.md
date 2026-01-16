## ADR-0002: Airflow KubernetesExecutor uses a shared pod template and fixed Fernet key

### Status

Accepted

### Context

For “prod-like” testing we run Airflow with:

- `KubernetesExecutor` (task execution as pods)
- `KubernetesPodOperator` (spawns additional pods for Spark jobs)
- Pod Security Standards hardening (non-root, read-only rootfs)

We hit these issues:

- Airflow attempted to write `/opt/airflow/airflow.cfg` under `readOnlyRootFilesystem=true`.
- DAGs mounted from ConfigMap are symlinks (`..data/…`); Airflow can detect recursive loops while walking the DAG directory.
- KubernetesExecutor worker pods must run the **Airflow image**; using the Spark image breaks (`airflow …` command missing).
- Airflow Variables are encrypted; without a shared `FERNET_KEY`, different pods cannot decrypt values, causing fallbacks to defaults and unexpected namespaces.

### Decision

- Provide a **pod template** for KubernetesExecutor worker pods:
  - sets `serviceAccountName`
  - applies security contexts for PSS
  - mounts writable `emptyDir` for `/opt/airflow`, `/tmp`, `/opt/airflow/logs`
  - syncs DAGs into a real directory (`cp -LR`) via initContainer
- Configure a **fixed Fernet key**:
  - injected via Secret as `AIRFLOW__CORE__FERNET_KEY`
  - used by scheduler, webserver, and worker pods

### Consequences

- **Pros**
  - Airflow runs under PSS-hardening without filesystem write errors.
  - DAG discovery is stable (no ConfigMap symlink loop).
  - Variables behave consistently across scheduler/webserver/worker pods.
  - KubernetesExecutor pods use correct image and permissions.
- **Cons**
  - Requires managing a Fernet key (Secret) for each environment.

