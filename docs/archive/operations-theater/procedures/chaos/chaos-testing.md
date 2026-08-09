# Chaos Testing for Spark on Kubernetes

## Overview

This procedure defines chaos testing practices for Spark on Kubernetes.

## Chaos Experiments

### Experiment 1: Pod Kill

**Purpose**: Test Spark's resilience to pod failures

**Severity**: Low

**Expected Behavior**:
- Spark retries tasks on other executors
- Job completes successfully

---

### Experiment 2: Network Latency

**Purpose**: Test Spark's resilience to network issues

**Severity**: Low

**Expected Behavior**:
- Jobs complete with increased latency
- No job failures

---

### Experiment 3: Disk Fill

**Purpose**: Test Spark's resilience to disk space issues

**Severity**: Medium

**Expected Behavior**:
- Increased spill to disk
- Slower job performance

---

### Experiment 4: Shuffle Service Failure

**Purpose**: Test Spark's resilience to shuffle failures

**Severity**: Medium

**Expected Behavior**:
- Job may fail or retry
- Recovery after restart

---

### Experiment 5: Memory Pressure

**Purpose**: Test Spark's resilience to memory constraints

**Severity**: Low

**Expected Behavior**:
- Some executors OOM killed
- Spark dynamic allocation handles this

## Chaos Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| Job Success Rate | Jobs that complete successfully | > 95% |
| Job Duration | Average job completion time | < 2x baseline |
| Recovery Time | Time to restore after chaos | < 5 min |

## Related Procedures

- [Runbook Testing](../procedures/runbook-testing.md)

## References

- [Chaos Mesh Documentation](https://chaos-mesh.org/docs/)
