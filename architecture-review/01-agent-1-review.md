# Architecture Review, Round 1: Agent 1 (Senior Cloud Solutions Architect)

| Field | Value |
|---|---|
| Role | Agent 1: Senior Cloud Solutions Architect (GCP/AWS, Cloud Run Jobs + GPU, NVIDIA GPU infra, containers, object storage, distributed systems, cost) |
| Date | 2026-11-10 (research ran through 2026-11-11) |
| Document reviewed | `architecture.txt`: "Complete Video Generation Platform – System Architecture & Infrastructure Plan" |
| Scope | All components: Oracle Always Free VPS (Next.js/API/Postgres/queue), Cloud Run GPU Jobs (L4, 4 vCPU/16 GiB, asia-southeast1), ComfyUI + "LTX-2.5 22B Q4", "VoiceStudio" TTS, Whisper, GCS model storage, Remotion + FFmpeg rendering, Cloudflare R2, the AWS G5 fallback, security, cost controls, and roadmap |
| Method | Read-only. I used current official documentation: the Cloud Run docs and release notes, the Cloud Run, GCS and VPC pricing pages (per-region values parsed from the embedded pricing tables), the Lightricks Hugging Face repo file listing through the HF API (exact file sizes), docs.ltx.io system requirements, the LTX-2.x license text, NVIDIA's L4 product page, AWS EC2 G5/G6/G6e pages, AWS public on-demand price JSON (Mumbai), a read-only EC2 `DescribeInstanceTypeOfferings` call, Cloudflare R2 docs, Oracle Always Free docs, the Remotion license, the OpenAI Whisper repo, the GitHub API for repo licenses, and the Modal and RunPod pricing pages. I ran no benchmarks, created no resources, and assumed no quotas. |
| Evidence labels | **[FACT]** confirmed in an official source (URL in the evidence table and references). **[REC]** recommendation supported by evidence. **[ASSUMPTION]** must be tested. **[POC]** needs a benchmark or proof of concept. **[TRADE-OFF]** preference. |

---

## 1. Executive summary

1. **The core pattern is sound and I defend it:** an always-on control plane on free infrastructure, scale-to-zero GPU batch executions, and storage kept separate from compute. Cloud Run Jobs with GPU are **GA (since 2025-10-21)**. NVIDIA L4 is supported for jobs in **asia-southeast1**, and the minimum for L4 is exactly the planned **4 vCPU / 16 GiB** [FACT]. `asia-south1` (Mumbai) L4 is **"by invitation only"** [FACT].
2. **The model choice and the hardware target conflict.** LTX-2.5 exists (22B audio+video, released 2026-08-11). Lightricks' **official minimum is 32 GB+ VRAM and 32 GB system RAM**, and the recommended setup is A100 80GB/H100 with 64 GB+ RAM [FACT]. An L4 (24 GB VRAM) with 16 GiB RAM is below both minimums. "Q4" is not an official artifact. It means a community GGUF (unsloth Q4_K_M DiT = **13.58 GB**). The text encoder is a separate **Gemma 4 12B: 26.26 GB bf16, 15.37 GB official int8** [FACT]. An L4 can run this only with aggressive quantization plus sequential load/offload. That is unsupported and has to be proven in a POC. **16 GiB of host RAM is the binding constraint, more than the 24 GB of VRAM.**
3. **The doc's GPU price is the wrong region's rate.** $0.67212/h for the L4 is the **Tier 1 (Iowa/Mumbai)** rate. Singapore is **Tier 2**: L4 $0.00022404/s ($0.8065/h), CPU $0.0000216/vCPU-s, memory $0.0000024/GiB-s. So 4 vCPU/16 GiB/L4 in Singapore is **$1.2558/h**, not $1.0465/h (+20%). The realistic 8 vCPU/32 GiB configuration is **$1.7051/h** [FACT-based arithmetic].
4. **Storage was a blocker until recently.** **Cloud Run ephemeral disk became GA on 2026-11-04.** It provides 1–100 GiB per volume and 10 GiB per instance by default (quota increase needed above that), and it is billed per GiB-hour [FACT]. The doc's concern that the writable filesystem is memory-backed is correct for the default filesystem, but it is out of date as a design constraint. **Recommended model path:** a parallel GCS download (Direct VPC + Private Google Access) to an ephemeral disk, then load. Do not copy models to the in-memory filesystem (impossible at 16 GiB), and do not depend on random reads through GCS FUSE.
5. **The pipeline description contradicts itself.** It uses "two separate Docker images" but also "one shared GPU execution, sequential." A Cloud Run job task runs one container image, and with sidecars **only one container can hold the GPU** [FACT]. The options are to merge into one GPU worker image or to pay two cold starts. I recommend one image with stage-wise model loading.
6. **The timeout and retry settings are unsafe for long videos.** **GPU tasks are not live-migrated and are terminated during maintenance.** Google says multi-hour GPU tasks "should be expected to be interrupted at least once." The GPU task timeout can go up to 12 h, but that is **Preview** [FACT]. "Retries = 0" plus a monolithic 60–90 min execution guarantees lost work. The design needs per-clip checkpointing to object storage, idempotent resumable tasks, and retries ≥ 1.
7. **Cold start and model load are billed GPU time,** because GPU is "billed for the entire duration of the instance lifecycle" [FACT]. One execution per user request means paying for the image pull, a ~32 GB model fetch and model load every time. **Recommendation:** a queue-draining worker, where each execution processes jobs until the queue is empty or a time budget is reached.
8. **There are licensing gaps that must be closed before paid use.** LTX-2.x Community License: free commercial use **below $10M annual revenue** [FACT]. "VoiceStudio" is most likely `debpalash/VoiceStudio`, which is **AGPL-3.0**, a desktop-first app whose default engine is OmniVoice (Apache-2.0 code) [FACT]. That is ambiguous and risky for a SaaS, so call the underlying TTS engine directly. **Remotion needs a paid Company License** (Automators: $0.01/render, $100/mo minimum) unless the company has ≤3 employees [FACT]. ComfyUI is GPL-3.0, which is fine for internal server use.
9. **Some cost controls are now available as product features.** **Cloud Run Budget spend caps (GA 2026-10-12)** can pause jobs at a cap [FACT]. This should replace "billing alerts only" as the hard backstop, alongside app-level quotas. Delayed jobs (Preview) reduce CPU/memory prices but **not the GPU price** [FACT], so they matter little here.
10. **Alternatives that need a fair hearing.** On **Cloud Run RTX PRO 6000 (96 GB) in asia-southeast1**, LTX-2.5 runs at or above its official spec, but the minimum is 20 vCPU/80 GiB, which costs $3.824/h. It only wins if it is **≥2.24× faster** per clip than an 8 vCPU/32 GiB L4 [POC]. On **AWS g6e.xlarge (L40S 48 GB) in Mumbai** at $2.235/h, the model meets spec and the instance has a 250 GB local NVMe [FACT]. The fallback table should list **G6 (L4) and G6e (L40S)**, not only G5 (A10G).

---

## 2. Component-by-component evaluation

### 2.1 Oracle Always Free VPS (Next.js, API, auth, PostgreSQL, queue, orchestrator, status)
- **Facts.** The Always Free A1 allowance is 1,500 OCPU-hours and 9,000 GB-hours per month, which equals **2 OCPU / 12 GB**, with **200 GB** of combined block/boot storage in the home region. It is Arm (Ampere A1). The idle reclamation policy applies when, over 7 days, CPU p95 < 20% **and** network < 20% **and** memory < 20% (the memory condition applies to A1). Free shapes can hit "out of host capacity" errors [FACT, Oracle docs].
- **Assessment.** It is adequate for an MVP control plane: Postgres, a Next.js SSR/API process, and a lightweight queue. Postgres plus Node on 12 GB will usually keep memory above 20%, so reclamation is unlikely but not contractually excluded [ASSUMPTION].
- **Gaps.**
  - There is no SLA. It is a single VM with no HA, so a Postgres failure loses job state.
  - The doc has no backup plan. Recommendation: nightly `pg_dump` + WAL archiving to R2 or GCS, with tested restores.
  - The VM is ARM64, so every image built for it must be `linux/arm64` (multi-arch builds).
  - The queue should be Postgres-native (`SELECT … FOR UPDATE SKIP LOCKED`, e.g. pg-boss/Graphile Worker) to avoid running Redis on 12 GB [REC].
  - The orchestrator needs **reconciliation polling** of Cloud Run execution status, not only a callback from the worker. A worker killed by maintenance or OOM never calls back.

### 2.2 Cloud Run Jobs (GPU execution)
- **Facts (configuring/jobs/gpu, release notes):**
  - GPU jobs GA 2025-10-21. GPU types: L4 24 GB and RTX PRO 6000 Blackwell 96 GB, driver 580.x (CUDA 13.0).
  - L4 regions: asia-southeast1, asia-south1 (invite only), europe-west1, europe-west4, us-central1, us-east4.
  - RTX PRO 6000 regions: asia-southeast1, asia-south2, europe-west4, us-central1.
  - L4 minimum: 4 CPU / 16 GiB. RTX PRO 6000 minimum: 20 CPU / 80 GiB.
  - One GPU per instance, attached to one container only.
  - Jobs **must** use non-zonal-redundancy (`--no-gpu-zonal-redundancy`). Failover is best-effort.
  - First use in a region gets an automatic **3-GPU quota**, "subject to availability". Parallelism must stay below quota or the deploy fails.
  - Instances with preinstalled drivers "start in approximately 5 seconds."
  - GPU is billed for the whole instance lifecycle.
- **Jobs CPU/memory doc:** maximum **8 vCPU / 32 GiB**, and 4 vCPU allows at most 16 GiB. This conflicts with the RTX PRO 6000 minimum of 20 vCPU/80 GiB, so the GPU-specific page evidently overrides the general table. **Flag: verify with a dry-run deploy.**
- **Task timeout:** default 10 min, max 168 h, **GPU tasks max 12 h (Preview, 2026-10-30)**. GPU tasks are not live-migrated and get SIGTERM 10 s before kill [FACT].
- **Assessment.** The fit is good: run-to-completion work, no idle cost, managed drivers, a quota that exists by default. Three things are wrong or missing in the doc:
  - (a) The per-region price (see Section 7).
  - (b) The 4 vCPU/16 GiB sizing. It is the minimum, and it is too little RAM for a 22B DiT plus a 12B text encoder with ComfyUI offload. **Start at 8 vCPU/32 GiB** (the maximum for the L4 tier).
  - (c) Interruption semantics.
- **Job triggering.** Use `RunJob` with **overrides** (args/env per execution) so that one job definition serves all requests. Oracle's identity needs only `run.jobs.runWithOverrides` on that job (plus `run.executions.get`) [REC].

### 2.3 NVIDIA L4 (24 GB) with 4 vCPU / 16 GiB
- **Facts (NVIDIA):** 24 GB, **300 GB/s** memory bandwidth, FP8 tensor 485 TFLOPS *with sparsity* (half that dense), BF16 242 TFLOPS sparse (121 dense), 72 W TDP, PCIe Gen4 x16, NVENC 2 / NVDEC 4. Ada architecture: FP8 yes, **NVFP4 no** (the NVFP4 LTX checkpoint requires Blackwell) [FACT].
- **Assessment.** The L4 is a low-power inference card. Its 300 GB/s bandwidth is low next to an A10G (24 GB) or an L40S (48 GB), and the gap matters for a 22B DiT [ASSUMPTION about relative speed: POC]. It is cost-efficient per hour but likely slow per clip.
- **CPU sizing.** 4 vCPU is enough for orchestration and FFmpeg muxing, but tight for GGUF dequantization paths that fall back to CPU, Python startup, and parallel downloads. 8 vCPU also unlocks 32 GiB RAM.

### 2.4 ComfyUI + "LTX-2.5 22B Q4"
- **Facts:**
  - LTX-2.5 is a real 22B open-weights audio+video model, released 2026-08-11.
  - Official files: dev/distilled DiT bf16 (**42.02 GB** each), Comfy int8-convrot (**21.5 GB**), distilled NVFP4 (**18.72 GB**, Blackwell only).
  - Text encoder: Gemma 4 12B with projections, bf16 **26.26 GB** or Comfy int8 **15.37 GB**.
  - Video VAE **1.47 / 1.45 GB** (DiffVAE / Conv), audio VAE **0.36 GB**, spatial x2 upscaler **1.0 GB**, temporal x2 upscaler 0.26 GB, distilled LoRA 8.9 GB.
  - The templates also use a prompt enhancer (`gemma4_e2b_it`), **enabled by default**.
  - Frames must satisfy `num_frames % 8 == 1`, and width and height must be divisible by 32. The example is 121 frames (≈5 s at 24 fps). There is an "auto duration" head. The model generates synchronized audio and supports T2V, I2V, V2V, text-to-audio and **audio-to-video** [FACT, HF repo/docs.ltx.io].
  - **Official requirements:** GPU 32 GB+ VRAM, 32 GB RAM, 100 GB disk, CUDA ≥ 12.7, and the ComfyUI page also says "CUDA-compatible GPU with 32GB+ VRAM" [FACT].
  - The "Q4" in the doc maps to **community** GGUFs (e.g. `unsloth/LTX-2.5-GGUF`: Q4_K_M **13.58 GB**, UD-Q4_K_XL 14.0 GB, Q5_K_M 15.63 GB, Q8_0 22.78 GB). Community Gemma GGUF: Q4_K_M **8.41 GB** [FACT: file sizes; provenance is third-party].
- **VRAM reasoning (estimates):**
  - DiT Q4_K_M weights are 13.6 GB. Add CUDA context plus PyTorch allocator overhead (~0.5–1.5 GB) and activations at the target resolution. The token count is roughly latent (W/32 × H/32 × ((F−1)/8+1)), e.g. 24×42×16 ≈ 16k video tokens at 768×1344×121f, plus audio tokens. That plausibly fits in 24 GB **for the DiT alone**.
  - The int8 TE (15.4 GB) cannot be resident at the same time, so ComfyUI must load the TE, encode, evict, load the DiT, sample, evict, then decode with the VAE (tiled).
  - Host RAM is where it breaks. ComfyUI offloads evicted models to system RAM. With 16 GiB RAM, the TE (15.4) and DiT (13.6) cannot both be cached, so every stage swap re-reads from disk, and a gen2 container OOM-kills the task.
  - Q4 GGUF also adds per-layer dequantization overhead and quality loss, and Lightricks has published no validation for it.
  - **Verdict:** L4 + Q4 is "may work, unsupported, POC required". L4 + **official int8** (21.5 GB DiT) almost certainly needs partial DiT offload to RAM per step, which is very slow [ASSUMPTION/POC].
- **Operational facts that matter:**
  - The LTX ComfyUI nodes "automatically download required models on first use." This must be disabled or blocked in production (egress, nondeterminism, cold start).
  - Disable or replace the default prompt enhancer (an extra model load).
  - Pin the ComfyUI and ComfyUI-LTXVideo commits.
  - Run ComfyUI headless, through the Python API or `--listen 127.0.0.1` driven by the entrypoint.
- **Product implication the doc misses.** LTX clips are seconds long. A 2–3 minute YouTube video is **tens of clips** (e.g. 150 s ÷ 5–10 s ≈ 15–30 clips), plus character and scene consistency work. GPU time scales roughly linearly with output seconds. The doc's 7.5 min per video is not grounded.

### 2.5 "VoiceStudio" TTS
- **Facts:** The most likely match is **`debpalash/VoiceStudio`**, licensed **AGPL-3.0** (GitHub API), with very high star activity. It is a desktop-first "AI voice studio" with CLI, Local API, MCP and Docker server images (`ghcr.io/debpalash/voicestudio:stable`, port 3900). Its default engine is **k2-fsa/OmniVoice** (code **Apache-2.0**). The Model Manager exposes "dozens of other engines," each with its own weight license. A different project, `LatentForge/voicestudio`, also uses the name [FACT].
- **Assessment.** The doc must say which project, which engine, which voice weights, and which license applies. The AGPL wrapper carries network-use obligations if modified. The app's architecture (desktop app, Bun) also adds weight to a GPU batch image.
- **Recommendation.** Call the chosen engine directly as a Python library (e.g. OmniVoice or another engine with clearly commercial-licensed **weights**) inside the worker. Record the license per voice model [REC]. VRAM is unknown [POC].

### 2.6 Whisper
- **Facts (openai/whisper, MIT):** large 1550M ≈10 GB VRAM; **turbo** 809M ≈6 GB, ~8× faster than large; medium ≈5 GB; small ≈2 GB. faster-whisper (CTranslate2) is MIT [FACT].
- **Assessment.** If the narration text comes from your own script, Whisper is only needed for **word timestamps/alignment** for captions. turbo or small via faster-whisper is enough and costs very little GPU time. It could even run in the CPU render job [TRADE-OFF].

### 2.7 GCS model storage (~50 GB)
- **Facts:**
  - GCS-to-Cloud Run in the same location is free [FACT, GCS pricing].
  - Singapore Standard storage is ≈ **$0.020/GB-month** (parsed from the pricing page, verify), so 50 GB ≈ **$1.00/month**.
  - Cloud Run GPU best practices: download from GCS **concurrently** (`gcloud storage cp` / transfer manager), use **Direct VPC egress (all-traffic) + Private Google Access** "to optimize ML model loading", and keep models in container images only if they are "<10 GB". GCS FUSE can use `cache-dir` on an **in-memory** volume and `enable-buffered-read`, and both count against container memory. **Rapid Cache** (SSD-backed GCS read cache) is available at extra cost [FACT].
- **Assessment.** The doc's caution about FUSE random reads is correct. Its plan to copy to temporary local storage was impossible at 16 GiB RAM before ephemeral disk existed. It is now possible with **ephemeral disk (GA 2026-11-04)**.
- **Working set** for the L4 path: Q4 DiT 13.58 + int8 TE 15.37 + Conv VAE 1.45 + audio VAE 0.36 + upscaler 1.0 ≈ **31.8 GB**, plus TTS/Whisper. A ≥40–50 GiB ephemeral disk needs a per-instance quota increase above 10 GiB [FACT: limits].

### 2.8 Artifact Registry and images
- **Facts:** Google recommends Deep Learning Containers or NGC base images, "store models in container images" only for models <10 GB, and Cloud Run uses image streaming ("optimized container streaming infrastructure") [FACT].
- **Assessment.** Keep model weights **out** of the image. The image still holds torch, CUDA user libraries, ComfyUI and custom nodes (my estimate is 8–15 GB [ASSUMPTION]). Pull and stream time on a cold node is part of billed GPU time [POC]. The CUDA 13.0 driver is fine for CUDA 12.x/13.0 user space. CUDA >13.0 requires forward-compat packages [FACT]. Keep Artifact Registry in asia-southeast1.

### 2.9 Cloudflare R2
- **Facts:**
  - Standard storage $0.015/GB-month, Class A $4.50/M, Class B $0.36/M, **egress free**. Free tier: 10 GB-month, 1M Class A, 10M Class B.
  - Presigned URLs: GET/HEAD/PUT/DELETE, expiry 1 s–7 days, **not usable with custom domains** (S3 endpoint only) [FACT].
- **Assessment.** A good choice for user-facing delivery. Note that **GCP→R2 is internet egress from GCP** (Premium tier, ≈ **$0.12/GiB** for the first TiB to NA/EU/Asia destinations per the VPC pricing table [FACT, but verify that Singapore falls in that row grouping]).
- **Recommendation.** Keep **intermediates in GCS in asia-southeast1** (free intra-region) and push **only final MP4s, thumbnails and user-visible assets** to R2. Also set an R2 location hint near the users (APAC) [REC].

### 2.10 Remotion + FFmpeg (CPU rendering)
- **Facts:**
  - Remotion is free for individuals or for-profits with **≤3 employees**. Otherwise a Company License is needed: Creators $25/seat/mo, **Automators $0.01/render, $100/mo minimum**, and "prompt-to-video apps" fit the Automators tier.
  - `@remotion/cloudrun` is "**Alpha** and not actively being developed" (8 vCPU/32 GB, 60 min limits) [FACT].
  - Cloud Run CPU jobs: up to 8 vCPU / 32 GiB, and the ephemeral disk is now available [FACT].
- **Assessment.** A separate CPU job is the right call. Do not render on the billed GPU. Use `@remotion/renderer` `renderMedia()` in your own Cloud Run CPU job (headless Chrome) rather than the alpha Cloud Run package. Use **two-pass** `loudnorm`.
- **Simplification for MVP [TRADE-OFF].** If the timeline is just concatenated clips, narration, music bed and burned-in captions, FFmpeg alone (concat demuxer + `subtitles`/ASS + `amix` + loudnorm) avoids Chromium, the license cost and memory spikes. Add Remotion when you need templated motion graphics.

### 2.11 AWS fallback (G5/A10G, Mumbai)
- **Facts:** `DescribeInstanceTypeOfferings` (read-only) shows **g5.xlarge/2xlarge, g6.xlarge/2xlarge, g6e.xlarge/2xlarge are offered in ap-south-1a and 1b**. AWS on-demand Linux prices, Mumbai:

| Instance | Spec | Price |
|---|---|---|
| g5.xlarge | A10G 24 GB, 4 vCPU/16 GiB, 250 GB NVMe | **$1.208/h** |
| g5.2xlarge | 8/32, 450 GB NVMe | $1.4554/h |
| g6.xlarge | **L4** 24 GB, 4/16, 250 GB NVMe | **$0.9664/h** |
| g6.2xlarge | 8/32, 450 GB NVMe | **$1.1739/h** |
| g6e.xlarge | **L40S 48 GB**, 4/32, 250 GB NVMe | **$2.235/h** |
| g6e.2xlarge | 8/64, 450 GB | $2.6927/h |
| gr6.4xlarge | L4, 16/128 | $1.8483/h |

  AWS Batch supports GPU `resourceRequirements` on EC2 compute environments, but **not on Fargate** [FACT].
- **Assessment.** The "A10G, Mumbai" fallback is outdated in the doc. **g6.2xlarge (L4, 32 GiB RAM, local NVMe) is cheaper than Cloud Run L4 8/32 in Singapore ($1.17 vs $1.71/h)** and has free local NVMe for model caching. **g6e.xlarge (48 GB)** meets LTX-2.5's official VRAM spec. The trade-offs are instance boot (minutes), EBS/AMI handling, and quota (G and VT vCPU limits often start low for new accounts [ASSUMPTION, check Service Quotas]).

### 2.12 Security
- **The doc's list is good.** Additions:
  - **Oracle-to-GCP auth.** A long-lived SA key on the Oracle VM is the main credential risk. Scope it to `roles/run.invoker`-equivalent `run.jobs.runWithOverrides` on one job plus execution read. Store it encrypted and rotate it. Evaluate Workload Identity Federation with a custom OIDC issuer later [REC].
  - **Worker secrets.** Put the R2 token in Secret Manager (mounted as a secret), scoped to a single bucket with object read/write only.
  - **Callback authenticity.** The worker should call back to Oracle over HTTPS with an HMAC- or OIDC-signed payload.
  - **Prompt and content moderation**, plus abuse rate-limits. These are a cost-control **and** a legal control.
  - **Signed URLs:** R2 presigned URLs only work on the S3 endpoint. Use a Worker or an app proxy if a branded domain is needed.
  - **AGPL/GPL hygiene:** keep a component license inventory.

### 2.13 Cost controls
- **Good in the doc:** concurrency 1, timeouts, billing alerts, app-level limits.
- **Add:**
  - **Budget spend caps (GA)**, which stop new job executions and fail in-progress tasks when the cap is hit [FACT]. Set the cap below the true ceiling, because enforcement uses estimated costs.
  - Per-user monthly GPU-second quotas.
  - Max output duration per tier.
  - **retries = 1 with idempotent resume** instead of 0.
  - An explicit **stuck-execution reaper** on Oracle (cancel executions over budget).

---

## 3. Strengths (decisions I defend)

1. **Control plane on free infrastructure, GPU on demand.** For a platform starting with "a handful of videos per month", a persistent GPU (even an L4 at roughly $0.97–1.71/h) is $700–1,250/month idle. Scale-to-zero batch is the only sane economics [REC].
2. **Cloud Run Jobs over Cloud Run Services for generation.** Jobs fit run-to-completion work, have no request timeout semantics, and per-execution overrides map cleanly to a job ID. GPU jobs are GA [FACT].
3. **Singapore as the primary region.** It is the closest region with confirmed L4 (and RTX PRO 6000) Cloud Run GPU support to South and Southeast Asian users. Mumbai L4 is invite-only [FACT].
4. **Models in GCS in the same region, not in the image.** Same-location transfer is free. Google itself recommends GCS for models >10 GB [FACT].
5. **R2 for user delivery.** There is zero egress for downloads, which dominate at scale for video [FACT].
6. **A sequential GPU stage rule.** It is correct given the VRAM numbers above. I keep it, applied within one image.
7. **Rendering separate from GPU generation.** CPU rendering on a GPU-billed instance wastes ≈$0.81/h of L4 time (Singapore L4 rate) [FACT-based].
8. **A provider-agnostic job interface and "fallback only on capacity errors".** These are good distributed-systems hygiene.
9. **The doc's own caveats are accurate:** billing alerts are not caps, the 7.5 min figure is illustrative, and GCS is not a local SSD.

---

## 4. Weaknesses and missing components

| # | Weakness / gap | Severity |
|---|---|---|
| W1 | The target model's official minimum (32 GB VRAM / 32 GB RAM) exceeds the target hardware (24 GB / 16 GiB). "Q4" is community, unvalidated. | **Critical** |
| W2 | 16 GiB host RAM cannot hold the TE and DiT for ComfyUI offload, and no local disk was planned. | **Critical** (fixable: 32 GiB + ephemeral disk) |
| W3 | Pricing uses Tier 1 rates for a Tier 2 region (−17% understatement). | High |
| W4 | "Two images, one GPU execution" is impossible as written on Cloud Run. | High |
| W5 | No checkpoint/resume. Retries=0. GPU tasks are terminated on maintenance. Long videos are at risk. | High |
| W6 | One execution per request means a full cold start and model fetch per video. There is no batching/drain mode. | High (cost) |
| W7 | Ambiguous TTS component and license (AGPL app). Remotion licensing not addressed. | High (legal) |
| W8 | Missing: Postgres backups, execution reconciliation and reaper, observability (structured logs, per-stage timings, GPU memory metrics), content moderation, per-user quotas, idempotency keys, dead-letter handling. | Medium |
| W9 | Egress from GCP to R2 is not costed. Intermediates go through R2 instead of staying in-region. | Medium |
| W10 | The fallback lists A10G only. It omits L4 (G6), L40S (G6e) and Cloud Run RTX PRO 6000. | Medium |
| W11 | Clip-based generation for 2–3+ minute videos (shot planning, consistency, the LTX duration limits) is not designed. | Medium (product) |
| W12 | No mention of disabling ComfyUI/LTX node auto-downloads or the default prompt enhancer. | Medium |
| W13 | Oracle VM is ARM64, which affects build targets. No HA/SLA. | Low–Medium |

---

## 5. Technical risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| LTX-2.5 Q4 on L4 OOMs or is unacceptably slow or low quality | **High** | Critical | POC gate (Section 12). Pre-approve the RTX PRO 6000 path or the g6e path. |
| Host RAM OOM (16 GiB) during TE/DiT swaps | **High** at 16 GiB, Medium at 32 GiB | High | 8 vCPU/32 GiB. Ephemeral disk. Never write models to the in-memory filesystem. |
| GPU capacity or quota unavailable in asia-southeast1 at peak (no reservations, best-effort) | Medium | High | Retry with backoff. Secondary region (europe-west4/us-central1, where latency is irrelevant for batch). AWS g6/g6e. |
| Maintenance termination mid-job (no live migration) | Medium per long task | Medium–High | Per-clip checkpoints to GCS. Resume. Retries ≥1. Keep tasks ≲1 h. |
| Ephemeral disk quota (10 GiB/instance default) not raised in time | Medium | High (blocks design) | File the quota request in week 1 (per-instance and regional). |
| Cold start (image + ~32 GB models + load) dominates cost for short videos | High | Medium | Drain mode. Smaller working set. Optionally Rapid Cache or a model-in-image layer for the hottest file (POC). |
| License non-compliance (AGPL TTS app, Remotion company license, LTX >$10M) | Medium | High | License inventory. Direct engine use. Budget for Remotion Automators or use FFmpeg only. |
| Oracle VM reclaimed or out of capacity, no SLA | Low–Medium | High | Off-box backups. IaC to rebuild. Consider the PAYG upgrade (free resources stay free). |
| Spend runaway (bug loops, abuse) | Medium | High | Spend cap (GA). Per-user quotas. Max executions/day. Reaper. |
| Community GGUF supply-chain risk | Low–Medium | Medium | Pin hashes. Mirror into your own bucket. Prefer official int8/NVFP4 where hardware permits. |

---

## 6. Performance bottlenecks (quantitative where possible)

Billed timeline per execution:
`instance + GPU attach (~5 s, documented)` → `image pull/stream [POC]` → `model fetch GCS→ephemeral disk [POC]` → `ComfyUI import + node init [POC]` → `TE load + encode` → `DiT load + sampling (dominant) [POC]` → `VAE decode (tiled)` → `TTS + Whisper` → `upload`.

- **Model fetch, illustrative only.** ~31.8 GB working set. At an *assumed* effective 500 MB/s it is ~64 s. At 200 MB/s it is ~160 s. Google says Direct VPC + PGA is needed for good throughput, and ephemeral disk docs note slower transfers without Direct VPC [FACT: guidance; throughput numbers are ASSUMPTIONS]. At $1.7051/h ($0.000474/s), **each 100 s of load costs ≈ $0.047**. That is significant against a target of ~$0.15–0.25 per video.
- **Disk-to-RAM-to-VRAM.** PCIe Gen4 x16 is 64 GB/s nominal [FACT]. In practice disk read and safetensors/GGUF parsing dominate. GGUF Q4 tensors are dequantized at compute time on the GPU [ASSUMPTION about the ComfyUI-GGUF behavior: verify].
- **Sampling.** The L4 has 121 dense BF16 TFLOPS and 300 GB/s [FACT]. The distilled model uses a fixed **8-step** schedule with CFG=1 [FACT], which helps a lot. Per-clip latency on the L4 is **unknown and must not be guessed** [POC].
- **VRAM.** Covered in 2.4. The TE and DiT must be serialized. VAE decode at high resolution must be tiled. Two-stage (x2 spatial upscaler) workflows add memory and time.
- **I/O to R2.** Uploads go over the internet from GCP. Use multipart and keep intermediates in GCS.
- **CPU render.** Remotion's headless Chrome is CPU- and memory-heavy. Measure frames/s per vCPU [POC].
- **Amortization.** With drain mode and N videos per execution, the fixed overhead per video falls by roughly 1/N [arithmetic].

---

## 7. Cost concerns (official prices, arithmetic shown)

**7.1 Doc's numbers check (Cloud Run pricing page, Jobs table, accessed 2026-11-10):**
- Tier 1 (us-central1 = asia-south1): CPU $0.000018/vCPU-s, memory $0.000002/GiB-s, L4 non-zonal $0.0001867/s.
  - L4 0.0001867×3600 = **$0.67212** ✔. CPU 4×0.000018×3600 = **$0.2592** ✔. Memory 16×0.000002×3600 = **$0.1152** ✔. So the **doc used Tier 1/Iowa/Mumbai rates**.
- **asia-southeast1 (Tier 2), Jobs:** CPU $0.0000216/vCPU-s, memory $0.0000024/GiB-s, **L4 $0.00022404/s**, **RTX PRO 6000 $0.00043826/s** [FACT].

| Config (Singapore, Cloud Run Jobs) | GPU $/h | CPU $/h | Mem $/h | **Total $/h** | 7.5 min | 30 × 7.5 min |
|---|---|---|---|---|---|---|
| Doc (Tier 1 rates, mislabelled) | 0.67212 | 0.25920 | 0.11520 | 1.04652 | 0.1308 | 3.92 |
| L4, 4 vCPU/16 GiB | 0.80654 | 0.31104 | 0.13824 | **1.25582** | **0.1570** | **4.71** |
| L4, 8 vCPU/32 GiB (recommended) | 0.80654 | 0.62208 | 0.27648 | **1.70510** | **0.2131** | **6.39** |
| RTX PRO 6000, 20 vCPU/80 GiB | 1.57774 | 1.55520 | 0.69120 | **3.82414** | 0.4780 | 14.34 |

- **Break-even.** RTX PRO 6000 is cheaper per clip than L4 8/32 only if it is **≥ 3.824/1.705 = 2.24× faster** [POC]. Given 96 GB (no offload, bf16/int8/NVFP4 native) against 24 GB with Q4 and offload, this is plausible but **unproven**.
- **Free tier.** Jobs: 240,000 vCPU-s and 450,000 GiB-s per month, applied as a spend discount at Tier 1 pricing. That is worth at most 240,000×0.000018 + 450,000×0.000002 = **$5.22/month**. **The GPU has no free tier** [FACT].
- **Delayed jobs (Preview).** Singapore CPU $0.00001512, memory $0.00000168, GPU unchanged, so L4 8/32 = 0.80654 + 0.43546 + 0.19354 = **$1.4355/h (−15.8%)**. Provisioning can be delayed up to 12 h, so it only fits an "economy/overnight" tier [FACT + arithmetic].
- **Instance-based billing note.** The pricing page states a **1-minute minimum** for instance-based billing on services. Whether the same minimum applies to jobs is not explicit in what I read [verify]. It is immaterial at multi-minute runtimes.
- **Ephemeral disk.** $0.000109589/GiB-hour (Tier 1 shown), so 50 GiB × 0.25 h ≈ $0.0014. Negligible.
- **GCS models.** 50 GB × ~$0.020 = **~$1.00/month** (verify the exact Singapore rate). Reads to Cloud Run in the same region are free [FACT].
- **GCP→R2 egress.** About $0.12/GiB Premium for the first TiB [FACT, verify the Singapore row]. Example [ASSUMPTION on sizes]: 30 clips × 15 MB = 450 MB, about $0.053 per video, i.e. **~25–33% of the GPU cost of a 7.5-minute run**. Keeping intermediates in GCS and exporting only a ~50–150 MB final MP4 brings this to about $0.006–0.018.
- **R2.** 1,000 videos/month × 100 MB = 100 GB → (100−10) × $0.015 = **$1.35/month**. Operations are negligible within the free tier [arithmetic on FACT prices].
- **Remotion.** If the company has more than 3 employees, **≥ $100/month minimum** (Automators) [FACT]. At low volume this can exceed the GPU bill.
- **Hidden per-video costs.** Cold start (Section 6), failed or retried runs, prompt-enhancer loads, two-stage upscaling, and Artifact Registry storage (verify the AR price per GB-month).

**7.2 Cross-provider hourly reference (official list prices, accessed 2026-11-10):**

| Option | GPU (VRAM) | Host | $/h | Notes |
|---|---|---|---|---|
| Cloud Run Jobs SG | L4 (24) | 8/32 | 1.705 | Scale-to-zero, ~5 s instance start, no local NVMe (ephemeral disk billed) |
| Cloud Run Jobs SG | RTX PRO 6000 (96) | 20/80 | 3.824 | Meets/exceeds LTX spec |
| AWS g6.2xlarge Mumbai | L4 (24) | 8/32, 450 GB NVMe | 1.174 | VM boot minutes; you manage the AMI and lifecycle |
| AWS g6e.xlarge Mumbai | L40S (48) | 4/32, 250 GB NVMe | 2.235 | Meets LTX VRAM spec |
| AWS g5.xlarge Mumbai | A10G (24) | 4/16 | 1.208 | Doc's fallback, now dominated by g6 |
| Modal | L4 / L40S / A100-80 / RTX PRO 6000 | + CPU/mem | 0.80 / 1.95 / 2.50 / 3.03 (GPU only) | Region pinning 1.15–1.75×. Page lists "non-preemptible … 3x base prices". $30/mo credits (Starter) |
| RunPod Serverless | 24 GB / 48 GB L40S / 80 GB A100 / 96 GB RTX 6000 Pro | n/a | 0.75 / 1.75 / 2.72 / 3.49 | Flex/active split not on page |

GCE G2 (L4) on-demand and Spot prices for asia-southeast1 could not be extracted from the dynamic pricing page. **UNVERIFIED in this round.**

---

## 8. Recommended changes (prioritized)

**P0: before any build-out**
1. **Run the model-feasibility POC first (Section 12).** Do it on Cloud Run L4 8/32 + ephemeral disk **and** on Cloud Run RTX PRO 6000. Pick hardware by **$/output-second at acceptable quality**, not by $/hour.
2. **Fix the sizing.** L4 jobs should use **8 vCPU / 32 GiB** (the maximum for the L4 tier). Add an **ephemeral disk of ≥50 GiB**, and request the per-instance and regional quota now.
3. **Fix the cost model.** Use asia-southeast1 Tier 2 rates and add egress, cold start and Remotion licensing.
4. **Use one GPU worker image** (ComfyUI + LTX nodes + TTS engine lib + faster-whisper). Load models stage-wise in the order **TTS → (Whisper alignment) → LTX**. Producing narration first lets you size clip durations to the speech, and optionally use LTX-2.5 **audio-to-video** conditioning [REC; quality is a POC].
5. **Resolve licenses.** Name the TTS engine and weights (avoid the AGPL desktop wrapper), decide on Remotion (license or FFmpeg-only MVP), and record LTX-2.x Community License compliance (<$10M revenue).

**P1: reliability and cost**
6. **Idempotent, resumable jobs.** Write a manifest in GCS listing clip IDs. On start, skip completed clips. Checkpoint after each clip. **Retries = 1**. Keep each task ≲ 60 min (Google's GPU best practice says "set a task timeout of one hour or lesser"). Split long videos into several executions or tasks.
7. **Drain-mode worker.** Each execution leases jobs from Oracle (an HTTPS lease API backed by `SKIP LOCKED`) until the queue is empty or it reaches a time budget (e.g. 45 min). Then it exits. This amortizes the cold start [REC].
8. **Model-loading path.** Direct VPC egress (all-traffic) + Private Google Access → parallel `gcloud storage cp` / transfer-manager into the ephemeral disk → load. Benchmark against GCS FUSE with `enable-buffered-read`, and against Rapid Cache [POC].
9. **Storage topology.** Keep intermediates in **GCS asia-southeast1** with a lifecycle rule that deletes them after 7 days. Send only finals, thumbnails and previews to R2.
10. **Spend cap (GA)** plus per-user GPU-second quotas, a max output duration per plan, and a reaper for executions over budget.
11. **Reconciliation.** Oracle polls execution state (`run.executions.get`) and does not rely only on worker callbacks. Callbacks must be signed.

**P2: hygiene and scale**
12. Pin ComfyUI, custom-node and model hashes. Block runtime downloads (no egress except GCS/R2/Oracle, or check hashes). Disable the prompt enhancer unless it proves its value.
13. Postgres backups to R2/GCS with restore drills. IaC (Terraform `google_cloud_run_v2_job`) for reproducibility. Multi-arch builds for the ARM VPS.
14. Observability: per-stage timings, peak VRAM/RAM, and cost per job written to Postgres. This is the data needed for pricing.
15. Update the fallback list: Cloud Run RTX PRO 6000 (SG/Delhi), **AWS g6/g6e (Mumbai)**, then serverless GPU vendors.

---

## 9. Alternative architectures considered

| Alternative | Pros | Cons | Verdict |
|---|---|---|---|
| **A. Cloud Run Jobs L4 8/32 + ephemeral disk (refined doc plan)** | GA, scale-to-zero, quota 3 by default, ~5 s instance start, minimal ops | Below LTX official spec. Tier 2 price. No local NVMe, so models are re-fetched every run. Maintenance kills tasks. | **MVP candidate if the POC passes quality/speed** |
| **B. Cloud Run Jobs RTX PRO 6000 (96 GB) SG** | Meets LTX spec with headroom. bf16/int8/NVFP4 native. No offload. Likely much faster [POC]. Same ops model as A. | 20 vCPU/80 GiB minimum, $3.82/h. A larger blast radius if a job loops. | **Strong candidate; decide by POC $/output-second** |
| C. Compute Engine G2 (L4) Spot/on-demand VM started per batch | Persistent disk/image with models pre-baked (no per-run fetch). Local SSD option. Spot discount. | Boot time in minutes. You manage start/stop, images, drivers and preemption. Price unverified this round. | Good at medium volume, or as a batch "burst" worker |
| D. GKE Autopilot/Standard with GPU node pools + image streaming | Best scaling control. Node-local caching across jobs. Spot pools. | Cluster fee and ops complexity far beyond MVP needs | Phase 3+, only at sustained volume |
| E. AWS Batch on EC2 g6/g6e (Mumbai) | g6.2xlarge $1.17/h is cheaper than A for the same GPU, with 450 GB NVMe. g6e meets spec. Batch handles queueing and scale-to-zero. | Instance boot plus container pull. Quota requests. A second cloud to operate. | **Primary fallback**. It could become primary if A/B fail on price. |
| F. Serverless GPU vendors (Modal, RunPod) | Fast cold starts with volume caching (vendor feature, verify). Broad GPU menu (L40S/A100/RTX PRO 6000). Simple Python deploy. | Vendor lock-in. Asia region pinning costs 1.15–1.75× (Modal). Preemption semantics. Data residency. | Good tertiary fallback, and a good POC bench |
| G. Hosted LTX API / fal.ai | No infrastructure. Official quality. | Per-second API pricing (not verified here). Less control. Margin risk. | Use as a **quality baseline** in the POC and as an emergency fallback |
| H. Persistent always-on GPU | Lowest latency, warm models | Hundreds of USD per month idle | Reject for MVP |

---

## 10. Recommended MVP deployment and scaling path

**MVP (Phase 0–2)**
- **Oracle A1:** Next.js + API + Postgres (with a `SKIP LOCKED` queue) + orchestrator/reconciler + signed-URL issuer. Nightly backups off-box.
- **GCP asia-southeast1:**
  - Artifact Registry.
  - GCS `video-models` (pinned, hashed) and `video-work` (intermediates, 7-day TTL).
  - **One Cloud Run GPU job** `gpu-worker`:
    - `nvidia-l4`, `--no-gpu-zonal-redundancy`, 8 vCPU/32 GiB, ephemeral disk 50–60 GiB.
    - Direct VPC egress all-traffic + PGA (and Cloud NAT if the worker must reach R2 or Oracle over the internet).
    - Secret Manager for the R2 and callback secrets, task timeout ≤ 60 min, retries 1, parallelism 1, in drain mode.
  - Stage order: TTS → Whisper alignment → LTX clips, with clip checkpoints to GCS.
  - **One Cloud Run CPU job** `render-worker` (FFmpeg-only first, Remotion when needed). It reads GCS and writes the final MP4 to R2.
- **Cloudflare R2:** finals, thumbnails and previews, delivered through presigned GET URLs.
- **Guardrails:** Budget spend cap, per-user quotas, max output seconds per plan, and a reaper.
- **Gate.** If the POC shows the L4 fails quality or speed, switch the same job definition to `nvidia-rtx-pro-6000` with 20/80 (a one-line change). Pricing then follows the measured $/output-second.

**Scale path**
1. **Tens of videos per day:** raise the GPU quota (more than 3 is not guaranteed). Set parallelism to N. Drain mode with N workers. Add a priority queue (paid before free). Delayed jobs for an "economy" tier, with the caveat that there is no GPU discount.
2. **Hundreds per day:** run a multi-region pool (europe-west4/us-central1 L4 or RTX PRO 6000; latency is irrelevant for batch). Add AWS Batch g6/g6e in Mumbai behind the same lease API.
3. **Sustained utilization above ~40–50% of a GPU:** evaluate GCE/GKE Spot with model-baked disks, or committed use. Note that Cloud Run CUDs apply to CPU/memory, and the GPU rows show no CUD discount on the pricing page.
4. **Control plane:** move Postgres to a managed service (Cloud SQL, or OCI PAYG) once paid users depend on it. Keep Oracle for the web tier if it is still adequate.

---

## 11. Evidence table

| # | Claim | Classification | Source |
|---|---|---|---|
| 1 | GPU for Cloud Run jobs is GA (2025-10-21) | Confirmed fact | Cloud Run release notes |
| 2 | L4 jobs regions include asia-southeast1. asia-south1 is by invitation only. | Confirmed fact | configuring/jobs/gpu |
| 3 | RTX PRO 6000 (96 GB) is available for jobs in asia-southeast1 and asia-south2 | Confirmed fact | configuring/jobs/gpu |
| 4 | L4 minimum 4 CPU/16 GiB. RTX PRO 6000 minimum 20 CPU/80 GiB. | Confirmed fact | configuring/jobs/gpu |
| 5 | Jobs CPU/memory maximum is 8 vCPU / 32 GiB (and 4 vCPU allows at most 16 GiB) | Confirmed fact (conflicts with #4 for RTX PRO 6000: verify) | configuring/jobs/cpu, memory-limits |
| 6 | GPU jobs require non-zonal redundancy. Failover is best-effort. | Confirmed fact | configuring/jobs/gpu |
| 7 | Automatic 3-GPU quota on first use, subject to availability | Confirmed fact | configuring/jobs/gpu |
| 8 | GPU instances start in about 5 s. GPU is billed for the whole instance lifecycle. | Confirmed fact | configuring/jobs/gpu |
| 9 | GPU task timeout up to 12 h (Preview). GPU tasks are not live-migrated. Expect interruptions. | Confirmed fact | configuring/task-timeout; release notes 2026-10-30 |
| 10 | Singapore Jobs prices: L4 $0.00022404/s, CPU $0.0000216/vCPU-s, memory $0.0000024/GiB-s | Confirmed fact | cloud.google.com/run/pricing (embedded regional table) |
| 11 | The doc's $1.04652/h equals Tier 1 (us-central1/asia-south1) rates | Confirmed fact (arithmetic) | Same |
| 12 | Jobs free tier is 240k vCPU-s and 450k GiB-s. No GPU free tier. | Confirmed fact | Same |
| 13 | Ephemeral disk is GA (2026-11-04): 1–100 GiB per volume, 10 GiB per instance by default, 100 GiB per region | Confirmed fact | release notes; configuring/jobs/ephemeral-disk |
| 14 | The default writable filesystem is in-memory and counts against instance memory | Confirmed fact | container-contract |
| 15 | GCS FUSE cache-dir uses an in-memory volume and counts against memory. Direct VPC + PGA is recommended. | Confirmed fact | gpu-best-practices; cloud-storage-volume-mounts |
| 16 | Baking models into the image is recommended only for models under 10 GB | Confirmed fact | gpu-best-practices |
| 17 | Budget spend caps for Cloud Run are GA (2026-10-12) | Confirmed fact | release notes; billing spend-cap docs |
| 18 | Delayed jobs (Preview) lower CPU/memory prices but not GPU prices | Confirmed fact | delayed-jobs; pricing |
| 19 | LTX-2.5 is a 22B audio+video model with the community license, free below $10M revenue | Confirmed fact | HF Lightricks/LTX-2.5; LICENSE-2_x |
| 20 | LTX-2.5 official minimum: 32 GB+ VRAM, 32 GB RAM, 100 GB disk | Confirmed fact | docs.ltx.io system-requirements; comfy-ui |
| 21 | LTX-2.5 file sizes (DiT bf16 42.02 / int8 21.5 / NVFP4 18.72; Gemma TE 26.26 / 15.37 GB) | Confirmed fact | HF API file listing |
| 22 | The "Q4" model is a community GGUF (Q4_K_M 13.58 GB) | Confirmed fact (third-party artifact) | HF unsloth/LTX-2.5-GGUF |
| 23 | L4 + Q4 LTX-2.5 fits and is usable for production quality | **Assumption requiring testing** | n/a |
| 24 | 16 GiB host RAM is insufficient for the TE+DiT ComfyUI offload | Evidence-supported recommendation (file sizes + RAM limit) | #21, #4 |
| 25 | NVFP4 requires Blackwell. The L4 (Ada) supports FP8, not FP4. | Confirmed fact | HF model card; NVIDIA L4 page |
| 26 | L4: 24 GB, 300 GB/s, 72 W, FP8 485 TFLOPS sparse | Confirmed fact | nvidia.com/l4 |
| 27 | Only one container per instance gets the GPU | Confirmed fact | configuring/jobs/gpu |
| 28 | "VoiceStudio" is most likely debpalash/VoiceStudio (AGPL-3.0), whose default engine is OmniVoice (Apache-2.0) | Confirmed fact (identity ambiguous: confirm with the author) | GitHub API, README |
| 29 | Whisper turbo needs about 6 GB VRAM, MIT license | Confirmed fact | github.com/openai/whisper |
| 30 | Remotion is free for ≤3 employees. Automators $0.01/render, $100/mo minimum. | Confirmed fact | Remotion LICENSE.md; remotion.pro/license |
| 31 | @remotion/cloudrun is Alpha and not actively developed | Confirmed fact | remotion.dev/docs/cloudrun |
| 32 | R2: $0.015/GB-mo, A $4.50/M, B $0.36/M, free egress. Presigned URLs do not work on custom domains. | Confirmed fact | developers.cloudflare.com/r2 |
| 33 | GCP internet egress Premium is about $0.12/GiB (first TiB) | Confirmed fact (Singapore row grouping to verify) | cloud.google.com/vpc/network-pricing |
| 34 | Oracle A1 Always Free: 2 OCPU/12 GB/200 GB, plus the idle-reclaim criteria | Confirmed fact | Oracle Always Free docs |
| 35 | g5/g6/g6e are offered in ap-south-1a/1b. Mumbai prices as tabled. | Confirmed fact | EC2 API (read-only); AWS public price JSON; G5/G6/G6e pages |
| 36 | Single GPU image + drain mode lowers cost per video | Evidence-supported recommendation | #8 billing semantics |
| 37 | RTX PRO 6000 is ≥2.24× faster than L4 for LTX-2.5 | **Assumption requiring testing** | n/a |
| 38 | FFmpeg-only rendering is enough for the MVP | Preference/trade-off | n/a |
| 39 | Model download throughput of 200–500 MB/s from GCS with Direct VPC | **Assumption requiring testing** | n/a |
| 40 | Modal/RunPod list prices as tabled | Confirmed fact (vendor pages) | modal.com/pricing; runpod.io/pricing |

---

## 12. Open questions, and the POCs and benchmarks required

**Questions for the doc author**
1. What target output: resolution, fps, clip length, total duration per tier, and is audio-from-LTX used or muted?
2. Which "VoiceStudio" (repo URL), which engine, and which voice weights (license per voice)? Is voice cloning in scope? If so, consent and legal flows are needed.
3. Is the company more than 3 people (Remotion), and could revenue approach $10M (LTX)?
4. What latency SLO per video (minutes? hours?). This decides whether delayed jobs or overnight batch are acceptable.
5. Is image-to-video with user uploads in scope? That affects moderation and storage.

**POCs (in order, each with pass/fail criteria)**
1. **LTX-2.5 feasibility matrix.** Test {L4 8/32 with Q4_K_M, Q5_K_M, Q8_0 GGUF, and official int8} × {RTX PRO 6000 20/80 with bf16/int8/NVFP4}. Use a fixed prompt set at the target resolution and 121/241 frames. Measure: peak VRAM, peak host RAM (OOM?), TE time, sampling time per clip, VAE decode time, and blinded quality rating against the API/bf16 baseline (option G). **Output: $/output-second.**
2. **Cold-start breakdown** on Cloud Run: instance start, image pull (with image size), GCS→ephemeral disk throughput (with and without Direct VPC, gcloud vs transfer manager vs FUSE buffered-read vs Rapid Cache), ComfyUI init, first-model load.
3. **Host-memory accounting.** Does the page cache from reading models off the ephemeral disk count toward the container memory limit and cause OOM? [unknown: test]
4. **Interruption handling.** Send SIGTERM mid-clip and verify that resume skips completed clips and the retry completes.
5. **TTS engine choice:** VRAM, real-time factor, quality, license. Whisper-turbo alignment accuracy against engine-native timestamps.
6. **Render.** FFmpeg-only against Remotion: vCPU-seconds per output minute at 8 vCPU/32 GiB. Two-pass loudnorm targets (e.g. −14 LUFS for YouTube) [ASSUMPTION about the target].
7. **Quota and capacity.** Confirm the automatic 3-L4 quota and the RTX PRO 6000 grant in asia-southeast1. Request ephemeral-disk quota above 10 GiB per instance and record the turnaround time.
8. **Spend cap drill.** Set a tiny cap in a test project and confirm that jobs stop starting.
9. **AWS fallback dry run:** g6.2xlarge/g6e.xlarge quota in ap-south-1, AMI boot to first frame time, AWS Batch GPU CE.

---

## 13. References (all accessed 2026-11-10)

- Cloud Run: configure GPUs for jobs: https://docs.cloud.google.com/run/docs/configuring/jobs/gpu
- Cloud Run: best practices, jobs with GPUs: https://docs.cloud.google.com/run/docs/configuring/jobs/gpu-best-practices
- Cloud Run: task timeout: https://docs.cloud.google.com/run/docs/configuring/task-timeout
- Cloud Run: ephemeral disk for jobs: https://docs.cloud.google.com/run/docs/configuring/jobs/ephemeral-disk
- Cloud Run: in-memory volume mounts (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/in-memory-volume-mounts
- Cloud Run: Cloud Storage volume mounts (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/cloud-storage-volume-mounts
- Cloud Run: NFS volume mounts (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/nfs-volume-mounts
- Cloud Run: container runtime contract: https://docs.cloud.google.com/run/docs/container-contract
- Cloud Run: memory limits (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/memory-limits
- Cloud Run: CPU limits (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/cpu
- Cloud Run: delayed jobs: https://docs.cloud.google.com/run/docs/delayed-jobs
- Cloud Run: release notes: https://docs.cloud.google.com/run/docs/release-notes
- Cloud Run: pricing: https://cloud.google.com/run/pricing
- Cloud Billing: spend cap budgets: https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps
- Cloud Run billing settings: https://docs.cloud.google.com/run/docs/configuring/billing-settings
- Cloud Storage pricing: https://cloud.google.com/storage/pricing
- VPC network pricing: https://cloud.google.com/vpc/network-pricing
- Optimize AI/ML workloads with Cloud Storage FUSE: https://docs.cloud.google.com/architecture/optimize-ai-ml-workloads-cloud-storage-fuse
- Lightricks LTX-2.5 (HF): https://huggingface.co/Lightricks/LTX-2.5 and file API https://huggingface.co/api/models/Lightricks/LTX-2.5/tree/main
- Lightricks org (HF): https://huggingface.co/Lightricks
- LTX-2.x Community License: https://github.com/Lightricks/LTX-2/blob/main/LICENSE-2_x
- LTX docs: system requirements: https://docs.ltx.io/open-source-model/getting-started/system-requirements
- LTX docs: ComfyUI: https://docs.ltx.io/open-source-model/integration-tools/comfy-ui
- Community GGUF: https://huggingface.co/unsloth/LTX-2.5-GGUF ; https://huggingface.co/elix3r/gemma4-12b-with-proj-ltx-2.5-GGUF
- ComfyUI day-0 LTX-2.5 support (secondary): https://blog.comfy.org/p/ltx-25-day-0-support-in-comfyui
- ComfyUI repo (GPL-3.0): https://github.com/Comfy-Org/ComfyUI
- NVIDIA L4: https://www.nvidia.com/en-us/data-center/l4/
- VoiceStudio: https://github.com/debpalash/VoiceStudio ; OmniVoice: https://github.com/k2-fsa/OmniVoice ; alternate project: https://latentforge.github.io/VoiceStudio
- OpenAI Whisper: https://github.com/openai/whisper ; faster-whisper: https://github.com/SYSTRAN/faster-whisper
- Remotion license: https://github.com/remotion-dev/remotion/blob/main/LICENSE.md ; pricing: https://www.remotion.pro/license ; Cloud Run package: https://www.remotion.dev/docs/cloudrun
- Cloudflare R2 pricing: https://developers.cloudflare.com/r2/pricing/ ; presigned URLs: https://developers.cloudflare.com/r2/api/s3/presigned-urls/
- Oracle Always Free resources: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- AWS EC2 G5: https://aws.amazon.com/ec2/instance-types/g5/ ; G6: https://aws.amazon.com/ec2/instance-types/g6/ ; G6e: https://aws.amazon.com/ec2/instance-types/g6e/
- AWS EC2 on-demand price data (Mumbai): https://b0.p.awsstatic.com/pricing/2.0/meteredUnitMaps/ec2/USD/current/ec2-ondemand-without-sec-sel/Asia%20Pacific%20(Mumbai)/Linux/index.json
- AWS Batch GPU jobs: https://aws.amazon.com/blogs/compute/creating-an-aws-batch-environment-for-mixed-cpu-and-gpu-genomics-workflows/ ; https://docs.aws.amazon.com/batch/latest/userguide/gpu-jobs.html
- Modal pricing: https://modal.com/pricing ; RunPod pricing: https://www.runpod.io/pricing

**Not verified this round:** GCE G2 (L4) Singapore on-demand and Spot prices (the page is dynamically rendered), the Artifact Registry per-GB price, the RTX PRO 6000 Server Edition bandwidth and FP4 figures (only third-party sources found), the R2 Class A/B classification of multipart uploads, and whether the 1-minute billing minimum applies to jobs.
