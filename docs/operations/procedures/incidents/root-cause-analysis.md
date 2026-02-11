# Root Cause Analysis Methodology

## Overview

This procedure defines methods for conducting root cause analysis (RCA) during incident response and post-incident reviews.

## RCA Methods

### 1. 5 Whys Technique

The 5 Whys method is a simple yet effective technique for exploring the cause-and-effect relationships underlying a problem.

#### When to Use

- Simple incidents with clear linear causality
- Quick initial investigation
- Single system/domain incidents
- When time is constrained

#### How to Apply

1. Write down the specific problem
2. Ask "Why did this happen?" and write the answer
3. If the answer doesn't identify the root cause, repeat step 2
4. Continue until the root cause is identified
5. Verify the root cause by reversing the logic

#### Example

**Problem**: Spark job failed with OOM errors

- **Why 1**: Executor pods were OOMKilled
- **Why 2**: Memory requests were insufficient for the data size
- **Why 3**: Data size was 3x larger than expected
- **Why 4**: Data size estimation was based on dev data, not production
- **Why 5**: No process exists for validating data size estimates
- **Root Cause**: Lack of production data validation process

#### Best Practices

- Be specific: "The system failed" → "The authentication service returned 500 errors"
- Focus on systems, not people: "John made a mistake" → "The code review process didn't catch the error"
- Validate the root cause: If we fix this, will the problem be prevented?

---

### 2. Fishbone (Ishikawa) Diagram

The fishbone diagram is a visual tool for categorizing potential causes of a problem.

#### When to Use

- Complex incidents with multiple potential causes
- Cross-functional/team incidents
- When visual representation aids understanding
- Group brainstorming sessions

#### Categories (6Ms)

1. **Man (People)**
   - Training gaps
   - Onboarding issues
   - Communication breakdowns
   - Fatigue/stress
   - Process knowledge

2. **Machine (Technology)**
   - Software bugs
   - Hardware failures
   - Configuration errors
   - Performance bottlenecks
   - Integration issues

3. **Material (Data)**
   - Data quality issues
   - Incorrect data inputs
   - Data volume changes
   - Data format changes
   - Data dependencies

4. **Method (Process)**
   - Procedure gaps
   - Manual processes
   - Missing validation
   - Insufficient testing
   - Deployment issues

5. **Measurement (Metrics)**
   - Missing metrics
   - Incorrect thresholds
   - Delayed alerts
   - False positives/negatives
   - Insufficient visibility

6. **Environment (Context)**
   - Configuration drift
   - Dependency changes
   - External API changes
   - Network issues
   - Capacity constraints

#### How to Create

1. Write the problem at the "head" of the fish
2. Draw the "spine" and main "bones" (categories)
3. Brainstorm potential causes for each category
4. Ask "Why?" for each cause to dig deeper
5. Identify the most likely root causes
6. Validate with data/evidence

#### Example: Spark Job Failure

```
                     [Job Failed]
                          |
        +-------+--------+--------+-------+
        |       |        |        |       |
     People  Process  Machine  Data  Environment
        |       |        |        |       |
  On-call   Deploy   Bug     Large    Config
  gap       manual           data     drift
        |       |        |
 Training  No       Memory
  gap      auto     leak
```

---

### 3. Timeline Analysis

A detailed chronological analysis of events leading to and during the incident.

#### When to Use

- All incidents (required for PIRs)
- Complex multi-step failures
- When timing reveals patterns
- When understanding dependencies

#### How to Create

1. Gather data from all sources (logs, metrics, chat)
2. Sort events chronologically
3. Identify key transitions (normal → degraded → failure)
4. Highlight decision points
5. Note information available at each point
6. Identify delays and miscommunications

#### Timeline Template

| Time | Event | State | Information Available | Decision Made |
|------|-------|-------|----------------------|---------------|
| 08:00 | High latency alert | Normal | Alert fired | Investigating |
| 08:05 | Dashboard error | Degraded | Error spike visible | Escalated |
| 08:10 | Root cause identified | Failure | SQL query identified | Rollback initiated |
| 08:15 | Rollback complete | Recovery | Service restored | Monitoring |

---

### 4. Change Analysis

Analyzing recent changes that may have contributed to the incident.

#### When to Use

- Deployment-related incidents
- Configuration-related incidents
- When timing correlates with changes

#### Change Categories

1. **Code Changes**
   - Recent deployments
   - Library updates
   - Dependency changes

2. **Configuration Changes**
   - ConfigMap updates
   - Environment variable changes
   - Flag toggles

3. **Infrastructure Changes**
   - Node pool changes
   - Network changes
   - Storage changes

4. **Data Changes**
   - Data volume changes
   - Schema changes
   - Data source changes

#### Analysis Process

1. List all changes in the past 7-14 days
2. Identify which changes are most relevant
3. Analyze each relevant change:
   - What was changed?
   - Why was it changed?
   - What testing was done?
   - What was the expected impact?
4. Correlate changes with incident timeline

---

## RCA Process

### Step 1: Define the Problem

Be specific about what happened:

- **Vague**: "The system was slow"
- **Specific**: "Spark job completion time increased from 5 minutes to 25 minutes at 08:00 UTC"

### Step 2: Gather Data

Collect evidence from:
- Logs (application, system, audit)
- Metrics (Prometheus, CloudWatch)
- Traces (Jaeger, X-Ray)
- Chat logs (Slack, Teams)
- Tickets (Jira, ServiceNow)

### Step 3: Choose RCA Method

Select method based on incident complexity:
- **Simple**: 5 Whys
- **Moderate**: Timeline + Change Analysis
- **Complex**: Fishbone + Timeline + Change Analysis

### Step 4: Conduct Analysis

- Involve diverse perspectives
- Challenge assumptions
- Use data to validate hypotheses
- Avoid jumping to conclusions

### Step 5: Identify Root Causes

Distinguish between:
- **Symptoms**: What we observed (job failed)
- **Contributing factors**: What enabled the failure (insufficient testing)
- **Root cause**: The fundamental issue (no automated testing for data size validation)

### Step 6: Verify Root Causes

Test by asking:
- If we fix this root cause, will the problem be prevented?
- Is this root cause something we can control?
- Is this the most fundamental cause we can address?

### Step 7: Document Findings

Document in PIR:
- Root causes identified
- Evidence supporting each cause
- Assumptions made
- Gaps in understanding

## Common Root Cause Patterns

### Technical Patterns

1. **Configuration Errors**
   - Missing config values
   - Incorrect values
   - Environment-specific issues

2. **Resource Exhaustion**
   - Memory leaks
   - Connection pool exhaustion
   - Disk full
   - CPU saturation

3. **Dependency Failures**
   - API down
   - Database unavailable
   - Network issues
   - Service degradation

4. **Data Issues**
   - Unexpected data volume
   - Malformed data
   - Data dependencies broken

### Process Patterns

1. **Insufficient Testing**
   - No unit tests
   - No integration tests
   - No load tests
   - No chaos tests

2. **Manual Processes**
   - Manual deployments
   - Manual configuration
   - Manual verification

3. **Poor Monitoring**
   - Missing alerts
   - No dashboards
   - Insufficient logging
   - Delayed detection

4. **Communication Gaps**
   - On-call handoff issues
   - Documentation gaps
   - Knowledge silos

## RCA Report Template

```markdown
## Root Cause Analysis

### Problem Statement
[Clear, specific problem description]

### Investigation Method
[Which method(s) were used]

### Analysis

#### 5 Whys
1. [First why]
2. [Second why]
...

#### Fishbone Diagram
[Diagram or description]

#### Timeline Analysis
[Key events and transitions]

#### Change Analysis
[Relevant changes identified]

### Root Causes Identified

1. **Primary Root Cause**
   - Description: [What is the fundamental issue]
   - Evidence: [Data supporting this conclusion]
   - Category: [Process/Technical/Data/People]

2. **Contributing Factors**
   - Factor 1: [Description]
   - Factor 2: [Description]

### Validation
[How we verified the root causes]

### Action Items
[Generated from root causes]
```

## Related Procedures

- [Post-Incident Review](./post-incident-review.md)
- [Incident Response](../runbooks/incidents/incident-response.md)
- [PIRA Template](../../templates/pira-template.md)

## References

- [The 5 Whys Technique](https://en.wikipedia.org/wiki/5_Whys)
- [Ishikawa Diagram](https://en.wikipedia.org/wiki/Ishikawa_diagram)
- [Root Cause Analysis Tools](https://www.isixsigma.com/tools-templates/root-cause-analysis/root-cause-analysis-made-easy/)
