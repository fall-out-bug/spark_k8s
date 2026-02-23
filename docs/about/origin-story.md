# Why spark_k8s?

> **Vision:** Production-ready, not production-hostile.

## The Problem: Two Worlds That Don't Speak

DevOps teams understand Kubernetes. They know pods, services, ingress, RBAC. Data engineers understand Spark. They know RDDs, DataFrames, executors, shuffle. But when you put Spark on Kubernetes, something breaks: **the communication gap**.

Platform teams provision clusters. Data teams write jobs. Neither fully understands the other's constraints. The result: deployments that work on a laptop fail in production. Configurations that pass `helm install` cause OOMKills at 3 AM. Every incident becomes a fire drill because there's no shared vocabulary.

**The cost is real:** weeks of back-and-forth tickets, environment drift between dev and prod, and teams that learn to work around the platform instead of with it.

## Problem Deep Dive: When the Gap Bites

Consider a typical scenario. A data engineer needs to test a pipeline change. They request a Spark environment from the platform team. Ticket submitted. Two days later, a cluster appears — but it's configured for a different use case. Memory limits don't match the job. The S3 bucket isn't mounted. The engineer spends a day debugging infrastructure instead of data logic.

**Quantified pain:**
- **Time:** 2–5 days from request to usable environment. Iteration cycles stretch to weeks.
- **Money:** Platform engineer hours, data engineer hours, both waiting. Opportunity cost of delayed insights.
- **Frustration:** "Why can't I just run it myself?" — a sentiment we've heard repeatedly.

**Real-world pattern:** Data teams resort to "shadow IT" — running Spark on their laptops or in ungoverned cloud accounts — because the official path is too slow. The platform team then inherits support for configurations they never designed.

## The Solution: Lego-Constructor Approach

spark_k8s takes a different path. Instead of a monolithic "here's your cluster" deployment, we provide **preset-based building blocks** that encode best practices.

**Lego-like modularity:** Teams combine components themselves. Need Jupyter + Spark Connect? Pick the preset. Need Airflow + MLflow? Pick another. Need OpenShift with PSS restricted? We have that. Each preset is tested, documented, and production-ready.

**Why presets matter:** They bridge the gap. A data engineer can deploy a known-good configuration in minutes. A DevOps engineer sees a standard, auditable setup. No custom YAML archaeology. No "it worked on my machine" — because the machine is defined by the preset.

**Balance:** Flexibility where it matters (resource sizing, feature flags), guardrails where it doesn't (security defaults, observability). You get self-service without chaos.

## Vision and Future Roadmap

**Beyond Helm charts:** spark_k8s aims to be a **Production Operations Framework**. Not just "how to deploy" but "how to operate." Day-2 operations: runbooks, incident response, backup/DR, SLI/SLO monitoring. See [ROADMAP.md](../../ROADMAP.md) for current progress.

**Community-driven:** Open source, bilingual (EN/RU) documentation, and a commitment to production-grade defaults. We evolve with community feedback — presets expand, runbooks grow, and the platform matures.

**Sustainability:** Maintained as a demonstration of expertise in production data platforms. Contributions welcome. The roadmap is transparent; the code is open.

---

**Summary:** spark_k8s exists because the DevOps/Data gap is real and costly. We solve it with preset-based deployment, modularity, and a focus on production operations. The result: fewer tickets, faster iteration, and teams that can focus on insights instead of infrastructure.
