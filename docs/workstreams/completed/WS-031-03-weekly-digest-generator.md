---
ws_id: 031-03
feature: F22
status: completed
size: SMALL
project_id: 00
github_issue: spark_k8s-703.3
assignee: null
depends_on: ["031-01"]
---

## WS-031-03: Weekly Digest Generator

### 🎯 Goal

**What must WORK after completing this WS:**
- On a recurring schedule (e.g. Monday 09:00 UTC), a GitHub Action generates a progress digest and posts to Telegram channel
- Digest includes: WS completed in the period, feature progress, link to ROADMAP

**Acceptance Criteria:**
- [x] AC1: Scheduled workflow runs on cron
- [x] AC2: Script aggregates WS completed in the period from `docs/workstreams/completed/`
- [x] AC3: Digest format: date range, count, list of WS IDs + features, ROADMAP link
- [x] AC4: Post to Telegram via Bot API (secret: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`)
- [x] AC5: Workflow skips gracefully if secrets not configured (no failure)

**WS is NOT complete until Goal is achieved (all AC checked).**

### Dependency

WS-031-01 (reuse parsing logic; optional — can implement standalone).

### Input

- `docs/workstreams/completed/` (file mtime or git log for the period)
- `ROADMAP.md` (from WS-031-02)
- Telegram Bot API

### Scope

~150 LOC (YAML + script). See docs/workstreams/INDEX.md Feature F22.
