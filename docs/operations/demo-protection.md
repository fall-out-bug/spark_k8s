# Demo Protection — Regression Prevention

> **Principle:** Critical paths (demo, deploy, smoke) must not regress. Use guards, tests, and canonical scripts. If a change can break them, add a check before merging.

The demo (`spark-infra`, `observability`) has been destroyed 3+ times by agent work. These rules implement regression prevention.

---

## READ FIRST — Before ANY helm/kubectl touching spark-infra or observability

1. Read this document
2. Run `./scripts/check-demo-health.sh` — if it fails, run `./scripts/restore-demo.sh` first
3. For config changes: read `charts/spark-3.5/presets/demo-full-spark-infra.yaml` — **sole source of truth**
4. Never run raw `helm` or `kubectl` for demo — use only canonical scripts

---

## Invariants (must always hold)

- `spark-infra` has exactly ONE Helm release named `spark-infra`, chart `spark-3.5` (parent, NOT subchart)
- Service names: `spark-infra-standalone-*` (master), `spark-infra-airflow-webserver`, `spark-infra-spark-35-*` (history, jupyter, metastore), `spark-infra-spark-base-*` (postgresql), `minio` — never `spark-shared-*`
- Preset `presets/demo-full-spark-infra.yaml` is the sole config source; `values.yaml` are fallback defaults only
- Workers: ≥3 replicas, ≥800m CPU, ≥13Gi memory, ≥2 cores, ≥14g Spark memory
- Resource budget: ~5 CPU / ~44Gi of 6 CPU / 48Gi node (enforced by `test_demo_preset_guard.py`)

---

## NEVER do these

**Helm/Kubectl:**
- `helm install/upgrade` in `spark-infra` — use `scripts/deploy-demo-minikube.sh` or `scripts/restore-demo.sh`
- `helm install spark-shared -n spark-infra` — conflicting release
- `helm install spark-infra` with wrong chart — chart swap, kills History/Metastore/Jupyter
- `helm uninstall spark-infra -n spark-infra` — use `restore-demo.sh`
- `kubectl delete namespace spark-infra` or `kubectl delete namespace observability`
- `kubectl delete pvc` in `spark-infra` — breaks PostgreSQL auth, Airflow state
- `kubectl scale --replicas=0` in `spark-infra` without immediately restoring
- `kubectl apply` raw manifests into `spark-infra` bypassing Helm

**Configuration:**
- Editing `charts/*/values.yaml` to change demo config — edit only `presets/demo-full-spark-infra.yaml`
- Adding `--set standalone.worker.resources.*` or `--set standalone.worker.replicas` — preset defines these
- Renaming the release from `spark-infra` — port-forwards, exporters, DAGs all reference it
- Hardcoding service names with `spark-shared-*` or any non-`spark-infra-` prefix
- Manually configuring Grafana datasources via API — not persistent; use `deploy-observability.sh`
- Increasing `MAX_TEST_NAMESPACES` in `run-matrix.sh` without verifying cluster capacity

---

## ALWAYS do these

- Run `./scripts/check-demo-health.sh` **before and after** any change to `spark-infra` or `observability`
- For config changes: edit `presets/demo-full-spark-infra.yaml`, deploy via canonical script
- Test scenarios in `test-scenario-*` / `test-*` namespaces, NEVER in `spark-infra`
- If demo broken: `./scripts/restore-demo.sh` — do NOT retry failed operation
- After restore/re-deploy: kill stale port-forwards, restart `./tests/observability/start-ui-portforwards.sh`
- When adding files referencing demo services: use `spark-infra` as release name

---

## Canonical scripts (use these, never invent alternatives)

| Script | Purpose |
|--------|---------|
| `scripts/deploy-demo-minikube.sh` | Fresh demo deploy |
| `scripts/restore-demo.sh` | Recover from any failure (<5 min) |
| `scripts/check-demo-health.sh` | Verify demo health (exit 0 = OK) |
| `scripts/tests/minikube/deploy-observability.sh` | Observability + Grafana datasources |
| `tests/observability/start-ui-portforwards.sh` | Port-forwards for Windows access |
| `scripts/lib/helm-safe.sh` | Helm wrapper blocking dangerous ops |

---

## Pre-flight (BEFORE any change)

```bash
./scripts/check-demo-health.sh   # exit 0 required; if fails → restore-demo.sh first
```

- Target namespace: `spark-infra` or `observability` — never mix
- spark-infra chart: `charts/spark-3.5` (parent), NOT subchart
- spark-infra values: MUST use `-f charts/spark-3.5/presets/demo-full-spark-infra.yaml`
- observability: use `./scripts/tests/minikube/deploy-observability.sh`

---

## Post-flight (AFTER any change)

```bash
./scripts/check-demo-health.sh   # run within 2 min of any deploy
```

If failed: do NOT retry — run `./scripts/restore-demo.sh`. If restore fails, hand off to human.

After restore/re-deploy: `pkill -f "kubectl port-forward.*spark-infra"` then `./tests/observability/start-ui-portforwards.sh`

---

## Rollback: symptom → action

| Symptom | Action |
|---------|--------|
| Helm stuck (pending-install/upgrade, uninstalling) | `./scripts/restore-demo.sh` |
| Wrong chart on release | `./scripts/restore-demo.sh` |
| Two releases in spark-infra | `helm uninstall <wrong-release> -n spark-infra` then `./scripts/restore-demo.sh` |
| Pods OOMKilled / Evicted | Clean test namespaces, then `./scripts/restore-demo.sh` |
| PostgreSQL auth failure | **Do NOT delete PVCs.** Reset password: `kubectl exec spark-infra-spark-base-postgresql-0 -c postgresql -- psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'postgres';"` then restart dependent pods |
| Metastore CrashLoopBackOff | Fix PostgreSQL first (above), ensure `metastore_db` exists, `kubectl delete pod` metastore |
| Grafana datasources missing | `./scripts/tests/minikube/deploy-observability.sh` |
| Port-forwards dead | `pkill -f port-forward` then `./tests/observability/start-ui-portforwards.sh` |

**Never:** `helm uninstall spark-infra -n spark-infra` — use restore-demo.sh.

---

## Resource budget (6 CPU / 48Gi minikube)

| Component | CPU req | Memory req |
|-----------|---------|------------|
| System (kube-system, etc.) | ~850m | ~300Mi |
| Observability | ~250m | ~544Mi |
| spark-infra infra | ~1550m | ~4.5Gi |
| 3 workers × 800m/13Gi | 2400m | 39Gi |
| **Total** | ~5050m (84%) | ~44Gi (92%) |

**Observability tuning for demo:** Loki `chunksCache.allocatedMemory: 256` (default 8192MB exceeds budget), `resultsCache.allocatedMemory: 128`, `gateway.affinity: null` (single-node: disable podAntiAffinity).

- Test namespaces: keep orphan count ≤ 1; each consumes ~500m CPU
- Never scale workers >3 or increase memory >13Gi without capacity check
- Before matrix: `kubectl get ns -o name | grep -c test-scenario` — must be ≤ 1

---

## Observability protection

- **Grafana datasources:** only via `deploy-observability.sh`; API/UI edits lost on restart
- **Prometheus targets:** demo-metrics-exporter expects `spark-infra-*` services
- **Port-forwards:** restart `start-ui-portforwards.sh` after every re-deploy

---

## Root causes (9 documented incidents)

1. Wrong chart installed as `spark-infra` instead of parent chart (`spark-3.5`) — killed History/Metastore/PostgreSQL/Jupyter
2. Two releases (`spark-infra` + `spark-shared`) in same namespace — Helm ownership deadlock
3. Too many test namespaces — memory exhaustion, demo pods evicted
4. Config drift: agent edited `values.yaml` instead of preset → 200m/1Gi workers
5. PVC deleted → PostgreSQL password mismatch on restart
6. Port-forwards pointed to `spark-shared-*` (old release name) after re-deploy
7. Grafana datasources configured via API, lost on pod restart
8. demo-metrics-exporter hardcoded `spark-shared-*` → metrics failed
9. Agent renamed release → cascading failures in DAGs, exporters, port-forwards

---

## Session handoff

```bash
./scripts/check-demo-health.sh          # MUST exit 0
kubectl get ns | grep test-scenario      # orphans ≤ 1
helm list -n spark-infra                 # 1 release, status=deployed
git status && git push                   # committed + pushed
```

If `restore-demo.sh` was run during session, note it in handoff.
