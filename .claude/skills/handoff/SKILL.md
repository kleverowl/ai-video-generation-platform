---
name: handoff
description: End-of-session or post-milestone context update. Use when the user says "handoff", "wrap up", "save progress", or "update context", or after finishing a phase, POC, or significant feature. Updates docs/context/current-state.md and places newly learned durable rules in the nearest folder-level CLAUDE.md, keeping the root CLAUDE.md minimal.
---

# Handoff: keep context current and minimal

Make the next session productive while loading as little context as possible.

## Steps

1. **Gather facts, not memory.**
   - Run `git status --short` and `git log --oneline -15`.
   - Review what was done this session.
2. **Rewrite `docs/context/current-state.md`** in place. Replace the sections; do not append a diary.
   - Last updated (today's date), Phase, Done (keep only the last ~5 milestones), In progress, Next actions (ordered), Blockers.
   - Keep it under ~80 lines. Older history lives in git.
3. **Decisions.** If a decision was made, make sure it has an ADR (use `/adr`) and a row in `docs/context/decisions.md`. If it resolves an item in `open-questions.md`, mark that item resolved with the ADR link.
4. **Durable rules learned** (a gotcha, a convention, a constraint discovered while working). Put each one in the **most specific** place:
   - It applies only to one folder → that folder's `CLAUDE.md`. Create the file if it is missing, and keep it under ~25 lines.
   - It applies to every task in the repo → root `CLAUDE.md`. This is rare. Root must stay under ~25 lines; if adding would exceed that, move something down into a folder file instead.
   - It is procedural ("how to do X") → a skill in `.claude/skills/`, not CLAUDE.md.
   - It is a one-off detail → nowhere. Git history is enough.
5. **Prune.** Delete any CLAUDE.md line you found stale or wrong during the session.
6. **Graph.** If code changed, run `graphify update .` (no LLM needed) so the knowledge graph stays current.
7. **Report** in 5 lines or fewer: what you updated, and the single next action.

## Rules
- Never record unmeasured numbers. Benchmarks go through `/poc-record`.
- Do not commit unless the user asks.
