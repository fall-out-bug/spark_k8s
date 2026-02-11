# Incident Scenarios for On-Call Training

## Overview

This document provides incident scenarios for on-call training.

## Scenarios

### Scenario 1: Driver Pod Crash Loop

**Severity**: P1

**Description**:
A Spark batch job that processes nightly ETL is failing. The driver pod is in crash loop backoff. This job must complete before the morning business reports run at 6 AM. Current time: 3 AM.

**Runbook**: [Driver Crash Loop](../runbooks/spark/driver-crash-loop.md)

---

### Scenario 2: Executor OOM Kills

**Severity**: P2

**Description**:
Users report slow Spark job performance. Investigation shows executor pods are being OOMKilled and restarted. Jobs are completing but taking 3x longer than usual.

**Runbook**: [OOM Kill Mitigation](../runbooks/spark/oom-kill-mitigation.md)

---

### Scenario 3: Hive Metastore Connection Failure

**Severity**: P0

**Description**:
All Spark jobs are failing with "Unable to connect to Hive Metastore". No jobs can read or write data. Complete service outage.

**Runbook**: [Data Layer Recovery](../runbooks/data/hive-metastore-restore.md)

---

### Scenario 4: Spark Connect Authentication Failure

**Severity**: P2

**Description**:
Users cannot connect to Spark Connect. Error: "Authentication failed". Interactive notebooks are unable to start Spark sessions.

**Runbook**: [Connect Issues](../runbooks/spark/connect-issues.md)

---

### Scenario 5: High Load on Control Plane

**Severity**: P2

**Description**:
Kubernetes API server is slow. Spark jobs are taking a long time to start. Cluster is unresponsive to kubectl commands.

**Runbook**: [Cluster Scaling](../runbooks/scaling/cluster-scaling.md)

---

## Practice Instructions

1. Set up training environment (staging cluster)
2. Start the scenario: Read the description
3. Resolve the incident: Follow the runbook
4. Document your resolution
5. Review with team

---

**Document Version**: 1.0
**Last Updated**: 2026-02-11
