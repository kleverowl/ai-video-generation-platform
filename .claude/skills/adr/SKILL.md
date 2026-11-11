---
name: adr
description: Create or update an Architecture Decision Record. Use when a technical decision is made or proposed, when resolving an item in docs/context/open-questions.md, or before any change that contradicts architecture-review/04-final-architecture.md.
---

# ADR workflow

1. Find the next number: list `docs/adr/` and take the highest `NNNN` + 1.
2. Copy `docs/adr/0000-template.md` to `docs/adr/NNNN-kebab-title.md` and fill it in.
   - **Context:** link the OQ-n item, the POC, or the section of 04 it touches.
   - **Options:** at least two, each with evidence. Label every claim [FACT] (with a source URL or file), [REC], [POC], or [TRADE-OFF].
   - **Supersedes:** name the exact section of 04, or the earlier ADR, that this replaces.
3. Add or update the row in `docs/context/decisions.md`.
4. If the ADR resolves an open question, mark that item in `docs/context/open-questions.md` as `✅ Resolved → ADR-NNNN`.
5. If the decision creates a durable rule for one folder, add a single line to that folder's `CLAUDE.md`.

## Rules
- Status must be `Proposed` until the user explicitly accepts it.
- Check current official documentation for any vendor fact (limits, prices, regions) before writing it down. Do not rely on memory.
