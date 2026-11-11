# 06 — Decision Matrix

## How to read the scores

Each option is scored **1 (poor) to 5 (excellent)** on the criteria that matter for that decision. Weights follow the review priorities:

| Criterion | Weight | Criterion | Weight |
|---|---|---|---|
| Technical feasibility | 20 | Total cost of ownership (TCO) | 13 |
| Reliability | 15 | Security | 6 |
| Video-generation performance | 12 | Scalability | 5 |
| Operational simplicity | 12 | Maintainability | 5 |
| GPU utilisation | 8 | Vendor independence | 4 |

Some decisions don't touch every criterion. Each table uses only the criteria that apply, renormalised to 100. Every score is a judgement grounded in the cited evidence. Scores marked **†** depend on an open POC and may change once it is run. Weighted totals are out of 5.00.

---

## D1. GPU execution platform

| Criterion (wt) | Cloud Run GPU Jobs | Compute Engine G2 L4 VM (stop/start, models on PD) | GKE GPU node pool | Serverless GPU vendor (Modal / RunPod) | AWS EC2/Batch g6 / g6e |
|---|---|---|---|---|---|
| Feasibility (20) | 4: GA GPU jobs; L4 and RTX PRO 6000 in target regions; ephemeral disk + GPU undocumented † | 5: full control; any disk size | 4 | 4: same container works; vendor specifics | 3: G/VT quota **defaults to 0** |
| Reliability (15) | 3: 10 s SIGTERM on maintenance; best-effort zone failover | 3: 1 h maintenance notice; **zonal stockout on restart** | 4 | 3: third-party SLA varies | 3 |
| Performance (12) | 3: staging every execution † | 5: models warm on disk | 4 | 4 † | 4: local NVMe |
| GPU utilisation (8) | 5: billed only while running | 3: idle if not stopped promptly | 3 | 5 | 3 |
| Ops simplicity (12) | 5: no OS or drivers | 2: drivers, OS patching, start/stop orchestration | 1: cluster operations | 4 | 2: second cloud, IAM, AMIs |
| TCO (13) | 4: spend cap available; Tier 1 L4 8/32 $1.4209/h | 4: cheaper per busy hour (G2 price **unverified**); fixed PD cost | 2: cluster fee + overhead | 3 † pricing not verified in review | 4: g6 Mumbai $0.9664/h (AWS price data) |
| Security (6) | 5: service identity, no SSH | 3 | 4 | 3: third-party data handling | 4 |
| Scalability (5) | 4: quota 3 auto-granted | 2 | 5 | 4 | 4 |
| Maintainability (5) | 5 | 2 | 2 | 4 | 3 |
| Vendor independence (4) | 3: OCI image, portable | 3 | 4 | 3 | 3 |
| **Weighted** | **4.00** | **3.55** | **3.25** | **3.70** | **3.24** |

**Decision:** Cloud Run GPU Jobs for the MVP. The VM is the phase-2 option once staging exceeds 15% of billed time or usage passes about 100 busy GPU-hours a month. Modal/RunPod is fallback 3 and AWS is fallback 4.

**Decisive facts:**
- GA budget **spend caps cover Cloud Run but not Compute Engine**.
- AWS G/VT quota is 0 by default.
- A Cloud Run GPU task can be terminated on maintenance, so the job must checkpoint.

---

## D2. GPU model

| Criterion (wt) | **L4 24 GB, 8/32** | RTX PRO 6000 96 GB, 20/80 | L40S 48 GB (AWS g6e) | A10G 24 GB (AWS G5) | A100/H100 |
|---|---|---|---|---|---|
| Feasibility (24) | 2: below LTX official 32 GB+ minimum; needs community Q4/Q5 or offload † | 5: meets spec; NVFP4/bf16 official path | 5: meets spec | 2: same VRAM as L4, older architecture | 5, but not on Cloud Run jobs |
| Reliability (16) | 3: OOM risk at high resolution or frame count † | 5 | 4 | 3 | 4 |
| Performance (16) | 2 † | 5 † | 4 † | 2 | 5 |
| Cost / output-second (24) | ? †: $1.4209/h (Tier 1) | ? †: $3.1868/h; wins only if ≥ 2.24× faster | ?: $2.235/h (AWS, Agent 1) | 3 | 1: VM-only, highest rate |
| Ops (12) | 5: Cloud Run | 5: Cloud Run | 2: AWS | 2: AWS | 2 |
| Availability (8) | 4: 6 regions; Mumbai invitation-only | 4: 4 regions incl. Delhi | 3: quota 0 by default | 3 | 2 |
| **Weighted (cost as 3 placeholder; A100/H100 = 1)** | **2.92** | **4.44** | **3.68** | **2.48** | **3.28** |

**Decision:**
- **POC baseline:** RTX PRO 6000.
- **Cost-down candidate:** L4 8/32.
- **Production pick:** whichever has the lowest measured **$/output-second** that passes the quality bar.
- **Dropped:** A10G.

The L4's low score reflects **unproven** feasibility, not a proven failure. POC-3 can raise it, so this matrix must not be used to rule the L4 out before testing.

---

## D3. CPU / RAM for the GPU job

| Option | Evidence | Verdict |
|---|---|---|
| 4 vCPU / 16 GiB (original) | The L4 minimum on Cloud Run. LTX requires 32 GB of system RAM. The in-memory filesystem counts against RAM. | **Reject** |
| **8 vCPU / 32 GiB** | Meets LTX's RAM minimum. Leaves room for ComfyUI offload. | **Adopt** (L4 arm) |
| 20 vCPU / 80 GiB | Platform minimum for the RTX PRO 6000 | Adopt (RTX arm) |

---

## D4. Model loading: GCS access vs persistent local cache

| Criterion (wt) | GCS FUSE direct reads | **Parallel copy → ephemeral disk (default egress)** | Copy via Direct VPC + PGA | Models baked into image | Persistent disk on warm VM |
|---|---|---|---|---|---|
| Feasibility (25) | 4 | 4: ephemeral disk + GPU job undocumented † | 4 † | 4: very large image † | 5 |
| Performance (25) | 2: random reads during load | 3 † (throughput undocumented) | 3: **capped at 1 Gbps**; startup delay ≥ 1 min | 4 † (image streaming) | 5 |
| Ops simplicity (20) | 4 | 4 | 2: VPC, PGA, maybe NAT | 3: rebuild on every model change | 2: VM operations |
| TCO (20) | 4: free same-region transfer | 4 | 3: NAT/startup billed GPU time | 4 | 3: fixed disk cost |
| Reliability (10) | 3 | 4 | 3 | 4 | 4 |
| **Weighted** | **3.40** | **3.75** | **3.05** | **3.80** | **3.90** |

**Decision:**
- **MVP:** test the ephemeral-disk copy and the baked image head to head (POC-2) and pick the faster.
- **Phase 2:** move to a persistent disk on a warm VM once its triggers fire.
  - The warm-VM persistent disk scores highest on raw performance (3.90). It is still deferred because its advantage only pays off at sustained volume, and it gives up spend-cap coverage and adds VM operations (see D1). At "a handful of videos per month", idle disk and VM overhead outweigh a few minutes of staging per execution.
- **FUSE direct reads:** benchmark arm only.
- **Direct VPC:** used only if POC-2 shows a clear gain.

Re-downloading the full ~50 GB set on every execution is rejected. Only the slim, pinned working set is staged.

---

## D5. Single GPU worker vs separate GPU workers

| Criterion (wt) | Two images in one GPU execution (original) | **One GPU image (LTX only); TTS and render on CPU jobs** | Separate GPU jobs for LTX and for TTS/Whisper | Unified GPU image incl. TTS + Whisper |
|---|---|---|---|---|
| Feasibility (30) | 1: "the GPU can only be attached to one container" | 5 | 5 | 5 |
| GPU utilisation (20) | n/a | 5: GPU does GPU-only work | 2: a second cold start and staging | 3: GPU idles during CPU-capable work |
| Simplicity (20) | 1 | 4 | 3 | 4 |
| TCO (20) | n/a | 5 | 2 | 3 |
| Reliability (10) | 1 | 4 | 4 | 3: one larger failure domain |
| **Weighted** | **≈1.0** | **4.70** | **3.30** | **3.80** |

**Decision:** a single GPU image dedicated to LTX. TTS runs as a CPU job by default; POC-6 decides whether it stays there or becomes the first GPU stage. Whisper or forced alignment runs on CPU in the render job.

---

## D6. Rendering

| Option | Feasibility | Cost | Simplicity | Verdict |
|---|---|---|---|---|
| Render on the GPU instance | Works | Wastes about $0.81/h of L4 time in Singapore | Simple | Reject |
| **FFmpeg-only on a Cloud Run CPU job** | Proven toolchain | CPU rates only. No licence. | High | **Adopt for MVP** |
| Remotion (`@remotion/renderer`) on a CPU job | Works. Needs Chrome and more RAM. | Paid licence above 3 employees ($100/mo minimum) | Medium | Add later if templated motion graphics are needed |
| `@remotion/cloudrun` | "Alpha … not actively being developed" | — | — | Reject |
| Remotion Lambda (AWS) | Works | Second cloud | Low | Reject for MVP |

---

## D7. Queue: Oracle-hosted vs managed

| Criterion (wt) | In-memory/ad-hoc queue on Oracle (as implied) | **Postgres queue (SKIP LOCKED / pg-boss) + state machine + reconciler** | Google Pub/Sub or Cloud Tasks | AWS SQS | Redis/BullMQ on Oracle |
|---|---|---|---|---|---|
| Reliability (30) | 2: lost on restart | 4: durable; correctness comes from the reconciler | 5 | 5 | 3: extra process; persistence must be configured |
| Simplicity (25) | 3 | 5: Postgres already exists | 3: another service plus auth from Oracle | 2: another cloud | 3 |
| TCO (20) | 5 | 5 | 4: free tier likely sufficient (not verified in review) | 4 | 5 |
| Fit at 1–3 GPU concurrency (15) | 3 | 5 | 3: over-built | 3 | 4 |
| Vendor independence (10) | 5 | 5 | 2 | 2 | 5 |
| **Weighted** | **3.30** | **4.70** | **3.70** | **3.45** | **3.75** |

**Decision:** a Postgres-backed queue. The **reconciler**, not the queue product, is what prevents orphaned or duplicate GPU executions. Move to a managed queue only if there are multiple dispatchers or throughput outgrows Postgres polling.

---

## D8. Control plane hosting

| Option | Cost | Reliability | Verdict |
|---|---|---|---|
| **Oracle Always Free A1 (hardened: WAL to R2, runbook, uptime check, Cloudflare)** | $0 | No SLA. Single VM. Idle reclamation unlikely with p95 CPU, network and memory all above 20%. | **Adopt for MVP/beta** |
| Oracle as-is (no off-box backups) | $0 | Only 5 free volume backups. Data loss risk. | Reject |
| Managed Postgres + small VM | Low monthly fee | Higher | Re-evaluate before taking payments, or if the restore drill fails RTO |

---

## D9. Output storage

| Criterion (wt) | **R2 for finals; GCS for intermediates** | R2 for everything (original) | GCS + Cloud CDN for everything | Backblaze B2 |
|---|---|---|---|---|
| TCO (35) | 5: zero R2 egress to users; free same-region GCS for intermediates | 3: GCP→internet egress (~$0.12/GiB) on every intermediate, plus NAT if Direct VPC is used | 2: internet egress to users is billed | 4 † (pricing not verified in review) |
| Simplicity (25) | 4: two stores, clear split | 5 | 4 | 3: another vendor |
| Security (15) | 5: GPU job has no internet path; presigned URLs | 4 | 5 | 4 |
| Performance (15) | 5: intermediates local to compute | 3 | 5 | 3 |
| Vendor independence (10) | 4: S3 API | 4 | 3 | 4 |
| **Weighted** | **4.65** | **3.75** | **3.50** | **3.60** |

**Decision:** keep R2 for user-facing finals. Move intermediates to same-region GCS.

---

## D10. Region

| Option | L4 8/32 rate | GPU SKUs for jobs | Notes | Verdict |
|---|---|---|---|---|
| **europe-west4** | $1.4209/h | L4 and RTX PRO 6000 | No quota caveat listed | **Default**, unless APAC residency is required |
| us-central1 | $1.4209/h | L4 and RTX PRO 6000 | L4 "might require a quota increase" | Secondary option |
| asia-southeast1 | $1.7051/h | L4 and RTX PRO 6000 | 20% surcharge | Primary only if residency is required; otherwise fallback 1 |
| asia-south1 (Mumbai) | — | L4 by **invitation only** | — | Not plannable |
| asia-south2 (Delhi) | (not verified) | RTX PRO 6000 only | — | Candidate if India residency plus the RTX arm wins |

---

## D11. GPU fallback provider

| Order | Option | Ready time | Key constraint |
|---|---|---|---|
| 1 | Cloud Run, second region | Hours (pre-provisioned) | Its own quota grant |
| 2 | Cloud Run, other GPU SKU | Minutes (one flag) | Separate model manifest |
| 3 | Modal / RunPod | Days (adapter) | No spend-cap equivalent; vendor limits |
| 4 | AWS g6 / g6e (ap-south-1) | Weeks (quota) | **G/VT quota defaults to 0.** Second cloud. |
| — | AWS G5 (A10G), as in the original | — | **Dropped.** No advantage over L4; below LTX spec. |

---

## D12. Retry, timeout and concurrency

| Setting | Original | Final | Evidence |
|---|---|---|---|
| Task timeout | 60–90 min | **≤ 45 min per task** | Google recommends ≤1 h. Over 1 h is Preview. Maintenance terminates GPU tasks. |
| Retries | 0 | **1–2, with per-clip checkpoints** | Spend cap and maintenance kill in-flight work |
| Concurrency | 1 | 1 at launch, configurable up to quota (3) | Auto-granted quota |
| Fallback trigger | Capacity only | Capacity only (kept) | Correct in the original |

---

## Summary of verdicts

| Decision | Original choice | Final choice | Changed? |
|---|---|---|---|
| D1 Platform | Cloud Run Jobs | Cloud Run Jobs | Kept |
| D2 GPU | L4 | RTX PRO 6000 baseline vs L4 cost-down (POC) | **Conditional** |
| D3 CPU/RAM | 4/16 | 8/32 | **Changed** |
| D4 Model loading | GCS FUSE or copy | Copy to ephemeral disk or baked image (POC) | **Changed** |
| D5 Workers | 2 images / 1 GPU job | 1 GPU image + CPU jobs | **Changed** |
| D6 Rendering | Remotion + FFmpeg | FFmpeg-only MVP | **Changed** |
| D7 Queue | Oracle queue | Postgres queue + reconciler | **Refined** |
| D8 Control plane | Oracle | Oracle, hardened | Kept |
| D9 Output | R2 | R2 finals + GCS intermediates | **Refined** |
| D10 Region | Singapore | europe-west4 (residency permitting) | **Changed** |
| D11 Fallback | Mumbai CR → AWS G5 | 2nd region → SKU → Modal/RunPod → AWS g6/g6e | **Changed** |
| D12 Retry/timeout | 0 / 60–90 min | 1–2 / ≤ 45 min tasks | **Changed** |
