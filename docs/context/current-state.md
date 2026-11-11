# Current State

> Update at the end of every working session using the `/handoff` skill. Keep this file under ~80 lines: replace old content rather than appending history (history lives in git).

**Last updated:** 2026-11-11
**Phase:** Pre-Phase 0. Repository bootstrapped; no application code.

## Done
- Architecture review completed (`architecture-review/01–06`).
- Repository bootstrapped:
  - git
  - folder structure
  - minimal CLAUDE.md plus folder-level CLAUDE.md files
  - context docs
  - project skills: handoff, adr, poc-record, cost-estimate, setup-machine
  - architecture-guard agent
  - graphify graph (184 nodes, 8 communities), committed
  - `.mcp.json` with Cloudflare API, Cloudflare docs and gcloud (preview)
  - a SessionStart hook that triggers a one-time `/setup-machine`
  - `plan.md`

## In progress
- None.

## Next actions
The work queue lives in **`plan.md`** (§3 tasks, §2 *Needs you*). The next task is **T-01** (`/setup-machine` on the new Mac), then T-02 to T-05.

## Decisions since review
- ADR-0003: Cloud Run region **us-central1** (cheapest tier; europe-west4 fallback).

## Blockers
- Licence answer (POC-0). Blocks paid launch, not the POC spike.

## Key numbers (verified; see 04 §15.1)
| Config | **us-central1** (Tier 1, ADR-0003) | Singapore (not used) |
|---|---|---|
| L4 8 vCPU/32 GiB | $1.4209/h | $1.7051/h |
| RTX PRO 6000 20/80 | $3.1868/h | $3.8241/h |
