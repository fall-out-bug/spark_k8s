# F25: LOC Exemptions Documentation

## Overview

This document records scripts that exceed 200 LOC but are justified to remain unsplit due to their nature and complexity.

## Quality Gate Rule

**Default:** Scripts must be <200 LOC per file.

**Exemption Criteria:**
- Script performs complex multi-step orchestration
- Script requires extensive error handling and validation
- Script is a comprehensive integration test
- Splitting would reduce maintainability without significant benefit

## Exempted Scripts

### test-spark-35-minikube.sh (302 LOC)

**Purpose:** Integration test for Spark 3.5 on Minikube

**Reason for Exemption:**
- **Complexity**: Tests entire Spark Connect stack (driver, executors, shuffle service)
- **Multi-step**: Creates kind cluster, builds/loads Spark, runs SQL workloads, validates results
- **Test Coverage**: Tests multiple scenarios (connection, SQL, DataFrame operations, error handling)
- **Error Handling**: Extensive validation of pod states, logs, and metrics
- **Difficulty to Split**: Each test step depends on previous steps; splitting would create circular dependencies

**Breakdown by Section:**
- Kind cluster setup: ~50 LOC
- Spark deployment config: ~40 LOC
- Test execution logic: ~80 LOC
- Validation and assertions: ~60 LOC
- Result aggregation: ~40 LOC
- Cleanup and teardown: ~32 LOC

**Estimated Split Impact:**
- Splitting into 4-5 files would increase complexity of test orchestration
- Single file ensures atomic test execution with proper setup/teardown ordering
- Integration tests benefit from monolithic structure

**Alternative Approaches Considered:**
1. **Keep as-is**: Current structure works well for integration testing
2. **Modular helper functions**: Extract helpers but keep main test linear
3. **Split by scenario**: Separate tests for different Spark versions (3.5, 4.1)

**Decision**: Keep as-is. This is an integration test that validates the entire Spark Connect stack. The monolithic structure ensures proper setup/teardown sequencing and reduces test flakiness.

---

## Review Process

Exemptions must be reviewed quarterly to ensure they remain valid.
Last review: 2026-02-12
Next review: 2026-05-12
