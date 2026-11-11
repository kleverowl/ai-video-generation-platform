# Architecture Review, Round 1: Agent 2 (Critical Infrastructure Reviewer)

| Field | Value |
|---|---|
| Role | Independent Principal DevOps Engineer and AI Infrastructure Architect, acting as critical infrastructure reviewer |
| Date | 2026-11-10 (research carried out 2026-11-10/11) |
| Document reviewed | `architecture.txt`, "Complete Video Generation Platform – System Architecture & Infrastructure Plan" |
| Scope | GPU platform choice, model fit (VRAM/RAM), model storage and loading, pipeline topology, voice/ASR, rendering, control plane on Oracle Always Free, queueing/retries, output storage, fallback, hidden costs, security/licensing |
| Independence | I did not read Agent 1's review. Everything here is my own work. |
| Method | I read official documentation: docs.cloud.google.com (Cloud Run GPU jobs, task timeout, container contract, ephemeral disk, Cloud Storage FUSE volume mounts, GPU best practices, locations/pricing tiers, release notes, Compute Engine GPU zones), Lightricks GitHub and Hugging Face (LTX-2 repo, LTX-2.5 model card, LICENSE-2_x, ComfyUI-LTXVideo), Oracle Always Free docs, the AWS EC2 quota docs, Cloudflare R2 pricing, the Remotion license, remotion.pro and the Cloud Run docs, faster-whisper, the VoiceStudio and OmniVoice repos, NVIDIA's L4 page, and Modal and RunPod pricing. Third-party sources are marked as such. |

**Labels used throughout.** CONFIRMED FACT means verified against a cited source on the access date. ASSUMPTION means my reasoning, not verified. NEEDS BENCHMARK/POC means it can only be settled by measurement. I have **not** invented any LTX-2.5 runtime figure on L4. Every runtime-dependent cost below is parametric, and I mark which ones are hypothetical.

---

## Executive summary

1. **License risk outranks infrastructure risk (Critical).** LTX-2.5 exists: Lightricks lists it as the recommended model, a 22B DiT with a Gemma 4 12B text encoder. Its LTX-2.x Community License allows commercial use below $10M revenue. However, Attachment A item 20 forbids using it "in any product, service, or application that directly competes with Licensor's commercial products or services … without obtaining a separate commercial license". Lightricks sells its own AI video creation product. A public AI video generation SaaS is plausibly inside that clause. Get written clearance or a commercial licence from Lightricks before building on it.
2. **The Cloud Run GPU job timeout is 1 hour at GA. Up to 12 hours is Preview only (since 2026-10-30).** GPU tasks are not live-migrated: maintenance terminates them, and Google says multi-hour tasks "should be expected to be interrupted at least once". The proposed 60–90 min timeout with **0 retries** and **one monolithic execution per 2–3 min video** is therefore the wrong shape. Split the work into per-clip (or per-batch) tasks, checkpoint to object storage, and enable retries.
3. **4 vCPU / 16 GiB is only the minimum Cloud Run allows for L4.** Google recommends 8 vCPU / 32 GiB. Cloud Run's default writable filesystem lives in memory, so a roughly 25–30 GB quantised model set (and the 66 GiB official bf16 bundle even more so) cannot be staged in 16 GiB of RAM. The design needs the newly GA **Cloud Run ephemeral disk**: GA 2026-11-04, max 100 Gi per volume, **regional quota 0 GiB by default**, and GPU compatibility not stated. It also needs a RAM bump to at least 32 GiB.
4. **24 GB L4 is below Lightricks' own ComfyUI guidance.** ComfyUI-LTXVideo lists "CUDA-compatible GPU with 32GB+ VRAM" as a prerequisite, and its low-VRAM loaders target "fits in 32 GB". Q4 GGUF quants are **community-made**, not official. Fitting LTX-2.5 on an L4 at the target resolution and duration is **unproven and a gating POC item**. Lightricks' official quantised paths are the int8-convrot (ComfyUI) and FP8-cast variants. FP8 suits L4 (Ada); NVFP4 needs Blackwell.
5. **The "separate Docker images, one sequential GPU execution" plan cannot work as described.** A Cloud Run job task runs one container image, and with sidecars "the GPU can only be attached to one container". Either build one unified GPU image or run separate executions. Better still: **move TTS and Whisper off the GPU** and generate narration **first**, because audio duration should drive clip count and timing.
6. **Use Compute Engine for long videos; Cloud Run Jobs suits Reels-length work.** For 2–3 min videos, a stop/start **Compute Engine G2 (L4) VM with a persistent disk that already holds the models** (or a spot VM with checkpointing) avoids the 1 h cap, the per-execution 25–66 GB re-download and the in-memory FS problem. Cloud Run Jobs is a reasonable fit for short Reels.
7. **The Oracle Always Free control plane is acceptable for a beta but is a single point of failure with no SLA.** Postgres needs off-box backups (only 5 free volume backups exist). The idle-reclamation rule (all three of p95 CPU, network and memory below 20% over 7 days, for A1) must be understood and monitored.
8. **The cost model understates cost.** The doc's $1.0465/h is the **Tier 1** price, but `asia-southeast1` is **Tier 2**, so CPU costs about 20% more ($0.0000216 vs $0.000018 per vCPU-second). The doc also uses the minimum 4/16 shape and assumes 7.5 min per video. A 2–3 min video at 5–10 s per clip is 15–30 LTX generations. Hidden items include GCP→R2 internet egress (~$0.12/GiB, Asia premium tier), Cloud NAT if Direct VPC egress is used for FUSE, and Remotion licensing ($100/month minimum if the company has more than 3 employees).
9. **VoiceStudio is identifiable but is the wrong building block.** It is `debpalash/VoiceStudio`, an **AGPL-3.0 desktop/server app** whose default engine is k2-fsa OmniVoice. For a SaaS, embed the underlying engine directly after checking its weights licence, or use a TTS API. Use faster-whisper on CPU (MIT licence), or skip ASR entirely and do forced alignment of the known script.
10. **Fallback.** AWS G5/G6 start with a **0 vCPU quota** for "Running On-Demand G and VT instances" and for spot. Request quota now or the fallback is fictional. G6 (L4) is the more like-for-like fallback than G5 (A10G, no FP8 tensor cores). A serverless GPU vendor (Modal or RunPod) is a cheaper-to-integrate second provider.

---

## Findings per investigation item

### 1. Is Cloud Run Jobs the best fit for this GPU workload?

**Finding.**
- GPU support for Cloud Run Jobs is **GA since 2025-10-21**.
- L4 job regions are: `asia-southeast1`; `asia-south1` (**"available by invitation only"**); `europe-west1`; `europe-west4`; `us-central1`; `us-east4`.
- The RTX PRO 6000 (96 GB) is available for jobs in `asia-southeast1`, `asia-south2`, `europe-west4` and `us-central1`.
- New projects get **3 L4 GPUs of quota (zonal redundancy off)** per region, "subject to availability".
- Jobs support **only** non-zonal-redundant GPUs. Failover is best effort: "Cloud Run routes job executions to other zones only if sufficient GPU capacity is available at that moment."
- The max task timeout for GPU tasks is **1 hour (GA)**, or **12 hours in Preview** (release note dated 2026-10-30).
- GPU tasks are **not live-migrated**: "routine infrastructure maintenance terminates them".
- GPU is "billed for the entire duration of the instance lifecycle". That includes model download and initialisation.
- Instances start in about 5 s, with drivers pre-installed (driver 580.x, CUDA 13.0). The container image pull and the model load come on top of that.

**Evidence.**
- https://docs.cloud.google.com/run/docs/configuring/jobs/gpu
- https://docs.cloud.google.com/run/docs/configuring/task-timeout
- https://docs.cloud.google.com/run/docs/release-notes
- https://docs.cloud.google.com/run/quotas, with the 1 h figure taken from the quotas and task-timeout pages as surfaced by search

**Classification.** Confirmed fact (limits). Evidence-supported recommendation (fit).

**Severity.** High.

**Analysis and recommended alternative.** Cloud Run Jobs is a good fit for **bounded, under-1-hour units of work**: one Reel, or one batch of N clips. It is a poor fit for "one execution renders an entire 2–3 min video", because:
- the GA cap is 1 h;
- the preview 12 h mode is explicitly interruption-prone;
- every execution re-stages tens of GB of models.

Options compared:

| Option | Pros | Cons |
|---|---|---|
| **Cloud Run Jobs (as proposed)** | No VMs to manage, scales to zero, 3-GPU default quota, per-task env overrides | 1 h GA cap; re-download models every execution; in-memory FS; no zonal-redundancy option for jobs; GPU billed during staging |
| **Compute Engine G2 VM (L4), stop/start, models on persistent disk** | Models stay on disk, so no re-download; no runtime cap; full control (NVMe/PD, RAM sizing, `g2-standard-8` = 8 vCPU/32 GB); spot option | You manage the VM image and drivers; stopped VMs still bill for disk; GPU quota for GCE must be requested (ASSUMPTION: new projects usually have 0 `GPUS_ALL_REGIONS`, so verify); start latency NEEDS BENCHMARK; a Singapore on-demand price of about $0.872/h for g2-standard-4 comes from a third party (Holori), so verify on the official page |
| **GKE (Autopilot or Standard with an L4 node pool scaled to 0)** | Image streaming, PV with models, queue-driven autoscaling | Control-plane fee and operational overhead are disproportionate for 1–3 concurrent GPUs |
| **Modal** | L4 $0.000222/s GPU; CPU $0.0000131/physical core·s; memory $0.00000222/GiB·s; volumes and snapshots; $30/month free credits | Region pinning costs 1.15–1.75×; another vendor; data residency |
| **RunPod** | Serverless 24 GB group (L4/A5000/3090) $0.75/h; pods L4 $0.59/h (secure); network volumes $0.07/GB-month | Variable host quality (community cloud); cold-start behaviour NEEDS BENCHMARK |

**Recommendation.**
- Keep Cloud Run Jobs for short-form work, but redesign it as **one task per clip batch** (well under 1 h) with checkpointing.
- For long-form work, run a POC of a **stop/start G2 VM that pulls from the queue**. It has no cap and no re-download.
- Decide on cost per finished minute after the benchmark, not before.

### 2. Is L4 24 GB sufficient for LTX-2.5? Does "LTX-2.5 22B" exist?

**Finding.** **Yes, it exists.**
- The LTX-2 repo states: "LTX-2.5 is the recommended model". LTX-2.3 is now legacy.
- The filenames show a **22B** transformer (`ltx-2.5-22b-distilled-transformer-bf16`, `ltx-2.5-22b-dev-transformer-bf16`).
- The text encoder is **Gemma 4 12B, fine-tuned, with projection** (`gemma4-12b-with-proj-ltx-2.5-bf16`).
- There are separate video VAE (diffusion and conv variants), audio VAE plus vocoder, spatial/temporal x2 latent upscalers and a duration head.
- The model generates **joint audio and video**.
- The full download is "roughly **66 GiB**".
- Constraints: `num_frames % 8 == 1`, width and height divisible by 32. The examples are 1920×1088 at 121 frames (about 5 s at 24 fps). No maximum duration is stated.

**Quantisation.**
- Official options: the ComfyUI **int8 + convrot** DiT and text encoder, **NVFP4** (Blackwell only) and runtime `--quantization fp8-cast` with `--offload cpu|disk`.
- **No official GGUF.** The Q4 GGUFs are community repos (unsloth, agosh, etc.). Third-party sizes for distilled Q4_K_M are about 13.6–15.7 GB, and a Gemma-4 encoder at Q5_K_M is about 9.5 GB.

**VRAM guidance.**
- The LTX-2.5 model card gives no VRAM figure.
- ComfyUI-LTXVideo lists **"CUDA-compatible GPU with 32GB+ VRAM"** as a prerequisite, and its low-VRAM loaders aim to make generation "fit in 32 GB VRAM".

**Arithmetic (ASSUMPTION, plain bytes × params).**

| Component | bf16 | FP8 | Q4 GGUF |
|---|---|---|---|
| 22B DiT | ≈ 44 GB | ≈ 22 GB | ≈ 13–16 GB |
| 12B text encoder | ≈ 24 GB | ≈ 12 GB | n/a |

Even at Q4 DiT plus FP8 text encoder (≈ 25–28 GB), the two **cannot be co-resident** on 24 GB with activations, VAE decode and the CUDA context. ComfyUI must encode text, evict the encoder, then load the DiT. That needs system RAM (or disk) to hold the evicted weights, which makes item 3 a hard dependency. VAE decoding at 1080p over 121+ frames needs tiled decode. LTX-2.5's "multishot" and longer-duration features increase latent token counts, and memory grows with resolution × frames.

**Licence.**
- Free commercial use applies only to entities with **annual revenue under $10M**, aggregated across affiliates.
- **Item 20** prohibits competing products without a separate licence.
- **Item 19** prohibits circumventing "watermarking, content provenance" features.
- Licensor claims no rights in outputs.

**Evidence.**
- https://github.com/Lightricks/LTX-2
- https://huggingface.co/Lightricks/LTX-2.5
- https://github.com/Lightricks/LTX-2/blob/main/LICENSE-2_x
- https://github.com/Lightricks/ComfyUI-LTXVideo
- Community quants (third party): https://huggingface.co/unsloth/LTX-2.5-GGUF

**Classification.** Model existence and licence text: confirmed fact. VRAM fit: **NEEDS BENCHMARK/POC**. Competition-clause interpretation: legal judgment, an assumption that requires counsel.

**Severity.** **Critical** (licence), **High** (VRAM fit).

**Recommended alternative.**
- (a) Get written confirmation or a commercial licence from Lightricks.
- (b) Run the POC with the **distilled** DiT (8 steps, CFG=1), the **official int8/FP8** checkpoints rather than community Q4 (official checkpoints have supported quality and licence lineage; L4 has FP8 tensor cores), the **conv VAE**, single-stage at 720p, and then upscale.
- (c) Measure peak VRAM, peak RAM and wall time per clip at each target resolution and duration.
- (d) Keep the **Cloud Run RTX PRO 6000 (96 GB)** in Singapore as an evaluated option. It removes VRAM gymnastics but requires a minimum of 20 vCPU / 80 GiB. Its price is not verified here and NEEDS PRICING CHECK.

### 3. Are 4 vCPU / 16 GiB sufficient?

**Finding.** No, for this model. On L4, Cloud Run requires "a minimum of 4 CPU and 16 GiB of memory" and the services page **recommends 8 CPU and 32 GiB**. The container filesystem "is an in-memory file system, so writing to it uses the instance's memory", and you cannot cap it. A container exceeding its memory "is terminated". Cloud Storage FUSE caches (`cache-dir` on an in-memory volume, buffered reads) are "counted under container memory limits".

The staging needs exceed 16 GiB on their own: roughly 25–30 GB of quantised models, more for bf16 or FP8. In addition, ComfyUI holds offloaded weights in system RAM (text encoder or DiT swap), plus Python/torch overhead, plus decoded frames.

The new **ephemeral disk** (GA 2026-11-04) fixes the staging problem, with these limits:
- 1–100 Gi per volume;
- 10 GiB per instance by default;
- **0 GiB regional quota by default**;
- second-generation execution environment only;
- billed for provisioned size × lifetime;
- "Live migration is not supported".

Its compatibility with GPU jobs is **not stated** on the page.

**Evidence.**
- https://docs.cloud.google.com/run/docs/configuring/services/gpu
- https://docs.cloud.google.com/run/docs/container-contract
- https://docs.cloud.google.com/run/docs/configuring/jobs/ephemeral-disk
- https://docs.cloud.google.com/run/docs/configuring/jobs/cloud-storage-volume-mounts

**Classification.** Confirmed fact (limits). Assumption (exact RAM need). NEEDS POC (peak RAM).

**Severity.** High.

**Recommended alternative.** Start at **8 vCPU / 32 GiB**, add an **ephemeral disk of about 64–100 Gi** for models after requesting quota, and verify GPU and ephemeral-disk compatibility in the POC. Measure peak RSS. Note the cost delta: Tier 2 CPU is 8 × $0.0000216 × 3600 = $0.622/h, versus $0.311/h for 4 vCPU.

### 4. GPU availability, regional quotas and deployment restrictions

**Finding.**
- `asia-southeast1` has L4 for Cloud Run jobs. `asia-south1` (Mumbai) is **invitation-only**, so treat the doc's Priority 2 as unavailable until granted.
- Default quota is 3 L4 per region (no zonal redundancy), "subject to availability". Parallelism above quota makes deployment fail.
- For Compute Engine, G2 exists in asia-southeast1-a/b/c and asia-south1-a/b/c. G4 (RTX PRO 6000) exists in asia-southeast1-a/b, asia-south1-c and asia-south2-a/c.
- AWS defaults for "Running On-Demand G and VT instances" and "All G and VT Spot Instance Requests" are **0 vCPUs**.

**Evidence.**
- https://docs.cloud.google.com/run/docs/configuring/jobs/gpu
- https://docs.cloud.google.com/compute/docs/gpus/gpu-regions-zones
- https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html

**Classification.** Confirmed fact.

**Severity.** Medium for GCP, High for the AWS fallback (it is non-functional until quota is granted).

**Recommended alternative.**
- File quota requests in week 1: Cloud Run L4, Cloud Run ephemeral disk, GCE `GPUS_ALL_REGIONS` + `NVIDIA_L4_GPUS`, and AWS G/VT on-demand and spot.
- Consider `us-central1` / `europe-west4` as **batch** regions. Users wait minutes anyway, so latency to Singapore is irrelevant for an async job. Those regions are Tier 1, which is cheaper for CPU and memory and has more GPU regions. Model and output data residency is the only constraint.

### 5. Cold start and model-loading overhead; GCS access

**Finding.** Google's GPU best practices:
- Recommend downloading from Cloud Storage with gcloud (parallel), noting that container images are "best suited for smaller models less than 10 GB".
- Say Cloud Storage FUSE requires **Direct VPC egress with `all-traffic` + Private Google Access**.
- Say FUSE cache and buffers count toward container memory.
- Recommend fast-loading formats such as GGUF.

FUSE parallel file-cache download defaults to 16 requests per file. Pulling 25–66 GB per execution is billed GPU time, and wall time NEEDS BENCHMARK; throughput is not published. Two side effects of `all-traffic` egress:
- Uploads to R2 and callbacks to Oracle then need **Cloud NAT**, which is a hidden cost and an extra component.
- Same-region GCS to Cloud Run transfer is ASSUMED to have no egress charge. Operation charges are negligible at this scale.

**Evidence.**
- https://docs.cloud.google.com/run/docs/configuring/jobs/gpu-best-practices
- https://docs.cloud.google.com/run/docs/configuring/jobs/cloud-storage-volume-mounts

**Classification.** Confirmed fact for the mechanisms. NEEDS BENCHMARK for throughput.

**Severity.** High (cost and latency per execution, and the cause of item 3).

**Recommended alternative, in preference order.**
1. **Load only what the workflow needs.** Distilled DiT plus one text encoder plus conv VAE plus audio VAE: drop the dev DiT, the duration head, unused upscalers and LoRAs, and every alternate precision.
2. Copy them to ephemeral disk with `gcloud storage cp` (parallel). Do not use random-access FUSE reads.
3. Once it is measured, consider **baking the slim model set into the image**. Cloud Run's image streaming may beat GCS, but Google calls GCS "more predictable". Note that this means Artifact Registry storage of about 25–30 GB per image version.
4. On a VM, keep models on a persistent disk or local SSD. Load once and serve many clips: **this amortises load across a whole video, or many videos**.

Whatever the platform, process **many clips per model load**. Never start one execution per clip.

### 6. Separate containers vs a unified GPU worker

**Finding.** The doc says the "AI processing pipeline will consist of separate Docker images" and also "The worker can use one shared GPU execution". A Cloud Run job task runs a single image. With sidecars, "the GPU can only be attached to one container". So two images cannot both use the GPU in one execution. Running them as two executions means two cold starts, two quota slots (or serialisation) and two model stagings.

**Evidence.** https://docs.cloud.google.com/run/docs/configuring/jobs/gpu (Limitations).

**Classification.** Confirmed fact, plus evidence-supported recommendation.

**Severity.** Medium. It is a design contradiction that will surface in Phase 4.

**Recommended alternative.**
- Use **one GPU image (ComfyUI + LTX only)**.
- Run voice and ASR **outside** the GPU job (see item 7).
- **Reverse the order: narration first.** Generate TTS, measure the duration of each segment, then derive the clip count and per-clip `num_frames` (8k+1) to match. The current video-then-voice order produces clips that will not match narration timing.
- LTX-2.5 also generates audio natively. Decide whether LTX audio is used at all (ambient/SFX) or disabled. It costs memory (audio VAE) and time.

### 7. VoiceStudio and Whisper: same GPU worker, CPU, or API?

**Finding.**
- "VoiceStudio" most plausibly refers to **`debpalash/VoiceStudio`**. It is a **desktop/mobile/server application** under **AGPL-3.0**. Its default engine is "powered by k2-fsa/OmniVoice", and it has a Local API, MCP, CLI and a Docker image (`ghcr.io/debpalash/voicestudio`). Its README states "Clone a voice only with its owner's permission".
- Other unrelated projects share the name (LatentForge/voicestudio, msrbuilds/voice-studio). **The doc never identifies which one**, so the reference is ambiguous.
- **OmniVoice** code is Apache-2.0. Its weights licence is **not stated on GitHub**, so it NEEDS CHECK on the HF card.
- **faster-whisper** is MIT. Its official CPU benchmark: Whisper *small*, int8, transcribed 13 min of audio in **1m42s** (51 s batched) on 8 threads of an i7-12700K, using about 1.5–3.6 GB RAM.

**Evidence.**
- https://github.com/debpalash/VoiceStudio
- https://github.com/k2-fsa/OmniVoice
- https://github.com/SYSTRAN/faster-whisper

**Classification.** Confirmed fact (licences, benchmark). ASSUMPTION: the doc means debpalash/VoiceStudio.

**Severity.** High (AGPL in a SaaS and voice-cloning consent are legal exposure; it is an app, not a library, so batch embedding is awkward).

**Recommended alternative.**
- Call the **TTS engine directly** (for example OmniVoice, after confirming its weights licence; or Kokoro or Piper-class models), or use a **managed TTS API**.
- Run TTS on **CPU or a small separate job**, or on the GPU VM before LTX loads.
- Captions come from a **script you already have**: use forced alignment, or faster-whisper small/base int8 on CPU. Extrapolating linearly from the official benchmark, 3 min of audio would take tens of seconds on comparable CPU (ASSUMPTION, needs measuring on Cloud Run vCPUs).
- Do not spend L4 seconds on Whisper.
- If VoiceStudio itself is kept, keep it **unmodified**, run it as a separate process behind its API, and get AGPL network-use clause (§13) advice.

### 8. Remotion and FFmpeg on CPU; licensing; long renders

**Finding.**
- CPU is correct. Remotion renders through headless Chrome and has no use for an L4. FFmpeg loudnorm is CPU work.
- **Licensing:** the free licence applies only to individuals, "for-profit organization with up to 3 employees", non-profits and evaluation. Otherwise a Company Licence is needed: Automators at **$0.01/render with a $100/month minimum**.
- `@remotion/cloudrun` is "**in Alpha status and not actively being developed**", with a 60 min timeout, 8 vCPU and 32 GB max.
- Use plain server-side rendering (`@remotion/renderer`) inside your own Cloud Run job or VM instead.
- The L4 has NVENC (2×) and NVDEC (4×), which can help FFmpeg encodes if rendering ever moves onto the GPU VM.

**Evidence.**
- https://github.com/remotion-dev/remotion/blob/main/LICENSE.md
- https://www.remotion.pro/
- https://www.remotion.dev/docs/cloudrun
- https://www.nvidia.com/en-us/data-center/l4/

**Classification.** Confirmed fact. Render time and RAM: NEEDS BENCHMARK.

**Severity.** Medium.

**Recommended alternative.**
- Run a Cloud Run **CPU job** at 4–8 vCPU / 8–16 GiB.
- Download clips to the ephemeral disk (not to the in-memory FS) and render 1080p.
- Benchmark a 3 min composition at concurrency 2, 4 and 8.
- If compositions are simple (concat + captions + music ducking + loudnorm), an **FFmpeg-only** path (ASS subtitles, `amix`/`sidechaincompress`, `loudnorm` two-pass) removes Chrome, the Remotion licence and much of the RAM need.
- **Never render on the Oracle 2-OCPU VM.** It would starve the API.

### 9. Is Oracle Always Free suitable for production API + Postgres + orchestration?

**Finding.**
- Always Free A1 is 2 OCPU / 12 GB total and must live in the home region.
- Storage is 200 GB of block volume, with **only 5 Always Free volume backups**.
- **Idle reclamation** applies when, over 7 days, p95 CPU < 20% **and** network < 20% **and** (A1 only) memory < 20%. A small app with Postgres and Next.js resident probably exceeds 20% memory (2.4 GB), so reclamation is unlikely but **not guaranteed**. This must be monitored.
- Capacity errors ("out of host capacity") mean that if the VM is lost, you may be **unable to recreate it** quickly.
- No SLA statement exists for Always Free.
- ARM64: every container and native dependency (Prisma engines, sharp, etc.) must have arm64 builds. Most do.

**Evidence.**
- https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm

**Classification.** Confirmed fact (policy). Assumption (reclamation likelihood).

**Severity.** High. The DB, auth, queue and orchestrator all share a single VM.

**Recommended alternative.**
- Keep Oracle for the beta, but:
  - (a) run **WAL-G/pgBackRest to R2** with continuous WAL archiving and daily base backups, and test restores;
  - (b) keep IaC and a cloud-init script so the VPS can be rebuilt on another provider in under 1 h;
  - (c) put Cloudflare in front for TLS, WAF and caching;
  - (d) alert on host down using an external uptime check;
  - (e) consider upgrading the tenancy to Pay-As-You-Go. Always Free resources remain free after an upgrade, per Oracle's docs. Whether PAYG changes reclamation is **not stated**, so verify.
- Before taking payments, consider a managed Postgres free or cheap tier (e.g. Neon or Supabase) so that the DB is not on the same SPOF. Weigh that against the added latency (preference/trade-off).

### 10. Does the queue need a managed service?

**Finding.** Volume (1–3 concurrent GPU jobs) does not justify Pub/Sub, SQS or Cloud Tasks. **The real risk is state reconciliation, not the queue transport.** If the VPS restarts after calling `jobs.run` but before saving the execution name, you get orphaned GPU executions (billed) or duplicate runs.

**Classification.** Evidence-supported recommendation, and partly preference.

**Severity.** Medium.

**Recommended alternative.**
- Use a **Postgres-backed queue** (`SELECT … FOR UPDATE SKIP LOCKED` or pg-boss) with an explicit state machine:
  `queued → dispatching → running(execution_id) → clips_done(k/n) → rendering → done/failed`.
- Write `dispatching` plus an idempotency key *before* calling Cloud Run, and pass the job ID as an env override.
- Run a **reconciler loop** every 1–2 min that lists Cloud Run executions carrying the job label and fixes the DB state. It should cancel orphans and re-dispatch lost jobs.
- Have the worker write progress markers and outputs to object storage so the reconciler can derive truth from storage rather than callbacks.
- Treat callbacks to Oracle as hints only, since Oracle may be down.

### 11. Retries (0), timeout (60–90 min), concurrency (1)

**Finding.**
- 90 min exceeds the 1 h GA cap, so it requires the **Preview** 12 h mode.
- GPU tasks are terminated (not migrated) during maintenance. Google advises "periodic checkpointing as your primary protection".
- SIGTERM gives a 10 s grace period.
- `CLOUD_RUN_TASK_INDEX` and `CLOUD_RUN_TASK_ATTEMPT` are provided.
- Google recommends "enabling retries for all jobs".

**Runtime mapping (ASSUMPTION/hypothetical).**
- A 150 s video in 5 s clips (121 frames at 24 fps) = **30 clips**. In 10 s clips = **15 clips**.
- Runtime ≈ staging/init + N × t_clip + decode/upload. t_clip on L4 is **unknown (NEEDS BENCHMARK)**.
- With t_clip = 3 min and 30 clips, generation alone is 90 min, so one execution blows the GA cap.

**Evidence.**
- https://docs.cloud.google.com/run/docs/configuring/task-timeout
- https://docs.cloud.google.com/run/docs/container-contract

**Classification.** Confirmed fact (limits). Hypothetical (runtime).

**Severity.** High.

**Recommended alternative.**
- **Task granularity:** one execution with `taskCount = ceil(N/k)` and `parallelism ≤ quota (3)`. Each task generates clips `[i·k, (i+1)·k)`, with k chosen so each task finishes in under 40 min. The trade-off is that parallel tasks each pay model staging.
- **Checkpointing:** upload each finished clip immediately to `jobs/{id}/clips/{idx}.mp4` with a deterministic seed. On retry, skip existing clips.
- **Retries:** use `maxRetries = 1–2` (safe because the work is idempotent).
- **Failure classification:**
  - Capacity or quota errors (execution never starts, or fails before the container starts: RESOURCE_EXHAUSTED or quota messages) are retried with backoff or routed to the fallback provider.
  - Deterministic app errors (OOM at a given resolution, NaNs, bad prompt) are not retried. Mark them failed and refund credits.
  - Exit codes from the worker carry the class.
- **Timeouts:** per-clip watchdog inside the worker, plus a task timeout ≤ 1 h.
- **Concurrency:** 1 is fine initially, but the *admission control* belongs in the app (per-user and global caps, credit reservation), not just in the Cloud Run setting.

### 12. Is Cloudflare R2 the right output store?

**Finding.**
- R2 pricing: storage $0.015/GB-month; Class A $4.50/M; Class B $0.36/M; **free egress**; free tier of 10 GB-month, 1M Class A and 10M Class B. This is good for user downloads.
- The **GCP side is not free.** Uploading clips and finals from Cloud Run to R2 is internet egress from GCP. Google's Premium tier Asia rate is **$0.12/GiB** (0–1 TiB, per its pricing announcement table).
- With Direct VPC egress, Cloud NAT is also needed (price NEEDS VERIFICATION).
- Intermediates (clips, audio) that bounce GCP → R2 → GCP render worker → R2 pay egress on the first and last hops.

**Evidence.**
- https://developers.cloudflare.com/r2/pricing/
- https://cloud.google.com/vpc/pricing-announce

**Classification.** Confirmed fact (prices). Evidence-supported recommendation.

**Severity.** Low–Medium. The cost is small per video but it is a design smell.

**Recommended alternative.**
- Keep **intermediates in a GCS bucket in the same region**, with a 7-day lifecycle delete. Same-region transfer is ASSUMED free.
- Push **only the final MP4 and thumbnail to R2** for delivery.
- Use R2 lifecycle rules for old finals.
- Backblaze B2 is not compelling here, since R2 already has zero egress.
- GCS + Cloud CDN would add egress cost for users.

### 13. Is AWS G5 the right fallback?

**Finding.**
- G5 is an A10G 24 GB (Ampere) with no FP8 tensor cores. L4 (Ada) has FP8, so FP8 checkpoints tuned on L4 may behave or perform differently on A10G.
- G6 (L4) is listed in ap-south-1 by third-party trackers: g6.xlarge on-demand about $0.9664/h, 2 AZs, spot snapshots $0.39–0.79/h. **This is unverified on official pages.**
- AWS default quota for G/VT on-demand and spot is **0 vCPU**.
- AWS Batch adds a compute environment, job queue and ECR on top. That is heavy for a fallback that may rarely run.

**Evidence.**
- https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html
- https://www.doit.com/compute/spot/ap-south-1/g6.xlarge (third party)

**Classification.** Confirmed fact (quota). Third-party (prices).

**Severity.** Medium.

**Recommended alternative.**
- If AWS is kept: use **G6 (L4) or G6e**, plain EC2 from a prebuilt AMI with models on an EBS snapshot, started by the orchestrator. Request quota now.
- A cheaper-to-integrate second provider is **Modal or RunPod serverless** (24 GB tier $0.75/h on RunPod; L4 ≈ $0.80/h GPU on Modal before CPU/RAM). Both take the same container and the same "process job X" contract.
- Also consider **Cloud Run in a second GCP region** (us-central1 / europe-west4, Tier 1) as the *first* fallback. It uses the same image and IAM, with no new vendor.

### 14. Hidden costs

See the dedicated section below.

**Severity.** Medium. The total is modest, but the doc's per-video figure is materially optimistic.

### 15. Security

**Finding.**
- **Oracle → GCP auth.** Google's Workload Identity Federation docs cover AWS/Azure natively and "other providers (OIDC)". OCI compute has no off-the-shelf integration (not mentioned). In practice this means either a **service account key** on the VPS or a self-run OIDC issuer.
- **R2.** API tokens can be scoped to specific buckets (prefix-level scoping is ASSUMED unavailable, so verify).
- **Presigned URLs.** S3-compatible presigned URLs should be short-lived (minutes, not days).
- **Content safety.** The LTX AUP binds you and your users. The licence requires end users to be bound by the use restrictions. Item 19 prohibits disabling watermarking and provenance.
- **Voice cloning.** This needs consent capture.

**Classification.** Mixed: confirmed (AUP, WIF scope); recommendation.

**Severity.** High (key compromise lets an attacker launch GPU jobs and burn budget; deepfake/voice abuse exposes the operator).

**Recommended alternative.**
- (a) Create a dedicated SA with a **custom role** limited to `run.jobs.runWithOverrides` and `run.executions.get/list/cancel` on the specific job. No storage or admin rights.
- (b) Store the key root-only with file mode 600, rotate it every 90 days, and set org-policy key expiry. Alert on SA usage outside expected IPs (Cloud Audit Logs).
- (c) The worker SA gets `storage.objectViewer` on the models bucket and `objectAdmin` on the intermediates bucket only.
- (d) Put the R2 write token in Secret Manager, accessed by the worker, scoped to the output bucket.
- (e) Use presigned GETs with ≤ 15–60 min lifetime, issued per request after an ownership check.
- (f) Layer the controls: prompt and input moderation before dispatch, image-input moderation for I2V, output sampling and moderation, rate limits, and per-account spending caps enforced in the DB.
- (g) Require a voice-cloning consent record (who, when, sample) and disallow cloning public figures.
- (h) Validate all user-supplied media (size, codec, duration) on the VPS **before** any GPU spend.

---

## Strengths of the original architecture

- It **puts the right principle first**: pay for GPUs only when working, and keep the control plane cheap. That is appropriate for an early-stage product.
- It **already flags** the right risks (GCS is not a local SSD, the in-memory filesystem, quota and availability, licensing as a production gate, billing alerts not being caps). Those instincts are sound.
- It keeps **storage and compute decoupled**, with a "common job interface" for provider-swapping. That is the correct abstraction and makes the fallback and VM alternatives cheap to add.
- It **separates AI generation from final assembly** and puts assembly on CPU. Correct.
- It chooses **R2 for user-facing delivery**. Correct, given zero egress.
- Its **staged roadmap** with a benchmark phase is appropriate.
- Its L4 Cloud Run L4 job regions claim for Singapore is **accurate**.

---

## Real failure scenarios

1. **Maintenance kill mid-video.** A 2.5 min video is dispatched as one execution with a 90 min timeout (Preview) and 0 retries. At minute 70, after 22 of 30 clips, a GPU host maintenance event terminates the task, because GPU tasks are not live-migrated. Clips were held locally (in-memory FS), so all are lost. The user sees "failed", about $1.30+ of GPU time is wasted (hypothetical), and a resubmit starts from zero.
2. **OOM at staging.** The worker runs `gcloud storage cp gs://video-models/ltx-2.5/ /models` into the default writable filesystem. Roughly 25–30 GB of writes to an in-memory FS on a 16 GiB instance means the container exceeds memory and "is terminated". This happens on every execution, before any generation, and is billed.
3. **Ephemeral disk quota of 0.** The team adds an ephemeral disk volume. The deployment fails because the project's regional ephemeral-disk allocation is 0 GiB by default. The quota request takes days.
4. **Text-encoder/DiT swap thrash.** On 24 GB, ComfyUI must evict Gemma 4 12B to load the DiT for every prompt. With 16 GiB RAM it cannot keep the evicted weights in RAM, so it re-reads them from disk (or FUSE) per clip. Per-clip time doubles and the 1 h cap is hit. (Mechanism plausible; magnitude NEEDS BENCHMARK.)
5. **Orphaned execution after VPS restart.** The orchestrator calls `jobs.run`, then the Oracle VM reboots (kernel update, OOM from a Next.js build, host maintenance) before the execution name is committed. The GPU job runs to completion and uploads to R2, but the DB still shows `queued`. On restart the queue re-dispatches, so the GPU is paid twice and two sets of outputs exist.
6. **Fallback is non-functional on the day it is needed.** Singapore returns capacity errors and Mumbai is invite-only. The AWS fallback fails with `VcpuLimitExceeded` because the G/VT quota is 0. All jobs queue indefinitely and users churn.
7. **Narration/visual mismatch.** Clips are generated first (fixed 5 s each), then the TTS for the script runs 2 m 47 s while the clips total 2 m 30 s. Remotion must loop, freeze-frame or time-stretch, and quality complaints follow. The fix requires regenerating clips. Root cause: wrong stage order.
8. **Licence enforcement.** The product gains traction. Lightricks deems it a competing product under item 20, and the licence "terminates immediately and automatically, without notice". The core model must be replaced under time pressure.
9. **Key leak.** The SA JSON key in `.env` on the VPS is exposed (via backup, repo or SSRF). If it has `roles/run.admin` or broader, an attacker deploys or executes GPU jobs up to quota. Billing alerts fire at $5/$10/$20, but alerts are not caps.
10. **Oracle reclamation or capacity.** During a quiet week (holiday), A1 metrics fall below all three thresholds and the instance is reclaimed. A recreate attempt hits "out of host capacity". The DB was only on the boot/block volume with ad-hoc backups.

---

## Hidden costs (with arithmetic)

Rates are CONFIRMED where sources are cited. Everything else is labelled.

**A. Hourly rate correction.** The doc's $1.04652/h uses GPU $0.0001867/s, CPU $0.000018/vCPU-s and memory $0.000002/GiB-s, which are **Tier 1** rates. `asia-southeast1` is **Tier 2** (Cloud Run locations page). Tier 2 CPU is $0.0000216/vCPU-s (a third-party snapshot of the pricing page agrees with ~20% uplift).

| Shape (Singapore, Tier 2) | GPU/h | CPU/h | Mem/h | Total/h |
|---|---|---|---|---|
| 4 vCPU / 16 GiB | 0.672 (Tier 1 figure; **Tier 2 GPU rate not verified**) | 4 × 0.0000216 × 3600 = **0.311** | 16 × 0.0000024 × 3600 = 0.138 (ASSUMED 20% uplift) | **≈ $1.12** |
| 8 vCPU / 32 GiB (Google-recommended) | 0.672 | **0.622** | 0.276 | **≈ $1.57** |

**B. Cost per 2.5 min finished video.** This is HYPOTHETICAL and parametric. Runtime = 5 min staging/init + N × t_clip.

| Clips (N) | t_clip | GPU-job minutes | @ $1.12/h | @ $1.57/h | Fits 1 h GA cap in one task? |
|---|---|---|---|---|---|
| 15 (10 s clips) | 1 min | 20 | $0.37 | $0.52 | yes |
| 15 | 3 min | 50 | $0.93 | $1.31 | marginal |
| 30 (5 s clips) | 1 min | 35 | $0.65 | $0.92 | yes |
| 30 | 3 min | 95 | $1.77 | $2.49 | **no** |
| 30 | 6 min | 185 | $3.45 | $4.84 | **no** |

None of these t_clip values come from measurement. They exist only to show sensitivity. The doc's 7.5 min per video is optimistic for anything beyond a short Reel unless per-clip times on L4 are well under 1 min.

Splitting into parallel tasks **adds** staging cost per task, about 5 min × $1.12/h ≈ $0.09 each (hypothetical).

**C. Failed and retried work.** Without checkpointing, every interruption costs the full elapsed time. With per-clip checkpointing, the expected loss is at most one clip plus staging.

**D. Egress GCP → R2.** At $0.12/GiB (Asia, Premium, 0–1 TiB), assume (hypothetically) 30 clips × 15 MB + 300 MB final ≈ 0.75 GiB/video, about **$0.09/video**. At 1,000 videos/month that is **$90/month**. Keeping intermediates in GCS (same region) and only shipping finals reduces this to about $0.035/video.

**E. Cloud NAT.** It is required if Direct VPC egress `all-traffic` is used, which the FUSE path requires. NAT has gateway-hour and per-GiB processing charges. **Rates not verified here; check the Cloud NAT pricing page.**

**F. Artifact Registry.** Rate: $0.10/GB-month above 0.5 GB (confirmed).

| Image strategy | Arithmetic | Monthly cost |
|---|---|---|
| Slim ComfyUI image (~10 GB, assumed) × 3 retained versions | 3 × 10 × $0.10 | ≈ $3 |
| Models baked in (~35 GB) × 3 retained versions | 3 × 35 × $0.10 | ≈ $10.50 |

Add cleanup policies so old versions do not accumulate.

**G. GCS model bucket.** Standard storage of 50–70 GB. Singapore pricing was **not verified** (ASSUMED about $0.02/GB-month), so roughly $1–1.50/month. Operations are negligible.

**H. Ephemeral disk.** Billed on "entire size of the provisioned disk and the lifetime of the instance". The rate was not verified. It is small per job but non-zero.

**I. Cloud Logging.** ComfyUI and torch are verbose. Set the worker log level to WARNING and add exclusion filters. The free allotment and per-GiB rate were **not verified here**.

**J. Remotion.** If the company has more than 3 employees, the minimum is **$100/month** (Automators, $0.01/render). At under 10,000 renders/month, that works out to **$100 / renders** per render. At 200 renders/month, that is **$0.50/render**, which may exceed the GPU cost of a Reel.

**K. Oracle backups.** Off-box Postgres backups to R2: a 5 GB DB with 30 days of WAL is about 20–50 GB × $0.015 ≈ **$0.30–0.75/month**. Cheap, so no excuse to skip it.

**L. Idle and minimum billing.** Jobs scale to zero, so there is no idle GPU cost on Cloud Run. **On a GCE VM, a forgotten running VM costs about $0.87/h**, roughly $636/month on-demand in Singapore for g2-standard-4 (third-party figure). This requires a self-shutdown watchdog plus an external "VM running with an empty queue" alert.

---

## Recommended changes (prioritised)

| # | Change | Why | Severity |
|---|---|---|---|
| 1 | Get written licence clarity from Lightricks on Attachment A item 20 (competing services), or a commercial licence. Also verify the Gemma 4 encoder licence, the OmniVoice weights licence and the Remotion licence tier. | Existential legal risk | Critical |
| 2 | **POC gate before any build-out**: on one L4 with 8 vCPU / 32 GiB and an ephemeral disk, run the official LTX-2.5 distilled int8/FP8 workflow at 720p and 1080p for 5 s and 10 s clips. Record peak VRAM, peak RAM, staging time, t_clip and failure modes. Compare with community Q4 GGUF. | Every downstream number depends on it | Critical |
| 3 | Redesign the GPU job as **idempotent, checkpointed, batched tasks** (each under 40 min, `maxRetries` 1–2, per-clip upload, deterministic seeds). Do not depend on the 12 h Preview. | 1 h GA cap; maintenance kills GPU tasks | High |
| 4 | Move to **8 vCPU / 32 GiB + ephemeral disk**, and request the ephemeral-disk quota now. Stage only the required model files with parallel `gcloud storage cp`. | In-memory FS; RAM offload | High |
| 5 | **Narration-first pipeline**: TTS on CPU or API, then durations, then clip plan, then LTX, then a CPU render. Remove voice and Whisper from the GPU job, and use one GPU image. | Sync correctness; contradiction in the doc | High |
| 6 | Durable **Postgres state machine + reconciler** against the Cloud Run Executions API, with idempotency keys and labels. | Orphaned or duplicate GPU spend | High |
| 7 | Replace VoiceStudio (AGPL app) with a directly embedded TTS engine whose weights licence is permissive, or with an API. Add a consent workflow for cloning. | Licence and abuse exposure | High |
| 8 | Postgres PITR backups to R2 plus a rebuild-in-1h runbook for the Oracle VM, and external uptime monitoring. | No SLA, no HA | High |
| 9 | File quota requests now: Cloud Run L4 (Singapore + one Tier 1 region), GCE L4, AWS G/VT. Make the **first fallback another GCP region**, with a serverless GPU vendor second. | Fallback is currently non-functional | Medium |
| 10 | Least-privilege SA (custom role on one job), key rotation and expiry, short-lived presigned URLs, and moderation before GPU spend. | Budget burn and abuse | Medium |
| 11 | Keep intermediates in same-region GCS with a 7-day lifecycle, and ship only finals to R2. | Egress and NAT cost | Low–Med |
| 12 | Correct the cost model to Tier 2 rates and the real shape. Model cost per finished minute from POC data. | Pricing accuracy | Medium |

---

## Alternative architectures

### A. "Cloud Run Jobs, done right" (closest to the original)
- **Design:** Oracle control plane with a Postgres queue and reconciler. CPU TTS job → one GPU Cloud Run job execution per video with `taskCount = ⌈clips/k⌉`, `parallelism ≤ 3`, an ephemeral disk and 8/32 → CPU render job → R2.
- **Pros:** No VMs; scale to zero; minimal change from the doc.
- **Cons:**
  - Model staging is paid per task.
  - It relies on GA-new ephemeral disk, whose GPU compatibility must be verified.
  - Singapore is Tier 2.
  - The 1 h cap shapes all the work.
- **Best for:** Reels and short videos, and low or bursty volume.

### B. "Stop/start GPU VM worker" (my preferred long-form path, subject to POC)
- **Design:** One `g2-standard-8` (L4) VM with a 150–200 GB balanced PD or local SSD holding the models, the Docker image and ComfyUI. The Oracle orchestrator starts the VM via API when the queue is non-empty. The worker pulls jobs from the Postgres queue (over an authenticated HTTPS API on the VPS), processes **many clips and many videos per model load**, checkpoints to GCS, and shuts down after X min idle. An external watchdog alerts if the VM runs with an empty queue.
- **Pros:** No 1 h cap; no per-run re-download; models stay warm across consecutive jobs; can add spot with checkpoint resume; rendering and NVENC can run on the same box.
- **Cons:** You manage the OS, drivers and image; VM boot plus model load latency NEEDS BENCHMARK; PD costs accrue while stopped; GCE GPU quota must be obtained; the cost of runaway risk is higher, so the watchdog is mandatory.
- **Best for:** 2–3+ min videos, and steady volume.

### C. "Serverless GPU vendor primary" (Modal or RunPod)
- **Design:** Same job contract, with a persistent volume or snapshot for models.
- **Pros:** Fast iteration; volumes avoid re-download; the L4 or 24 GB tier is priced in the same range as Cloud Run (Modal L4 GPU ≈ $0.80/h plus CPU/RAM; RunPod 24 GB serverless $0.75/h); larger GPUs available on demand.
- **Cons:** Vendor maturity and data-handling review; region surcharges on Modal (1.15–1.75×); network egress to R2 from the vendor; no GCP IAM integration.
- **Best for:** Fast POC and a second provider.

### D. "Bigger GPU, fewer tricks" (Cloud Run RTX PRO 6000, 96 GB)
- **Pros:** Removes VRAM fitting, offload and quantisation risk; bf16 or FP8 at higher resolution; available in Singapore and Delhi for jobs.
- **Cons:** Minimum 20 vCPU / 80 GiB, so the hourly rate is far higher. The price is not verified here. It is only worth it if POC t_clip drops enough that cost per clip is lower.
- **Best for:** If the L4 POC fails the VRAM or quality gate.

---

## Open questions and required POCs/benchmarks

1. **Lightricks licence:** Does an end-user AI video SaaS fall under item 20? This needs a written answer.
2. **LTX-2.5 on L4.** Measure, for each of the official int8/FP8 and community Q4/Q5 GGUF variants:
   - peak VRAM;
   - peak host RAM;
   - t_clip at 720p/1080p × 5 s/10 s;
   - quality deltas;
   - whether audio generation can be disabled to save memory and time.
3. **Staging throughput:** GCS to ephemeral disk via `gcloud storage cp` on Cloud Run L4 (GB/s), against image streaming of a slim baked image, against FUSE with file cache. Does ephemeral disk attach to GPU jobs at all?
4. **Cold-start total:** execution submit → first denoising step, for Cloud Run and for a stopped G2 VM.
5. **Quotas:** Cloud Run L4 (Singapore + Tier 1 region), ephemeral-disk regional allocation, GCE L4, AWS G/VT. Record grant times.
6. **Tier 2 GPU price:** What are the exact L4 and RTX PRO 6000 per-second prices in `asia-southeast1` for jobs (Billing SKU API)?
7. **Remotion vs FFmpeg-only:** render time and RAM for a 3 min 1080p composition on 4 and 8 vCPU. Licence tier by headcount.
8. **TTS choice:** OmniVoice weights licence; CPU real-time factor; quality per target language (Hindi/English likely, which is an ASSUMPTION based on the Mumbai/Delhi focus).
9. **Oracle:** actual p95 CPU, network and memory of the VPS over 7 days, against reclamation thresholds. Restore drill from R2 backups.
10. **Clip continuity:** How will the pipeline keep character and scene consistency across 15–30 independently generated clips (multishot, I2V chaining from last frames, LoRA)? This is a product-quality risk that affects clip count and runtime.

---

## References (accessed 2026-11-10 / 2026-11-11)

**Google Cloud**
- Cloud Run GPU for jobs: https://docs.cloud.google.com/run/docs/configuring/jobs/gpu
- Cloud Run GPU for services (recommended 8 CPU / 32 GiB): https://docs.cloud.google.com/run/docs/configuring/services/gpu
- Task timeout (GPU 1 h GA / 12 h Preview, no live migration): https://docs.cloud.google.com/run/docs/configuring/task-timeout
- Cloud Run quotas: https://docs.cloud.google.com/run/quotas
- Cloud Run release notes: https://docs.cloud.google.com/run/docs/release-notes
- GPU best practices for jobs: https://docs.cloud.google.com/run/docs/configuring/jobs/gpu-best-practices
- Container runtime contract: https://docs.cloud.google.com/run/docs/container-contract
- Ephemeral disk for jobs: https://docs.cloud.google.com/run/docs/configuring/jobs/ephemeral-disk
- Cloud Storage volume mounts for jobs: https://docs.cloud.google.com/run/docs/configuring/jobs/cloud-storage-volume-mounts
- Cloud Run locations and pricing tiers: https://docs.cloud.google.com/run/docs/locations
- Cloud Run pricing: https://cloud.google.com/run/pricing
- GPU regions and zones (Compute Engine): https://docs.cloud.google.com/compute/docs/gpus/gpu-regions-zones
- VPC pricing announcement (egress rates): https://cloud.google.com/vpc/pricing-announce
- Artifact Registry pricing: https://cloud.google.com/artifact-registry/pricing
- Workload Identity Federation with other clouds: https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-other-clouds

**Lightricks**
- LTX-2 repository: https://github.com/Lightricks/LTX-2
- LTX-2.5 model card: https://huggingface.co/Lightricks/LTX-2.5
- LTX-2.x Community License: https://github.com/Lightricks/LTX-2/blob/main/LICENSE-2_x
- ComfyUI-LTXVideo: https://github.com/Lightricks/ComfyUI-LTXVideo

**Third-party model and pricing sources**
- LTX-2.5 GGUF quants (community): https://huggingface.co/unsloth/LTX-2.5-GGUF
- LTX-2.5 release write-up: https://comfyui-wiki.com/en/news/2026-08-11-ltx-2-5-open-weights-release
- Cloudchipr Cloud Run pricing guide: https://cloudchipr.com/blog/cloud-run-pricing
- Holori g2-standard-4 in asia-southeast1: https://calculator.holori.com/gcp/vm/g2-standard-4/asia-southeast1
- DoiT g6.xlarge in ap-south-1: https://www.doit.com/compute/spot/ap-south-1/g6.xlarge

**Hardware**
- NVIDIA L4: https://www.nvidia.com/en-us/data-center/l4/

**Oracle**
- Always Free resources: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- Free Tier overview: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm

**AWS**
- EC2 instance quotas: https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html

**Cloudflare**
- R2 pricing: https://developers.cloudflare.com/r2/pricing/

**Rendering**
- Remotion license: https://github.com/remotion-dev/remotion/blob/main/LICENSE.md
- Remotion pricing: https://www.remotion.pro/
- Remotion Cloud Run: https://www.remotion.dev/docs/cloudrun
- Remotion concurrency: https://www.remotion.dev/docs/terminology/concurrency

**Voice and ASR**
- VoiceStudio: https://github.com/debpalash/VoiceStudio
- OmniVoice: https://github.com/k2-fsa/OmniVoice
- faster-whisper: https://github.com/SYSTRAN/faster-whisper

**Serverless GPU vendors**
- Modal pricing: https://modal.com/pricing
- RunPod pricing: https://www.runpod.io/pricing
