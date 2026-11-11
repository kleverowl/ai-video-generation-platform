# ADR-0001: Adopt the reviewed architecture as the baseline

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-11-11 |
| Supersedes | `architecture.txt` (original proposal) |

## Context

The original proposal (`architecture.txt`) went through a three-round, two-agent architecture review with Chief Architect arbitration (`architecture-review/01–06`). The review found that the overall pattern is sound. However, it identified several errors in the details:

- **VRAM and RAM vs LTX-2.5 minimums:** 24 GB VRAM and 16 GiB RAM, where LTX-2.5 needs 32 GB+ VRAM and 32 GB RAM.
- **Timeouts and retries:** one 60–90 min execution with 0 retries.
- **Pricing tier:** the cost table applied Tier 1 rates to Singapore.
- **Container topology:** two images sharing one GPU execution.
- **Fallback chain:** Mumbai L4 is invitation-only, and the AWS GPU quota defaults to 0.
- **Licensing:** LTX-2.x item 20.

## Decision

`architecture-review/04-final-architecture.md` is the authoritative baseline. Any deviation requires a new ADR that names the section it supersedes.

## Consequences

- Phase 0 (licence and quotas) and the Phase 2 GPU spike come before product UI work.
- Open conflicts with `system_architecture_technical_specification.md` are tracked in `docs/context/open-questions.md` (OQ-1…OQ-10). Each one needs its own ADR.
