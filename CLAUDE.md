# AI Video Generation Platform

Pre-code stage. Architecture: `architecture-review/04-final-architecture.md` is authoritative. ADRs in `docs/adr/` override it.

Work queue: `plan.md` (protocol plus tasks). Follow its protocol whenever asked to "execute" or "continue" the plan.

## Load context on demand. Don't read everything.
- Start of a session: read `docs/context/current-state.md` only.
- Architecture question: `docs/context/project-brief.md`, then the relevant section of 04.
- Before designing a component: check `docs/context/open-questions.md` and `docs/context/decisions.md`.
- Read `architecture-review/01–03` only when you need the source behind a claim.
- Folders carry their own `CLAUDE.md` with local rules. They load automatically when you work there.

## Always
- Never invent benchmark, runtime or per-video cost numbers. Measured numbers go in `docs/poc/` with a linked log.
- Never commit secrets, model weights or media (see `.gitignore`).
- A change that contradicts 04 or an ADR needs a new ADR first (`/adr`).
- End of session, or after a milestone: run `/handoff` to update `docs/context/current-state.md`.

## graphify
- Codebase questions: try `graphify query "<q>"`, `graphify path "<A>" "<B>"` or `graphify explain "<X>"` before broad reads. Read `graphify-out/GRAPH_REPORT.md` only for a wide architecture view.
- After code changes: `graphify update .` (AST-only, no API cost).
