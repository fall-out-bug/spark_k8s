# Blameless Culture Guidelines

## Overview

Blameless culture is essential for effective incident response and continuous improvement. This document provides guidelines for maintaining a blameless environment during incident analysis and post-incident reviews.

## Core Principles

### 1. Systems Over Individuals

**Principle**: Incidents are caused by complex systems, not individual failures.

**In Practice**:
- Ask "What system conditions led to this?" not "Who made this mistake?"
- Recognize that human error is a symptom, not a root cause
- Focus on improving the system, not punishing individuals
- Assume everyone acted with good intentions based on available information

### 2. Learning Over Blaming

**Principle**: The goal of incident analysis is learning and improvement.

**In Practice**:
- Celebrate finding problems (they're opportunities to improve)
- Treat near-misses as learning opportunities
- Share findings openly to help others learn
- Measure success by improvements, not by avoiding incidents

### 3. Psychological Safety

**Principle**: Team members must feel safe to speak up without fear of punishment.

**In Practice**:
- No repercussions for honest mistakes
- Encourage dissenting opinions
- Welcome questions and challenges
- Protect whistleblowers

## What Blameless Culture Looks Like

### During an Incident

```
# Blameless
"Let's understand what happened and why."
"What information do we need?"
"How can we recover quickly?"

# Not Blameless
"Who broke this?"
"Who wrote this code?"
"Why didn't you catch this?"
```

### During a PIR

```
# Blameless
"What conditions led to this decision?"
"What information was available at the time?"
"How can we make the system more resilient?"

# Not Blameless
"Who is responsible?"
"Why didn't you follow the procedure?"
"Shouldn't you have known better?"
```

### After an Incident

```
# Blameless
"What did we learn?"
"What can we improve?"
"Share the PIR widely!"

# Not Blameless
"Who do we need to train?"
"Who needs to be written up?"
"Keep this quiet."
```

## Language Guidelines

### Avoid These Words

| Don't Say | Why | Instead Say |
|-----------|-----|--------------|
| "Human error" | Blames the person | "Process gap" |
| "Careless" | Judges the person | "Missing validation" |
| "Should have known" | Uses hindsight | "System didn't surface this" |
| "Negligent" | Assigns blame | "Process failure" |
| "Failed to follow procedure" | Blames the person | "Procedure not discoverable" |
| "Mistake" | Negative connotation | "Learning opportunity" |

### Use These Words

| Say This | Why |
|----------|-----|
| "What conditions..." | Focuses on context |
| "How can we..." | Solution-oriented |
| "What information..." | Information gathering |
| "System allowed..." | Systems thinking |
| "Opportunity to improve" | Growth mindset |
| "We" | Collective ownership |

## Behavior Guidelines

### Do's

- Assume positive intent
- Focus on the future (what to do next)
- Admit what you don't know
- Ask curious questions
- Share your thought process
- Acknowledge tradeoffs
- Recognize constraints (time, information, tools)

### Don'ts

- Assign blame or fault
- Use "should have" questions
- Judge decisions with hindsight
- Shame or embarrass anyone
- Rush to conclusions
- Make assumptions
- Withhold information

## Examples

### Example 1: Deployment Failure

**Scenario**: A bad deployment caused an outage.

**Not Blameless**:
- "Why did you deploy without testing?"
- "Who approved this?"
- "Who wrote this buggy code?"

**Blameless**:
- "What testing gaps allowed this to reach production?"
- "How can we improve our CI/CD to catch this?"
- "What validation should we add?"

**Root Cause**:
- Not: "Engineer didn't test"
- Yes: "No automated testing for this code path"

### Example 2: Configuration Error

**Scenario**: Wrong config value caused a service failure.

**Not Blameless**:
- "Who made this typo?"
- "Why didn't you check the config?"
- "Be more careful next time."

**Blameless**:
- "What validation would have caught this?"
- "How can we make config errors visible?"
- "What tooling would help prevent this?"

**Root Cause**:
- Not: "Engineer made a typo"
- Yes: "No config validation in deployment process"

### Example 3: Incident Response Delay

**Scenario**: Incident wasn't acknowledged for 30 minutes.

**Not Blameless**:
- "Why didn't you respond to the alert?"
- "Where was the on-call engineer?"
- "You need to be more responsive."

**Blameless**:
- "Why wasn't the alert actionable?"
- "What on-call gaps caused this delay?"
- "How can we improve alerting?"

**Root Cause**:
- Not: "On-call engineer ignored alert"
- Yes: "Alert fatigue caused all alerts to be ignored"

## Leadership Role

Leaders must model blameless behavior:

### During Incidents
- Participate as a peer, not a judge
- Focus on resolution, not assigning fault
- Thank responders for their work
- Ask "What can I do to help?"

### During PIRs
- Set blameless tone at the start
- Interviate if blame creeps in
- Share your own mistakes
- Reinforce that incidents are inevitable

### After PIRs
- Resource action items appropriately
- Measure learning, not blame
- Celebrate improvements
- Share findings widely

## Implementation

### Team Agreement

Create a team agreement on blameless culture:

1. We assume positive intent
2. We focus on systems, not people
3. We learn from every incident
4. We share our findings openly
5. We support each other

### PIR Facilitator Role

The PIR facilitator ensures blameless culture by:
- Starting with a reminder of blameless principles
- Interrupting blame language
- Reframing questions to be blameless
- Modeling curious, non-judgmental inquiry
- Protecting participants from blame

### Training

All team members should be trained on:
- What blameless culture is (and isn't)
- Why it matters for incident response
- How to conduct blameless RCAs
- Blameless language and behavior
- How to intervene when blame appears

## Metrics

Measure blameless culture health:

| Metric | Target | Measurement |
|--------|--------|-------------|
| PIR participation rate | 100% of responders | Attendees / responders |
| Repeat incident rate | < 5% | Recurring / total |
| Action item completion | > 90% | Completed / total |
| Incident reporting | All incidents reported | Reports / estimate |
| Team psychological safety | > 80% positive | Annual survey |

## Common Misconceptions

### Misconception: Blameless means no accountability

**Reality**: Blameless means system accountability, not individual punishment. We hold people accountable by:
- Giving them the resources to succeed
- Providing proper training
- Building robust systems
- Learning from failures

### Misconception: Blameless means we don't care about mistakes

**Reality**: We care deeply about preventing mistakes, which means:
- Understanding why mistakes happen
- Building systems that prevent them
- Learning from every mistake
- Sharing that learning widely

### Misconception: Blameless means we can't talk about what happened

**Reality**: Blameless means we talk MORE openly about what happened, but focus on systems instead of individuals.

## Handling Persistent Blame Culture

If blame culture persists:

1. **Identify the pattern**: Where does blame appear?
2. **Understand the root cause**: Why does blame persist?
3. **Address it directly**: Have a conversation about blame culture
4. **Provide training**: Teach blameless techniques
5. **Model behavior**: Leaders must demonstrate blameless culture
6. **Create accountability**: Make blameless culture a performance metric

## Resources

### Reading

- [The Blameless Postmortem](https://queue.acm.org/detail.cfm?id=2796433)
- [Psychological Safety and Learning Behavior in Work Teams](https://hbr.org/1999/01/psychological-safety-and-learning-behavior-in-work-teams)
- [Google's Project Aristotle](https://rework.withgoogle.com/print/guides/5721312655836160/)

### Training

- Blameless Postmortem Workshop (Quarterly)
- PIR Facilitator Training (Biannual)
- Psychological Safety Assessment (Annual)

## Related Procedures

- [Post-Incident Review](./post-incident-review.md)
- [Root Cause Analysis](./root-cause-analysis.md)
- [Incident Response](../runbooks/incidents/incident-response.md)
