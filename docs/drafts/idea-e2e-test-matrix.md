## Idea: E2E test matrix execution

### Goal
Run the full E2E test matrix for Spark 3.5 and 4.1 across Jupyter and Airflow scenarios, with per-scenario isolation and repeatable scripts that capture logs, metrics, and final results.

### Scenarios
- Jupyter + Spark Connect + K8s workers (3.5, 4.1)
- Jupyter + Spark Connect + Standalone workers (3.5, 4.1)
- Airflow + Spark Connect + K8s workers (3.5, 4.1)
- Airflow + Spark Connect + Standalone workers (3.5, 4.1)
- Airflow + Spark K8s submit (3.5, 4.1)
- Airflow + Spark Operator (3.5, 4.1)

### Constraints
- Minikube as the primary test cluster.
- Each scenario should be runnable independently.
- Each run must verify: logs, metrics endpoint, and result output.

