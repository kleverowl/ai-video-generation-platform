# Open Questions

Conflicts between `system_architecture_technical_specification.md` (the "Spec") and `architecture-review/04-final-architecture.md` (the "Review"), plus other undecided items.

**Resolve each one with an ADR before coding the affected component.**

**Labels:** [FACT] verified with a source · [REC] recommendation · [VERIFY] not yet checked.

---

## Blocking: resolve before Phase 1 coding

### OQ-1: Database: "Oracle Database" (Spec §2.2) vs PostgreSQL on the Oracle VM (Review)

- **Spec:** "Oracle Database / Cloud Infrastructure" for user state, sessions and logging.
- **Review:** PostgreSQL 16 on the Oracle Always Free A1 VM. It also hosts the job queue and state machine, using `SKIP LOCKED` / pg-boss.
- **Question:** did the Spec mean *Oracle Cloud Infrastructure hosting* (consistent with the Review) or *Oracle Database* the product?
  - Oracle offers Always Free Autonomous Database instances [VERIFY current limits].
  - Those instances would lose the Postgres queue tooling and the pg-boss/WAL-G backup path the Review relies on.
- **Recommendation [REC]:** PostgreSQL on the OCI VM. It is one engine for app state, the queue and job events.

### OQ-2: Video asset storage: GCS (Spec §2.2) vs R2 for finals (Review)

- **Spec:** GCS for "video assets, temporary rendering chunks, and model checkpoints". Cloudflare CDN for outputs (§5.4).
- **Review:** GCS for models and intermediates, which agrees with the Spec. **R2 for final user-facing videos.**
  - GCS internet egress is billed at about $0.12/GiB [FACT, per review].
  - R2 has zero egress [FACT, R2 docs].
  - Cloudflare's CDN does not remove GCS egress charges when the origin is GCS.
- **Recommendation [REC]:** keep the Review split. Spec §5.4 (Cloudflare delivery) is satisfied naturally by R2.

### OQ-3: "On-Demand / Preemptible GPU Instances" on Cloud Run (Spec §3.1)

- The Cloud Run jobs GPU page reviewed on 2026-11-11 lists only L4 and RTX PRO 6000. It has **no preemptible or spot option**. The cost levers it documents are non-zonal redundancy (cheaper) and "delayed jobs", which discount CPU and memory only. [FACT, per review]
- Preemptible or Spot GPUs exist on **Compute Engine VMs**, which is the phase-2 option in the Review. [VERIFY current Spot G2 availability]
- **Recommendation [REC]:** remove "preemptible" from the MVP spec. Note it as a phase-2 VM option.

### OQ-4: "Real-time accrued cost via the Cloud Billing API" (Spec §4.2)

- [FACT] Google's billing docs (fetched 2026-11-11) say that **cost data is accessed through the BigQuery billing export**, which updates "automatically throughout the day". It is not real time. The Pricing API returns *prices*, not incurred costs.
- [VERIFY] The Cloud Billing API itself manages accounts and project links. It does not appear to return accrued spend.
- [VERIFY] BigQuery query costs, and the free tier for small billing datasets.
- **Recommendation [REC]:** the dashboard shows two numbers:
  - **(a) Live estimated cost**, computed by the app as GPU/CPU/RAM seconds × the verified unit rates per job. This is instant and free.
  - **(b) Reconciled actual cost**, from the BigQuery export, refreshed by the existing manual refresh button with server-side caching. This lags by hours.

  Label them clearly. The **spend cap** remains the hard limit.

## Important: resolve before Phase 4

### OQ-5: Backend language: FastAPI vs Node/TS (Spec §2.1)
- Tracked as ADR-0002.
- Inputs to the decision:
  - The workers are Python.
  - The frontend is Next.js (TS).
  - The Oracle VM is arm64; check wheel availability.
  - Team skills.
  - pg-boss is Node-native; the Python equivalent is a `SKIP LOCKED` loop or procrastinate [VERIFY].

### OQ-6: Dashboard GPU utilisation and memory metrics (Spec §4.1)
- [VERIFY] whether Cloud Monitoring exposes GPU utilisation and memory for **Cloud Run jobs** containers.
- Fallback [REC]: the worker samples `nvidia-smi` / NVML every N seconds and emits structured logs or metrics keyed by `job_id`. The Review requires `peak_vram` logging anyway.

### OQ-7: Terminate / Cancel / Force-Stop (Spec §4.1)
- Map these to Cloud Run `executions.cancel`, which the dispatcher SA is already granted in 04 §10.
- Define what "paused" means. Cloud Run executions cannot be paused; a "pause" is only a queue-level hold.
- Cancelling mid-job: are completed clips kept (resumable) or deleted?

### OQ-8: Prompt Enhancer (Spec §5.1) vs "LTX prompt enhancer OFF" (Review)
- These do not conflict once the placement is clear.
  - The Review disables LTX's built-in Gemma enhancer **inside the GPU job**, because it is an extra model load and costs VRAM and time.
  - The Spec's enhancer should run **before dispatch**: an LLM API call or a CPU step on the API side. The user then sees the enhanced prompt at the approval gate.
- Decide: which LLM or provider, cost per call, and moderation of the enhanced text.

### OQ-9: "Hot-swapping script modules" (Spec §5.3)
- Security risk [REC]: loading arbitrary code into running workers bypasses image pinning and supply-chain controls.
- **Recommendation:** use **configuration-driven feature flags** plus versioned workflow JSONs and images deployed by digest. "Skills" become data, not code.

### OQ-10: Automated QA (Spec §5.2)
- Define the concrete checks:
  - ffprobe resolution and duration
  - A/V sync tolerance (±200 ms, from roadmap Phase 3)
  - loudness ±1 LU
  - black or frozen frame detection
- Decide where they run: in the render job, before the R2 upload.

## Pending external answers
- **OQ-11:** Lightricks licence item 20 (POC-0).
- **OQ-12:** ✅ Resolved → ADR-0003. Region is us-central1; data is processed in the US.
- **OQ-13:** TTS engine and its weights licence.
