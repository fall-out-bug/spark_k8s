# PIR Template

**Incident ID**: INC-XXXX
**Incident Date**: YYYY-MM-DD
**PIR Date**: YYYY-MM-DD
**PIR Facilitator**: @name
**Document Status**: Draft | In Review | Published

---

## Executive Summary

*2-3 sentences describing what happened, the impact, and the key learning.*

**Template**:
On [DATE], [INCIDENT DESCRIPTION] occurred, resulting in [IMPACT]. The incident was caused by [ROOT CAUSE]. We have implemented [IMMEDIATE FIX] and have [NUMBER] action items to prevent recurrence.

**Example**:
On 2026-02-10 at 08:00 UTC, a Spark job failure caused 2 hours of data processing delay, impacting 50 users. The incident was caused by insufficient memory allocation for a 3x increase in data volume. We have increased memory limits and have 3 action items to prevent recurrence.

---

## Impact Assessment

### Customer Impact

- **Duration**: [X hours/Y minutes]
- **Affected Users**: [Number or percentage]
- **Affected Services**: [List of services]
- **User-Facing Symptoms**: [What users experienced]

### Business Impact

- **Revenue Impact**: [Dollars lost/opportunity cost]
- **SLA Breaches**: [Yes/No, details]
- **Customer Complaints**: [Number]
- **Compensation Required**: [Yes/No, details]

### Technical Impact

- **Services Degraded**: [List with duration]
- **Data Loss**: [Yes/No, details]
- **Recovery Time**: [Time to restore service]
- **MTTR**: [Mean time to resolution]

---

## Incident Timeline

| Time (UTC) | Event | State | Information Available | Action Taken |
|------------|-------|-------|----------------------|--------------|
| HH:MM | [What happened] | Normal/Degraded/Failure | [What was known] | [What was done] |
| HH:MM | [What happened] | Normal/Degraded/Failure | [What was known] | [What was done] |
| ... | ... | ... | ... | ... |

**Timeline Notes**:
- [Any important context about the timeline]
- [Decision points and rationale]
- [Communication breakdowns]

---

## Root Cause Analysis

### Investigation Method

Select methods used:
- [ ] 5 Whys
- [ ] Fishbone Diagram
- [ ] Timeline Analysis
- [ ] Change Analysis
- [ ] Other: [specify]

### Analysis

#### 5 Whys

1. **Why did [symptom] happen?**
   - [Answer]

2. **Why did [that] happen?**
   - [Answer]

3. **Why did [that] happen?**
   - [Answer]

4. **Why did [that] happen?**
   - [Answer]

5. **Why did [that] happen?**
   - **Root Cause**: [The fundamental issue]

#### Contributing Factors

- **Factor 1**: [Description]
  - How it contributed: [Explanation]
  - Evidence: [Data/supporting info]

- **Factor 2**: [Description]
  - How it contributed: [Explanation]
  - Evidence: [Data/supporting info]

### Root Cause Summary

**Primary Root Cause**:
[Description of the fundamental system issue that caused the incident]

**Secondary Contributing Factors**:
1. [Factor 1]
2. [Factor 2]

---

## Resolution

### Immediate Fix

**What we did to fix the incident**:
- [Action 1]
- [Action 2]
- [Action 3]

**Time to Resolution**: [X hours/Y minutes]

### Verification

**How we verified the fix worked**:
- [Verification method 1]
- [Verification method 2]

---

## Action Items

### High Priority (P0)

- [ ] **[Action Item Title]** (Owner: @name, Due: YYYY-MM-DD)
  - **Description**: [What needs to be done]
  - **Acceptance Criteria**: [How to verify completion]
  - **Link**: [GitHub issue / Jira ticket]

### Medium Priority (P1)

- [ ] **[Action Item Title]** (Owner: @name, Due: YYYY-MM-DD)
  - **Description**: [What needs to be done]
  - **Acceptance Criteria**: [How to verify completion]
  - **Link**: [GitHub issue / Jira ticket]

### Low Priority (P2)

- [ ] **[Action Item Title]** (Owner: @name, Due: YYYY-MM-DD)
  - **Description**: [What needs to be done]
  - **Acceptance Criteria**: [How to verify completion]
  - **Link**: [GitHub issue / Jira ticket]

---

## Lessons Learned

### What Went Well

- [Positive aspect 1]
- [Positive aspect 2]

### What Could Be Improved

- [Improvement area 1]
- [Improvement area 2]

### What Surprised Us

- [Surprise 1]
- [Surprise 2]

### What Would We Do Differently

- [Different action 1]
- [Different action 2]

---

## Follow-up

### 30-Day Check

**Date**: YYYY-MM-DD
**Items to Verify**:
- [ ] All action items completed
- [ ] Metrics improved
- [ ] No recurrence of incident

### Results

- **Action Items Completed**: X / Y
- **Metrics Improved**: Yes / No (details)
- **Incident Recurred**: Yes / No

---

## Appendix

### Logs

**Relevant Log Excerpts**:

```
[Paste relevant log entries here]
```

### Metrics

**Screenshots/Graphs**:

[Attach metrics graphs showing incident]

### Chat Logs

**Key Communication**:

[Relevant chat messages]

### Screenshots

**UI Screenshots**:

[Attach screenshots if relevant]

---

## Review History

| Date | Reviewer | Status | Comments |
|------|----------|--------|----------|
| YYYY-MM-DD | @name | Technical Review | [Comments] |
| YYYY-MM-DD | @name | Management Review | [Comments] |
| YYYY-MM-DD | @name | Approved | [Comments] |

---

**Document Status**: [Draft | In Review | Published]
**Next Review**: [Date for 30-day check]

---

## Resources

- **Incident Ticket**: [Link]
- **Runbook Used**: [Link]
- **Related PIRs**: [Links]
- **RFCs/Design Docs**: [Links if applicable]

---

*This PIR follows the Blameless Post-Incident Review process documented in [PROCEDURE LINK]*
