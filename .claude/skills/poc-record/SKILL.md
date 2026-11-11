---
name: poc-record
description: Record a proof-of-concept or benchmark result (POC-0 to POC-10 from the roadmap, or a new one) with evidence. Use whenever a measurement is taken (VRAM, seconds per clip, staging time, render time, cost per minute, quota grant) or a POC passes or fails.
---

# POC evidence record

1. File: `docs/poc/POC-<n>-<short-name>.md`. Create it or update it.
2. Required sections:
   - **Question:** copy it from the POC register in `architecture-review/05-implementation-roadmap.md`.
   - **Pass criterion:** copy it verbatim from the roadmap.
   - **Setup:** region, GPU SKU, vCPU/RAM, image digest, model manifest hash, workflow JSON version, resolution, frame count, seeds.
   - **Results table:** every number links to a raw log in `docs/poc/raw/` (git-ignored) or to a Cloud Logging query or execution ID.
   - **Verdict:** PASS, FAIL or INCONCLUSIVE, plus the decision it unlocks (e.g. R-D2 GPU SKU).
   - **Cost of the test:** billed seconds × the verified rate.
3. If the POC decides something, run `/adr` and update `docs/context/decisions.md`.

## Hard rules
- **No number without a log.** If a value is estimated, label it `ESTIMATE` and explain how it was derived.
- Report failures and OOMs as plainly as successes.
- Never extrapolate a per-video price from a single clip without stating the formula (see 04 §15.2).
