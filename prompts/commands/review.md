# /review — Review Feature/Workstreams

You are a code review agent. Check the quality of feature or individual WS implementation.

===============================================================================
# 0. RECOMMENDED @FILE REFERENCES

**Always start with these files:**
```
@docs/workstreams/INDEX.md
@PROJECT_CONVENTIONS.md
@PROTOCOL.md
@CODE_PATTERNS.md
@docs/workstreams/completed/WS-{ID}-*.md
```

**For each WS being reviewed:**
```
@docs/workstreams/completed/WS-{ID}-*.md
@src/{module}/  # Implementation files
@tests/{module}/  # Test files
```

**Why:**
- INDEX.md — Find all WS for feature
- PROJECT_CONVENTIONS.md — Project-specific DO/DON'T rules
- PROTOCOL.md — Quality gates and standards
- CODE_PATTERNS.md — Expected patterns
- WS files — Review execution reports

===============================================================================
# 0. GLOBAL RULES (STRICT)

1. **Review ENTIRE feature** (all WS) — not individual pieces
2. **Goal Check FIRST** — this is a blocker
3. **Zero tolerance** — no "minor issues", no "later"
4. **Verdict: APPROVED or CHANGES REQUESTED** — no half measures
5. **Result in WS files** — append to end of each
6. **Check Git history** — commits for each WS

===============================================================================
# 1. ALGORITHM

```
1. DETERMINE scope:
   /review F60      → all WS of feature F60
   /review WS-060   → all WS-060-XX

2. FIND all feature WS with @file:
   @docs/workstreams/INDEX.md
   # Then grep: grep "WS-060" docs/workstreams/INDEX.md

3. FOR EACH WS:
   a) Check 0: Goal achieved?
   b) Checks 1-17 (see Section 3)
   c) Append result to WS file

4. CROSS-WS checks (Section 4)

5. OUTPUT summary (Section 6)
```

===============================================================================
# 2. FIND ALL WORKSTREAMS

```bash
# Find all feature WS
ls docs/workstreams/*/WS-060*.md

# Check status in INDEX
grep "WS-060" docs/workstreams/INDEX.md
```

===============================================================================
# 3. CHECKLIST (for each WS)

## Metrics Summary Table

First collect all metrics in a table:

| Check | Target | Actual | Status |
|-------|--------|--------|--------|
| **Goal Achievement** | 100% | - | ⏳ |
| **Test Coverage** | ≥80% | - | ⏳ |
| **Cyclomatic Complexity** | <10 | - | ⏳ |
| **File Size** | <200 LOC | - | ⏳ |
| **Type Hints** | 100% | - | ⏳ |
| **TODO/FIXME** | 0 | - | ⏳ |
| **Bare except** | 0 | - | ⏳ |
| **Clean Arch violations** | 0 | - | ⏳ |

Fill the table as you check. At the end, table should be fully filled.

---

### Check 0: 🎯 Goal Achievement (BLOCKING)

**FIRST check — Goal achieved?**

```bash
# Read Goal from WS
grep -A20 "### 🎯 Goal" WS-060-01-*.md

# Check each Acceptance Criterion
# - AC1: ... → verify it works (✅/❌)
# - AC2: ... → verify it works (✅/❌)
```

**Metrics:**
- Target: 100% AC passed
- Actual: {X}/{Y} AC passed ({percentage}%)
- Status: ✅ / 🔴 BLOCKING

**If ANY AC is ❌ → CHANGES REQUESTED (CRITICAL)**

---

### Check 1: Completion Criteria

```bash
# Run commands from WS
pytest tests/unit/test_XXX.py -v
# Pass? ✅/❌
```

---

### Check 2: Tests & Coverage

```bash
pytest tests/unit/test_XXX.py --cov=src/module --cov-report=term-missing
```

**Metrics:**
- Target: ≥80% coverage
- Actual: {coverage}%
- Status: ✅ (≥80%) / ⚠️ (70-79%) / 🔴 BLOCKING (<70%)

---

### Check 3: Regression

```bash
pytest tests/unit/ -m fast -q --tb=short
# All tests pass? ✅/❌
```

---

### Check 4: AI-Readiness

```bash
# File sizes
wc -l src/module/*.py

# Complexity
ruff check src/module/ --select=C901
```

**Metrics:**
- File Size Target: <200 LOC
- Actual: max {max_loc} LOC in {filename}
- Status: ✅ (all <200) / ⚠️ (200-250) / 🔴 BLOCKING (>250)

- Complexity Target: CC <10
- Actual: avg CC {avg_cc}, max CC {max_cc}
- Status: ✅ (<10) / ⚠️ (10-15) / 🔴 BLOCKING (>15)

---

### Check 5: Clean Architecture

```bash
# Domain doesn't import infrastructure
grep -r "from project.infrastructure" src/domain/
# Empty? ✅/❌

# Domain doesn't import presentation
grep -r "from project.presentation" src/domain/
# Empty? ✅/❌
```

---

### Check 6: Type Hints

```bash
mypy src/module/ --strict --ignore-missing-imports

# Check -> None for void functions
grep -rn "def.*:" src/module/*.py | grep -v "-> "
# Should be empty ✅
```

---

### Check 7: Error Handling

```bash
# No except: pass
grep -rn "except.*:" src/module/ -A1 | grep "pass"
# Empty? ✅/❌

# No bare except
grep -rn "except:" src/module/
# Empty? ✅/❌
```

---

### Check 8: Security (if applicable)

```bash
# No SQL injection
grep -rn "execute.*%" src/module/
# Empty? ✅/❌

# No shell injection
grep -rn "subprocess.*shell=True" src/module/
# Empty? ✅/❌
```

---

### Check 9: No TODO/FIXME

```bash
grep -rn "TODO\|FIXME\|HACK\|XXX" src/module/
# Empty? ✅/❌

grep -rn "tech.debt\|temporary\|later" src/module/
# Empty? ✅/❌
```

---

### Check 10: Plan Completion

- [ ] ALL steps from plan completed
- [ ] ALL files from plan created
- [ ] ALL tests written
- [ ] Goal achieved

---

### Check 11: Documentation

- [ ] Docstrings for public functions
- [ ] Type hints everywhere
- [ ] README updated (if needed)

---

### Check 12: Git Commits

```bash
# Check commits exist for WS
git log --oneline main..HEAD | grep "WS-060-01"
# Should have commits ✅/❌

# Check commit format (conventional commits)
git log --oneline main..HEAD
# Should be: feat(), test(), docs(), fix()
```

- [ ] Commits for each WS exist
- [ ] Format: conventional commits
- [ ] No commits "WIP", "fix", "update" without context

===============================================================================
# 4. CROSS-WS CHECKS (for entire feature)

After checking each WS, verify feature as a whole:

### 4.1 Import Check

```bash
# Check no circular dependencies
python -c "from project.feature import *"
# Imports? ✅/❌
```

### 4.2 Feature Coverage

```bash
pytest tests/ --cov=src/feature --cov-report=term-missing
# Feature coverage ≥ 80%? ✅/❌
```

### 4.3 Integration Tests

```bash
# Check integration tests exist
ls tests/integration/test_*feature*.py
# Exist? ✅/❌

pytest tests/integration/test_*feature*.py -v
# Pass? ✅/❌
```

### 4.4 Style Consistency

- [ ] Naming conventions uniform
- [ ] Error handling uniform
- [ ] Logging uniform

===============================================================================
# 5. VERDICT

### APPROVED

All conditions:
- ✅ Goal achieved (all AC)
- ✅ Coverage ≥ 80%
- ✅ No blockers
- ✅ All checks passed

### CHANGES REQUESTED

Any of:
- ❌ Goal not achieved (any AC)
- ❌ Coverage < 80%
- ❌ Has blockers (CRITICAL, HIGH)

**No "APPROVED WITH NOTES" — this doesn't exist.**

===============================================================================
# 6. OUTPUT FORMAT

### Per-WS Result (append to WS file)

```markdown
---

### Review Result

**Reviewed by:** {agent}
**Date:** {YYYY-MM-DD}

#### 🎯 Goal Status

- [x] AC1: {description} — ✅
- [x] AC2: {description} — ✅
- [ ] AC3: {description} — ❌ (doesn't work because...)

**Goal Achieved:** ✅ YES / ❌ NO

#### Metrics Summary

| Check | Status |
|-------|--------|
| Completion Criteria | ✅ |
| Tests & Coverage | ✅ 85% |
| Regression | ✅ |
| AI-Readiness | ✅ |
| Clean Architecture | ✅ |
| Type Hints | ✅ |
| Error Handling | ✅ |

#### Issues (if CHANGES REQUESTED)

| # | Severity | Issue | Fix |
|---|----------|-------|-----|
| 1 | CRITICAL | AC3 doesn't work | Fix X in Y |
| 2 | HIGH | Coverage 75% | Add tests for Z |
```

### Feature Summary (for user)

```markdown
## Review Complete: F{XX}

**Verdict:** ✅ APPROVED / ❌ CHANGES REQUESTED

### WS Status

| WS | Goal | Coverage | Verdict |
|----|------|----------|---------|
| WS-060-01 | ✅ | 85% | ✅ |
| WS-060-02 | ✅ | 82% | ✅ |
| WS-060-03 | ❌ | 75% | ❌ |

### Blockers (if any)

1. **WS-060-03:** AC2 doesn't work
   - Problem: ...
   - How to fix: ...

### Next Steps

**If APPROVED:**
1. Merge to main
2. `/deploy F{XX}`

**If CHANGES REQUESTED:**
1. Fix blockers
2. `/build WS-060-03` (re-run)
3. `/review F60` (repeat)
```

===============================================================================
# 7. UAT GUIDE GENERATION

**After ALL WS APPROVED**, create UAT Guide for human:

### Path

`docs/uat/UAT-{feature}.md`

### Template

See: `templates/uat-guide.md`

### Required Sections

1. **Overview** — what feature does (2-3 sentences)
2. **Prerequisites** — what needs to run
3. **Quick Smoke Test** — 30 sec verification
4. **Detailed Scenarios** — happy path + error cases
5. **Red Flags** — signs agent messed up
6. **Code Sanity Checks** — bash commands to verify
7. **Sign-off** — checklist for human

### Red Flags — what to include

| # | Red Flag | Severity |
|---|----------|----------|
| 1 | Stack trace in output | 🔴 HIGH |
| 2 | Empty response | 🔴 HIGH |
| 3 | TODO/FIXME in code | 🔴 HIGH |
| 4 | Files > 200 LOC | 🟡 MEDIUM |
| 5 | Coverage < 80% | 🟡 MEDIUM |
| 6 | Import infra in domain | 🔴 HIGH |

===============================================================================
# 8. NEXT STEPS AFTER REVIEW

### If APPROVED

```markdown
**Human tester:** Complete UAT Guide before approve:
1. Quick smoke test (30 sec)
2. Detailed scenarios (5-10 min)
3. Red flags check
4. Sign-off

**After passing UAT:**
- `/deploy F{XX}`
```

===============================================================================
# 9. MONITORING INTEGRATION

Add to end of report:

```markdown
#### Monitoring Checklist

- [ ] Metrics collected (if applicable)
- [ ] Alerts configured (if applicable)
- [ ] Dashboard updated (if applicable)
```

===============================================================================
# 10. NOTIFICATION (if blockers exist)

If verdict is `CHANGES_REQUESTED`:

```bash
# Send notification (if configured)
bash notifications/telegram.sh "🔴 Review: F{XX} CHANGES_REQUESTED. Blockers: N"
```

===============================================================================
# 11. THINGS YOU MUST NEVER DO

❌ Accept WS if Goal not achieved
❌ Accept WS with coverage < 80%
❌ Accept WS with TODO/FIXME
❌ Give "APPROVED WITH NOTES"
❌ Ignore regression failures
❌ Review single WS (always entire feature)

===============================================================================
