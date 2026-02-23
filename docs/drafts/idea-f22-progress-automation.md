# Feature F22: Progress Automation

> **Feature ID:** F22  
> **Beads:** spark_k8s-703  
> **Source:** docs/plans/2026-02-04-product-branding-strategy.md Phase 1

## Goal

Set up automated progress bot via GitHub Actions to:
- Comment on closed workstreams with summary
- Update roadmap status automatically
- Generate weekly progress digest to Telegram channel
- (Optional) Metrics dashboard for visibility

## Context

From Product & Community Strategy Phase 1:
- "Set up progress automation" (1h) — Consistency
- Transparency and regular updates build trust with contributors

## Scope

| Component | Description |
|-----------|-------------|
| Workstream completion bot | GH Action on PR merge; comment with WS summary |
| ROADMAP auto-update | Update ROADMAP.md from docs/workstreams/INDEX.md |
| Weekly digest | Scheduled job; aggregate week's completions; post to Telegram |
| Metrics dashboard | (P3) Simple visibility into completion rate |

## Dependencies

- GitHub Actions (existing)
- Telegram Bot API (for digest)
- docs/workstreams/ structure (existing)

## Out of Scope

- Beads integration (separate)
- External project management tools
