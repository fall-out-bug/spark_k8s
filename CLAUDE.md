# Claude Code Integration Guide

Quick reference for using this Spec-Driven Protocol (SDP) repository with Claude Code.

> **📝 Meta-note:** This guide was written with AI assistance (Claude Sonnet 4.5). The workflow is based on real development experience.

## SDP Submodule

This repository uses [SDP](https://github.com/fall-out-bug/sdp) as a git submodule:

```bash
# Initialize submodule (first time)
git submodule update --init --recursive

# Update submodule to latest
git submodule update --remote .sdp

# Check SDP version
cd .sdp && git log --oneline -1 && cd ..
```

**SDP files (symlinks):**
- `PROTOCOL.md` → `.sdp/PROTOCOL.md` (Full SDP specification)
- `CODE_PATTERNS.md` → `.sdp/CODE_PATTERNS.md` (Code patterns)
- `MODELS.md` → `.sdp/MODELS.md` (Model recommendations)

**SDP Version:** v0.9.8

## TL;DR

Use **skills** to execute SDP commands:

```
@idea "Add user authentication"
@design idea-user-auth
@build WS-001-01
@review F01
@deploy F01
```

## Available Skills

| Skill | Purpose | Example |
|-------|---------|---------|
| `@idea` | **Interactive requirements** (AskUserQuestion) | `@idea "Add payment processing"` |
| `@design` | **Interactive planning** (EnterPlanMode) | `@design idea-payments` |
| `@build` | Execute workstream (TodoWrite tracking) | `@build WS-001-01` |
| `@review` | Quality check | `@review F01` |
| `@deploy` | Production deployment | `@deploy F01` |
| `@issue` | Debug and route bugs | `@issue "Login fails on Firefox"` |
| `@hotfix` | Emergency fix (P0) | `@hotfix "Critical API outage"` |
| `@bugfix` | Quality fix (P1/P2) | `@bugfix "Incorrect totals"` |
| `@oneshot` | **Autonomous execution** (Task-based) | `@oneshot F01` or `@oneshot F01 --background` |

Skills are defined in `.claude/skills/{name}/SKILL.md`

**Claude Code Integration Highlights:**
- `@idea` — Deep interviewing via AskUserQuestion (no obvious questions, explores tradeoffs)
- `@design` — EnterPlanMode for codebase exploration + AskUserQuestion for architecture decisions
- `@build` — TodoWrite real-time progress tracking through TDD cycle
- `@oneshot` — Task tool spawns isolated orchestrator agent with background execution support

## Quick Reference

### First Time Setup

1. **Read core docs:**
   - [README.md](README.md) — Overview and quick start
   - [PROTOCOL.md](PROTOCOL.md) — Full SDP specification
   - [RULES_COMMON.md](RULES_COMMON.md) — Common rules

2. **Understand key concepts:**
   - **Workstream (WS)**: Atomic task, one-shot execution
   - **Feature**: 5-30 workstreams
   - **Release**: 10-30 features

3. **Review quality gates:**
   - Files < 200 LOC
   - Coverage ≥80%
   - No `except: pass`
   - Full type hints

### Typical Workflow

```bash
# 1. Gather requirements (Interactive interviewing)
@idea "User can reset password via email"
# Claude asks deep questions via AskUserQuestion:
# - Technical approach (email service, token storage)
# - UI/UX (where in app, error messages)
# - Security (token expiry, rate limiting)
# - Concerns (complexity, failure modes)
# Result: comprehensive spec in docs/drafts/

# 2. Design workstreams (Interactive planning)
@design idea-password-reset
# Claude enters Plan Mode:
# - Explores codebase (existing auth, email infrastructure)
# - Asks architecture questions (JWT vs sessions, etc.)
# - Designs WS decomposition
# - Requests approval via ExitPlanMode
# Result: WS-XXX-01, WS-XXX-02, etc. in docs/workstreams/backlog/

# 3. Execute each workstream
@build WS-001-01
# Claude shows TodoWrite progress tracking:
#   [in_progress] Pre-build validation
#   [pending] Write failing test (Red)
#   [pending] Implement minimum code (Green)
#   [pending] Refactor implementation
#   ... (updates in real-time)

@build WS-001-02
# ... or use autonomous mode:
@oneshot F01

# 4. Review quality
@review F01

# 5. Deploy to production
@deploy F01
```

### Progress Tracking

When using `@build`, Claude Code automatically tracks progress using TodoWrite:

```markdown
User: @build WS-060-01

Claude:
→ Creating todo list...
  ✓ [in_progress] Pre-build validation
  • [pending] Write failing test (Red)
  • [pending] Implement minimum code (Green)
  • [pending] Refactor implementation
  • [pending] Verify Acceptance Criteria
  • [pending] Run quality gates
  • [pending] Append execution report
  • [pending] Git commit

→ Reading WS file...
  ✓ [completed] Pre-build validation
  ✓ [in_progress] Write failing test (Red)
  • [pending] Implement minimum code (Green)
  ...

→ Test created, running pytest... FAILED (expected)
  ✓ [completed] Write failing test (Red)
  ✓ [in_progress] Implement minimum code (Green)
  ...

→ Implementation done, running pytest... PASSED
  ✓ [completed] Implement minimum code (Green)
  ✓ [in_progress] Refactor implementation
  ...

[All steps complete]
  ✓ All tasks completed
```

This provides real-time visibility into WS execution progress.

### Autonomous Execution with @oneshot

For features with multiple workstreams, use `@oneshot` for autonomous execution:

```markdown
User: @oneshot F01

Claude Code:
→ Spawning orchestrator agent via Task tool...
→ Agent ID: abc123xyz (save for resume)

Orchestrator Agent:
→ Reading feature specification and workstreams...
→ Found 4 workstreams to execute

→ Creating todo list...
  ✓ [in_progress] Wait for PR approval
  • [pending] Execute WS-001-01: Domain entities
  • [pending] Execute WS-001-02: Application services
  • [pending] Execute WS-001-03: Infrastructure layer
  • [pending] Execute WS-001-04: API endpoints
  • [pending] Run final review
  • [pending] Generate UAT guide

→ Creating PR for approval...
→ Waiting for approval...

[User approves PR in GitHub]

→ PR approved!
  ✓ [completed] Wait for PR approval
  ✓ [in_progress] Execute WS-001-01: Domain entities

→ Executing WS-001-01...
  (internal @build TodoWrite tracking for this WS)
→ WS-001-01 complete (45m, 85% coverage)
  ✓ [completed] Execute WS-001-01: Domain entities
  ✓ [in_progress] Execute WS-001-02: Application services

→ Executing WS-001-02...
→ WS-001-02 complete (1h 10m, 82% coverage)
  ✓ [completed] Execute WS-001-02: Application services
  ✓ [in_progress] Execute WS-001-03: Infrastructure layer

... (continues for all WS)

→ All workstreams complete
  ✓ [in_progress] Run final review

→ Running /review F01...
→ Review verdict: APPROVED
  ✓ [completed] Run final review
  ✓ [in_progress] Generate UAT guide

→ Generating UAT guide...
  ✓ [completed] Generate UAT guide

→ All tasks completed! ✅

Main Claude:
## ✅ Feature F01 Execution Complete

**Agent ID:** abc123xyz (for resume)
**Duration:** 3h 45m
**Workstreams:** 4/4 completed
**Coverage:** avg 86%

### Next Steps
1. Human UAT (5-10 min)
2. `@deploy F01` if UAT passes
```

**Background execution** for large features:

```bash
User: @oneshot F01 --background

Claude Code:
→ Starting orchestrator agent in background...
→ Task ID: xyz789
→ Output file: /tmp/agent_xyz789.log

You can continue working. I'll notify when complete.
Check progress: Read("/tmp/agent_xyz789.log")

[5 minutes later]
✅ Background task xyz789 completed!
Feature F01 is done and ready for UAT.
```

**Resume** from interruption:

```bash
# If execution interrupted
User: @oneshot F01 --resume abc123xyz

Claude Code:
→ Resuming agent abc123xyz...
→ Agent continues from last checkpoint (WS-001-03)
```

### File Structure Reference

```
project/
├── docs/
│   ├── drafts/           # @idea outputs here
│   ├── workstreams/
│   │   ├── backlog/      # @design outputs here
│   │   ├── in_progress/  # @build moves here
│   │   └── completed/    # @build finalizes here
│   └── specs/            # Feature specifications
├── prompts/commands/     # Skill instructions
├── .claude/
│   ├── skills/           # Skill definitions
│   ├── agents/           # Multi-agent mode (advanced)
│   └── settings.json     # Claude Code settings
└── hooks/                # Git hooks for validation
```

## Key Principles (Quick)

- **SOLID, DRY, KISS, YAGNI** — see [docs/PRINCIPLES.md](docs/PRINCIPLES.md)
- **Clean Architecture** — Domain ← App ← Infra ← Presentation
- **TDD** — Tests first (Red → Green → Refactor)
- **AI-Readiness** — Small files, low complexity, typed

## Validation

### Pre-build Check
```bash
hooks/pre-build.sh WS-001-01
```

### Post-build Check
```bash
hooks/post-build.sh WS-001-01 project.module
```

### Manual Validation
```bash
python scripts/validate.py docs/workstreams/backlog/
```

## Quality Gates (Enforced)

| Gate | Requirement |
|------|-------------|
| **AI-Readiness** | Files < 200 LOC, CC < 10, type hints |
| **Clean Architecture** | No layer violations |
| **Error Handling** | No `except: pass` |
| **Test Coverage** | ≥80% |
| **No TODOs** | All tasks completed or new WS |

## Forbidden Patterns

❌ `except: pass` or bare exceptions  
❌ Time-based estimates  
❌ Layer violations  
❌ Files > 200 LOC  
❌ TODO without followup WS  
❌ Coverage < 80%

## Required Patterns

✅ Type hints everywhere  
✅ Tests first (TDD)  
✅ Explicit error handling  
✅ Clean architecture boundaries  
✅ Conventional commits

## Troubleshooting

### Skill not found
Check `.claude/skills/{name}/SKILL.md` exists

### Validation fails
Run `hooks/pre-build.sh {WS-ID}` to see specific issues

### Workstream blocked
Check dependencies in `docs/workstreams/backlog/{WS-ID}.md`

### Coverage too low
Run `pytest --cov --cov-report=term-missing` to identify gaps

## Advanced: Multi-Agent Mode

For complex features, use multi-agent orchestration:

```bash
@orchestrator F01  # Coordinates all agents
```

Agents defined in `.claude/agents/`:
- `planner.md` — Breaks features into workstreams
- `builder.md` — Executes workstreams
- `reviewer.md` — Quality checks
- `deployer.md` — Production deployment
- `orchestrator.md` — Coordinates workflow

## Configuration

See `.claude/settings.json` for:
- Custom Git hooks
- Validation scripts
- Tool integrations

## Resources

| Resource | Purpose |
|----------|---------|
| [PROTOCOL.md](PROTOCOL.md) | Full specification |
| [docs/PRINCIPLES.md](docs/PRINCIPLES.md) | Core principles |
| [CODE_PATTERNS.md](CODE_PATTERNS.md) | Code patterns |
| [MODELS.md](MODELS.md) | Model recommendations |
| [prompts/commands/](prompts/commands/) | Skill instructions |

---

**Version:** SDP v0.9.8  
**Claude Code Version:** 0.3+  
**Mode:** Skill-based, one-shot execution
