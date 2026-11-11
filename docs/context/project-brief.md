# Project Brief (read this first)

**What:** a web-based AI video generation platform (Instagram Reels, YouTube 2–3+ min, custom formats). It is built to keep GPU spend low: the GPU is rented only while a job runs.

**Stage:** pre-code. The architecture has been reviewed, and the next step is the Phase 0 gates and the Phase 2 GPU POC spike.

## Sources of truth (in priority order)

| Doc | Role |
|---|---|
| `architecture-review/04-final-architecture.md` | **Authoritative architecture** (arbitrated). Wins on any conflict until an ADR changes it. |
| `architecture-review/05-implementation-roadmap.md` | Phases, POC register (POC-0…10), exit criteria |
| `architecture-review/06-decision-matrix.md` | Scored trade-offs behind each decision |
| `docs/adr/*` | Decisions made after the review (supersede 04 where stated) |
| `system_architecture_technical_specification.md` | Product/feature spec (dashboard, billing view, prompt enhancer, QA, CDN). Conflicts with 04 are tracked in `open-questions.md`. |
| `architecture.txt` | Original proposal (historical; superseded by 04) |
| `architecture-review/01–03` | Agent reviews and debate (evidence; read only when a claim's source is needed) |

## Architecture in 10 lines

1. **Control plane:** Oracle Always Free A1 (arm64) runs web, API, auth, Postgres, the Postgres-backed queue, the dispatcher and the reconciler. Cloudflare sits in front.
2. **GPU:** Cloud Run **GPU Jobs**, scale-to-zero, one region: **`us-central1`** (ADR-0003). Fallback region: `europe-west4`.
3. **GPU SKU:** decided by POC-3. Baseline RTX PRO 6000 96 GB (20 vCPU/80 GiB) vs cost-down L4 24 GB (**8 vCPU/32 GiB**).
4. **Model:** LTX-2.5 distilled via ComfyUI. A slim, hash-pinned set is copied from GCS to the **ephemeral disk**.
5. **Pipeline:** TTS (CPU job) → user approval → GPU job (≤45-min tasks, per-clip checkpoints, 1–2 retries) → render (CPU job, FFmpeg) → R2.
6. **Storage:** intermediates in the GCS `work` bucket (7-day lifecycle). Finals in **R2**, delivered via 15–60 min presigned URLs.
7. **Cost:** GA Cloud Run **spend cap** + per-user GPU-second quotas + an approval gate before GPU spend.
8. **Fallback:** second Cloud Run region → other GPU SKU → Modal/RunPod → AWS g6/g6e (after quota).
9. **Blocking gate:** LTX-2.x licence Attachment A item 20 ("directly competes"). Needs a written answer from Lightricks.
10. **No per-video cost figure exists** until POC-10. Never quote one.

## Glossary

- **Dispatcher:** writes the `dispatching` state plus an idempotency key, then calls Cloud Run `RunJob`.
- **Reconciler:** a cron that syncs the DB with Cloud Run executions and GCS done-markers.
- **Done-marker:** a GCS object written after each clip completes. It makes retries resumable.
- **Slim set:** only the model files the chosen workflow needs, listed in a SHA-256 manifest.
- **Tier 1 / Tier 2:** Cloud Run price tiers. Singapore is ×1.2 of Iowa and Netherlands.
