# Specs Index

Active feature specs (spec-kit SDD). Constitution governs all of them.

## Constitution

- [_constitution.md](_constitution.md) — project-wide principles + Consumers & Invariants, v1.1.0 (ratified 2026-06-14, amended 2026-06-17)

## Active Features

| Feature | Status | Path |
|---------|--------|------|
| Spark Load Tests with 10GB NYC Taxi | Draft (0/30 tasks) | [spark-load-tests-10gb/](spark-load-tests-10gb/) |
| Harden Default Credentials in Values Files | Draft (0/25 tasks) | [credential-hardening/](credential-hardening/) |
| Grafana Observability Stand | ✅ Completed (36/36 tasks, PR #9 merged) | [grafana-observability-stand/](grafana-observability-stand/) — ready to archive |

## Workflow

```
/speckit.constitution                         # one-time setup (DONE)
/speckit.specify "Add feature X"              # create new spec
/speckit.plan                                 # technical plan
/speckit.tasks                                # actionable tasks
/speckit.implement                            # execute
/speckit.analyze                              # consistency check
/speckit.taskstoissues                        # publish to GitHub Issues
```

## Historical Archive

Pre-migration (SDP workstream format, 35+ features, 28+ completed WS):

- [docs/archive/sdp-workstreams/MEMORIES.md](../docs/archive/sdp-workstreams/MEMORIES.md) — meta-library of historical project state (read-only provenance)
- [docs/archive/sdp-workstreams/INDEX.md](../docs/archive/sdp-workstreams/INDEX.md) — feature/WS index
- [docs/archive/sdp-workstreams/completed/](../docs/archive/sdp-workstreams/completed/) — 28+ completed workstreams
- [docs/archive/sdp-workstreams/backlog/](../docs/archive/sdp-workstreams/backlog/) — 2 backlog WS (migrated to specs/ above)

Do NOT add new work to the archive. New features use `specs/<name>/` only.
