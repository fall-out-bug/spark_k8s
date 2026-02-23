# PRODUCT_VISION.md

> **Last Updated:** 2026-02-02
> **Version:** 1.0

## Mission

Lego-constructor for rapid assembly of production-ready Apache Spark infrastructure on Kubernetes/OpenShift with preset configurations for typical data scenarios and documentation that helps DevOps engineers understand Data team requirements.

## Problem Context

**Communication Gap:** DevOps engineers often don't understand which Spark deployment approach they need (k8s vs standalone vs operator), which Spark versions to use (3.5 vs 4.1), what features and drawbacks exist in each branch. Data Engineers/Scientists cannot clearly explain technical requirements.

**Technical Complexity:** DevOps don't know which components are mandatory vs optional, which ports to configure, how to tune memory/cores, how to connect storage. No clear examples for typical scenarios.

**OpenShift Pain:** Standard Helm charts don't work due to PSS/SCC restrictions.

## Users

1. **DevOps Engineer** — Tasked with "deploying Spark", doesn't know how, looking for a ready-to-use solution with clear documentation

2. **Data Engineer / Lead** — Understands Data team requirements, looking for a way to explain them to DevOps and quickly deploy dev/prod environments

3. **Tech Lead / Architect** — Choosing stack for entire organization, needs flexible and understandable tool with support for different scenarios

4. **Platform Engineer** — Building Internal Developer Platform, wants to give Data teams self-service to Spark infrastructure

5. **Data Scientist / Analyst** — Wants pandas-like experience (Spark Connect) without diving into Kubernetes details

## Success Metrics

- [ ] **Time to First Spark** — `< 5 minutes` from `git clone` to working Spark Connect with Jupyter
- [ ] **Documentation Coverage** — 100% of typical scenarios covered by preset files and examples
- [ ] **Support Reduction** — 80% reduction in questions/incidents after deployment (measured via issue tracker)
- [ ] **OpenShift Compatibility** — All validated scenarios work on OpenShift (Minikube validated, OpenShift prepared)

## Strategic Tradeoffs

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Chart Architecture** | Experiment: Spark 3.5 — modular charts, Spark 4.1 — unified | Analyzing which approach is more convenient for DevOps |
| **Backend Modes** | Support three modes: k8s, standalone, operator | Different requirements: Connect for DS/DA (pandas-like), k8s for power users, standalone for conservative approaches without deep K8s knowledge |
| **Configuration Approach** | Presets for quick start + good documentation | Presets accelerate first spark, documentation eliminates "click-click" approach |
| **Multi-version Support** | Support Spark 3.5 (LTS) and 4.x (latest) | 3.5 is stable LTS, 4.x has new features but not always stable |
| **OpenShift Compatibility** | PSS `restricted` / SCC `restricted` out of the box | Pain point for many DevOps when trying to deploy standard charts |

## Core Components (Project Constants)

These components are mandatory for any build and testing:

- **Hive Metastore** — Table metadata storage for SQL queries and ACID transactions
- **Minio (or S3-compatible storage)** — Raw dataset storage for tests, event logs for Spark History Server
- **Spark History Server** — Job history collection for testing and monitoring (proper K8s setup is a pain point we solve)

## Non-Goals (What project does NOT do)

- **K8s Cluster Management** — Does not create namespaces, configure storage classes, manage cluster resources (helper scripts provided for local Minikube testing)

- **Spark Education** — Does not teach how to write Spark jobs, tune queries, optimize code (future work)

- **Managed Service** — Operations required: patching, updates, monitoring — user responsibility

- **All Integrations** — Only typical scenarios supported (Airflow, MLflow, MinIO), custom integrations — user responsibility

## Optional Components

Available on demand for specific scenarios:

- **Jupyter** — Interactive notebooks with remote Spark Connect
- **Airflow** — Pipeline orchestration
- **MLflow** — ML experiment tracking
- **Celeborn** — Disaggregated shuffle service (optional)
- **Prometheus/Grafana** — Monitoring and alerting (optional)

## Project Positioning

**"Lego for DataOps/DevOps"** — Modular constructor that:
- Allows building environments for DE/DS/DA with minimal effort
- Helps DevOps understand Spark stack without deep dives
- Provides ready-to-use patterns for typical scenarios
- Solves OpenShift compatibility pain out of the box
