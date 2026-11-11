# ADR-0003: Cloud Run region is us-central1 (Iowa)

| Field | Value |
|---|---|
| Status | **Accepted** (decided by the user, 2026-11-11) |
| Date | 2026-11-11 |
| Supersedes | 04-final-architecture §1 "Primary region europe-west4" and decision R-D10; resolves U-2 / OQ-12 |

## Context
- Generation is asynchronous batch work, so user latency doesn't matter. Cost decides the region.
- Singapore (asia-southeast1) is a Tier 2 region, priced at ×1.2 of Tier 1. [FACT] Cloud Run pricing, verified in the review.

## Decision
**All GCP resources for the platform live in `us-central1`:**
- Cloud Run GPU, TTS and render jobs
- the GCS `models` and `work` buckets
- the Artifact Registry repository

## Consequences
- **Prices** (Tier 1, see `/cost-estimate`):
  - L4 at 8 vCPU / 32 GiB: **$1.4209/h**
  - RTX PRO 6000 at 20 / 80: **$3.1868/h**

  These are 16.7% below Singapore.
- **Available for jobs in us-central1:** both L4 and RTX PRO 6000. [FACT] Cloud Run jobs GPU page, verified 2026-11-11.
- **Quota caveat [FACT]:** for L4, Google notes that in us-central1 "Additional resource scaling … might require a quota increase request." So in Phase 0, file the L4 and RTX PRO 6000 quota requests for us-central1 early (T-02c, U-5).
- **Fallback chain** (replaces 04 §17 row 1):
  1. Cloud Run **europe-west4** (same Tier 1 price, both SKUs)
  2. the other GPU SKU
  3. Modal / RunPod
  4. AWS g6/g6e

  asia-southeast1 is used only if a residency requirement ever appears.
- **Data residency:** user prompts, voices and videos are processed in the US. Disclose this in the privacy policy and terms. If an APAC residency requirement appears later, that needs a new ADR.
- Users download from Cloudflare R2, so delivery latency is unaffected by the GCP region.
- Upload latency for user media (images, voice samples) from India to Iowa is higher. It is acceptable for async jobs; measure it in Phase 5.
