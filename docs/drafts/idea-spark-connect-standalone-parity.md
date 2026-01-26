# Idea: Spark Connect parity with Standalone backend (modular constructor)

**Created:** 2026-01-19  
**Status:** Draft  
**Author:** user + GPT-5.2 (agent)

---

## 1. Problem Statement

### Current State

This repo provides multiple Spark deployment modes via Helm charts (Spark Standalone, Spark Connect, Spark 3.5 and Spark 4.1).
Spark Connect is primarily treated as a separate deployment mode (Connect server + Kubernetes-native executors).

### Problem

For “full modularity”, Spark Connect must be able to run in **two operational modes**:

1. **Connect-only (Kubernetes mode)**: Spark Connect server runs and executes jobs by launching Kubernetes executors (no Standalone cluster required).
2. **Connect + Standalone backend**: Spark Connect server runs in Kubernetes but uses an existing **Spark Standalone master/workers** as the execution backend (Connect submits to `spark://...:7077`; workers are Standalone workers).

This parity is required for both Spark versions supported in the repo:
- Spark **3.5.x** (LTS)
- Spark **4.1.x** (latest)

### Impact

- Operators want a single “constructor” to compose Spark parts without duplicating charts and guides.
- Migration path becomes simpler: teams can keep Standalone pipelines while adopting Spark Connect UX.
- Reduces fragmentation: one set of docs/tests/values patterns across both modes.

---

## 2. Proposed Solution

### Description

Introduce a **modular Spark Connect configuration** that supports selecting the backend mode:

- **Mode A (K8s executors):** `spark.master=k8s://...` + executor pod templates
- **Mode B (Standalone backend):** `spark.master=spark://<standalone-master-svc>:7077` + Standalone workers

This must be configurable via Helm values and work for both Spark 3.5 and Spark 4.1 Connect charts.

### Key Capabilities

1. **Two backend modes** for Spark Connect (K8s executors vs Standalone backend)
2. **Version parity**: Spark 3.5 and Spark 4.1 both support both modes
3. **Composable deployment**:
   - Deploy Connect alone
   - Deploy Standalone alone
   - Deploy Connect “next to” Standalone in the same namespace and point to its master service
4. **OpenShift/PSS compatibility** preserved (PSS `restricted` / SCC-like constraints)
5. **Full-load validation**: runtime tests cover the two modes under load, not only smoke

---

## 3. User Stories

### Primary User: Data/DevOps (operator)

- As an operator, I want to deploy Spark Connect in Kubernetes-native mode so that DE/DS can run jobs without Standalone.
- As an operator, I want to deploy Spark Connect next to an existing Standalone cluster so that Connect submits to Standalone workers.
- As an operator, I want both Spark 3.5 and Spark 4.1 to behave the same way so that upgrades do not change deployment patterns.

### Secondary Users: DE + DS (Spark users)

- As a DE/DS, I want to use Spark Connect regardless of the backend mode so that my workflow stays stable while infra evolves.

---

## 4. Scope

### In Scope

- Helm values / templates / docs enabling Spark Connect backend selection:
  - Connect-only (K8s executors)
  - Connect+Standalone backend (submit to Standalone master)
- Support for both Spark 3.5 and Spark 4.1 Connect charts.
- Compatibility with existing repository capabilities already implemented:
  - PSS/OpenShift-like hardening patterns
  - S3/MinIO integration patterns used by the repo
  - Existing smoke/E2E scripts approach (Minikube validated)
- Runtime validation under **full load** for both modes (see Success Criteria / Testing).

### Out of Scope

- Multi-tenancy / cross-namespace submission (assume same namespace connectivity)
- Data migration (metastore buckets, schema migration, etc.)
- New “from scratch” images outside the established build strategy
- Spark Operator adoption (unless already part of existing capabilities for the chosen chart)

### Future Considerations

- Cross-namespace Connect → Standalone submission (network policies, DNS, RBAC)
- Optional integration with Spark Operator as another backend mode (separate idea)

---

## 5. Success Criteria

### Acceptance Criteria

- [ ] Spark Connect **3.5** supports both:
  - [ ] Connect-only (K8s executors)
  - [ ] Connect + Standalone backend (`spark://...:7077`)
- [ ] Spark Connect **4.1** supports both:
  - [ ] Connect-only (K8s executors)
  - [ ] Connect + Standalone backend (`spark://...:7077`)
- [ ] Both modes remain compatible with **PSS `restricted`** expectations (OpenShift-like)
- [ ] Helm render sanity:
  - [ ] `helm lint` passes for affected charts
  - [ ] `helm template` for both modes and both versions renders successfully
- [ ] Runtime tests in Minikube cover **full-load** (not only SparkPi):
  - [ ] Mode A (K8s executors) load scenario passes
  - [ ] Mode B (Standalone backend) load scenario passes
  - [ ] E2E scripts produce clear “green” criteria and are referenced in docs

### Metrics (if applicable)

- Load scenario definition: number of concurrent jobs / data volume / job duration (to be defined during `/design`).
- Stability: no systematic failures across N iterations of the load run.

---

## 6. Dependencies & Risks

### Dependencies

| Dependency | Type | Status |
|------------|------|--------|
| Existing Spark Standalone chart (3.5) | Hard | Ready |
| Existing Spark Connect charts (3.5 and 4.1) | Hard | Ready |
| PSS/OpenShift-compatible security patterns | Hard | Ready |
| MinIO/S3 credentials and endpoints used by tests | Soft | Ready |

### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Connect→Standalone backend needs Spark config differences vs K8s executors | Medium | High | Explicit `backendMode` values + separate config blocks |
| PSS restrictions break write paths/config generation | Medium | High | Reuse writable `emptyDir` patterns already applied in charts |
| “Full load” tests are flaky in Minikube due to resource constraints | Medium | Medium | Provide tunable limits/replicas; document minikube resource requirements |

---

## 7. Open Questions

- [ ] How should the user select backend mode in values? (`backendMode: k8s|standalone` vs `spark.master` direct override)
- [ ] Should we support deploying Connect and Standalone in one umbrella chart release, or only “separate releases in same namespace”?
- [ ] What is the minimal “full load” definition that is stable in Minikube but still meaningful?

---

## 8. Notes

- Assumption confirmed by user: Connect+Standalone operates **within the same namespace**, and Connect submits to Standalone workers.
- Must preserve OpenShift-like constraints as a primary requirement.

---

## Next Steps

1. **Review draft** — refine open questions
2. **Run `/design idea-spark-connect-standalone-parity`** — create workstreams
