# Decisions Index

Short index only. Full reasoning lives in the linked ADR or review section.

**Status values:** ✅ accepted · 🟡 proposed/pending · ⛔ superseded · 🔬 decided by a POC

| ID | Decision | Status | Source |
|---|---|---|---|
| ADR-0001 | Adopt `architecture-review/04-final-architecture.md` as the baseline architecture | ✅ | `docs/adr/0001-baseline-architecture.md` |
| ADR-0002 | Backend language: FastAPI (Python) vs Node.js (TypeScript) | 🟡 | `docs/adr/0002-backend-language.md` |
| ADR-0003 | Cloud Run region us-central1 | ✅ | `docs/adr/0003-region-us-central1.md` |
| R-D1 | Cloud Run GPU Jobs as the MVP GPU platform | ✅ | 04 §1, 06 D1 |
| R-D2 | GPU SKU: RTX PRO 6000 baseline vs L4 cost-down | 🔬 POC-3 | 04 §2 |
| R-D3 | L4 shape: 8 vCPU / 32 GiB + ephemeral disk | ✅ | 04 §3 |
| R-D4 | Model staging path (copy to ephemeral disk vs baked image vs Direct VPC) | 🔬 POC-1/2 | 04 §6 |
| R-D5 | One GPU image (LTX only); TTS and render as CPU jobs | ✅ (TTS placement 🔬 POC-6) | 04 §8 |
| R-D6 | FFmpeg-only rendering for the MVP; Remotion later | ✅ | 06 D6 |
| R-D7 | Postgres queue + write-ahead state machine + reconciler | ✅ | 04 §4, §9 |
| R-D8 | Oracle A1 control plane, hardened (WAL backups to R2) | ✅ | 04 §9 |
| R-D9 | Intermediates in GCS, finals in R2 | ✅ | 04 §7 |
| R-D10 | Region: **us-central1** (fallback europe-west4) | ✅ | ADR-0003 |
| R-D11 | Fallback order: 2nd CR region → other SKU → Modal/RunPod → AWS | ✅ | 04 §17 |
| R-D12 | Tasks ≤45 min, per-clip checkpoints, retries 1–2 | ✅ | 04 §4.3, §14 |
| R-D13 | Licence gate 0 (LTX item 20) before paid launch | ✅ | 04 §0 |
