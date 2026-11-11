# 05 — Implementation Roadmap

| Field | Value |
|---|---|
| Basis | `04-final-architecture.md` |
| Principle | **De-risk the GPU and the licence before building the product.** The original roadmap built the web app first and discovered GPU feasibility in Phase 3. This plan inverts that. |
| Durations | Indicative, for a 1–2 person team. They are not commitments. |
| Rule | Every phase ends with **verification tasks**. A phase is not complete until its exit criteria are met with recorded evidence: logs, numbers, screenshots in `docs/poc/`. |

---

## Phase 0 — Gates and long-lead requests (start on day 1, run in parallel)

This phase comes before Phase 1. It has external lead times.

| Task | Owner | Exit evidence |
|---|---|---|
| Email Lightricks (or counsel) about LTX-2.x Attachment A **item 20** ("directly competes") and item 19 (watermark/provenance) for a text-to-video SaaS | Founder | Written response filed. **Paid launch is blocked until this exists.** |
| Choose the TTS engine. Verify its **weights** licence. Note that OmniVoice code is Apache-2.0 but its weights are unverified. | Eng | Licence text saved; decision recorded |
| Confirm Gemma 4 text-encoder terms and the Remotion licence tier (if Remotion is ever used) | Eng | Recorded |
| Decide data residency. Is APAC processing required? This picks **europe-west4** or **asia-southeast1**. | Founder | Decision recorded |
| Create GCP projects `vidgen-dev` and `vidgen-prod` with billing, budgets and a **spend cap** on prod | Eng | Screenshot of budget and cap configuration |
| File quota requests: Cloud Run L4 and RTX PRO 6000 (primary and secondary region), ephemeral disk per-instance > 10 GiB, AWS "Running On-Demand G and VT instances" (default 0) | Eng | Ticket IDs and turnaround times logged (POC-8) |

**Contingency if Lightricks says no or demands terms you can't afford.** Stop worker development. Re-run POC-3 with an alternative open video model whose licence permits SaaS use. The architecture does not change, only the `gpu-worker` workflow and the model manifest. Verify any candidate's licence from its official repository. Do not rely on memory or marketing.

---

## Phase 1 — Infrastructure foundation (≈ week 1)

**Goal:** minimal, reproducible infrastructure. No product UI yet.

Tasks:
1. **Terraform** for the GCP side, in a single region:
   - Artifact Registry repo
   - buckets `models` (versioned) and `work` (7-day lifecycle)
   - service accounts `gpu-worker`, `tts-worker`, `render-worker`, `oracle-dispatcher`, with the custom role from section 10 of `04`
   - Secret Manager secret for the R2 token
2. **Cloudflare:**
   - R2 buckets `video-output` and `db-backups`, with lifecycle rules
   - two scoped API tokens
   - DNS and proxy in front of the Oracle VM
3. **Oracle A1 hardening:**
   - SSH key-only
   - firewall allowing 80/443 from Cloudflare ranges only
   - Postgres on localhost
   - unattended upgrades
   - Docker/Compose or systemd
4. Postgres 16 installed, with **WAL-G/pgBackRest archiving to R2**.
5. A CI pipeline that builds arm64 (web) and amd64 (workers) images, scans them, and pushes by digest.

**Verification:**
- [ ] `terraform plan` is clean. Destroy and re-apply works in `dev`.
- [ ] **Restore drill:** restore Postgres from R2 onto a scratch VM. Record RTO (target ≤ 1 h) and RPO (target ≤ 5 min).
- [ ] An external port scan of the Oracle IP shows only 80/443, and only via Cloudflare.
- [ ] `oracle-dispatcher` credentials can run **only** the named jobs. Attempt a forbidden action and confirm it gets 403.

---

## Phase 2 — GPU worker (≈ weeks 1–3) — *the critical path*

**Goal:** answer "can we generate acceptable clips at an acceptable $/output-second, and on which GPU?"

Tasks:
1. **POC-1 (day 1–2):** deploy a trivial GPU job (`nvidia-smi && df -h && sleep 60`) on L4 8/32 with `--add-volume type=ephemeral-disk,size=50Gi` and `--no-gpu-zonal-redundancy`. Repeat on RTX PRO 6000 20/80.
2. Build the `gpu-worker` image:
   - CUDA, PyTorch, ComfyUI and ComfyUI-LTXVideo at **pinned commits**
   - auto-download disabled
   - prompt enhancer off
   - headless `worker_entrypoint.py` that takes `{job_id, clip_range, params}`
3. Mirror the slim model sets into `gs://…-models`, each with a **SHA-256 manifest**:
   - L4 arm: Q4_K_M and Q5_K_M GGUF DiT, int8 DiT, int8 and Q4 Gemma TE, VAE
   - RTX arm: NVFP4/bf16 distilled DiT, bf16 TE, VAE
4. **POC-2, staging benchmark.** Time to a ready-to-sample state for each of these paths:
   - (a) parallel `gcloud storage cp` over default egress
   - (b) a slim set baked into the image
   - (c) Direct VPC with Private Google Access
   - (d) GCS FUSE with buffered read

   Also chart container memory during loading to check the page-cache accounting.
5. **POC-3, LTX matrix.** Fixed prompt set (≥ 10 prompts × 3 seeds) at 720p and 1080p, 121 and 241 frames, single-stage distilled T2V/I2V. For every run, log:
   - peak VRAM (`torch.cuda.max_memory_allocated` plus `nvidia-smi` sampling)
   - peak host RSS
   - TE, DiT and VAE seconds
   - OOM events
6. Blinded quality rating of the L4 arms against the RTX PRO 6000 baseline (2+ raters, a simple 1–5 rubric: motion, prompt adherence, artefacts).
7. **POC-7:** cold image start time, from execution creation to first log line.

**Verification / exit criteria:**
- [ ] POC-1 passes on the chosen SKU. If the ephemeral disk is **not** supported with GPU jobs, switch to path (b), a baked image, and re-run POC-2.
- [ ] POC-2: staging is ≤ 15% of billed time for a typical execution, with no OOM at 32 GiB.
- [ ] POC-3: a table of **$/output-second per arm** at acceptable quality. Choose the production SKU by rule: RTX PRO 6000 wins only if it is ≥ 2.24× faster per output-second than L4 8/32.
- [ ] Decision recorded: GPU SKU, quantisation, resolution tiers per plan, and max frames per clip.
- [ ] **No invented numbers.** Every figure in the decision record links to a log.

---

## Phase 3 — Video generation pipeline (≈ weeks 3–5)

**Goal:** script in, assembled video out, run manually from the CLI with no web UI.

Tasks:
1. `tts-worker` CPU job. **POC-6:** real-time factor on 8 vCPU. If a 3-minute narration takes more than 5 minutes, or quality is poor, move TTS to the first stage of the GPU job instead.
2. Clip planner:
   - narration durations → clip list
   - `num_frames % 8 == 1`
   - frame rate as chosen
   - per-clip prompts derived from the script
3. GPU task logic:
   - TE encodes all prompts for the task, then DiT samples clips sequentially, then VAE decodes
   - write `gs://work/{job}/clips/{i}.mp4` plus a done-marker after **each** clip
   - deterministic seeds
   - skip clips that already exist
   - per-clip watchdog
   - exit codes mapped to {capacity, oom, timeout, validation, internal}
4. **POC-5, continuity:** a 2-minute script rendered with (a) multishot, (b) I2V last-frame chaining, (c) a LoRA if relevant. Rated by humans.
5. `render-worker` CPU job:
   - FFmpeg concat
   - ASS captions from forced alignment, or faster-whisper on CPU
   - background music ducking (`sidechaincompress`/`amix`)
   - **two-pass `loudnorm`** to platform targets (document the LUFS target chosen per platform)
   - aspect-ratio presets for Reels (9:16) and YouTube (16:9)
6. **POC-9:** render a 3-minute 1080p video and record vCPU-seconds and peak RAM.

**Verification:**
- [ ] End-to-end CLI run produces a correct 30 s Reel and a 2–3 min YouTube video with audio and visuals in sync (checked by eye at 5 points).
- [ ] **POC-4, resume test:** send SIGTERM to a GPU task mid-clip. The retry skips completed clips, the final output has no duplicate or missing clips, and billed time is recorded.
- [ ] A loudness meter on the output confirms the LUFS target ±1.
- [ ] Captions align within ±200 ms on sampled lines.

---

## Phase 4 — Job orchestration (≈ weeks 5–7)

**Goal:** a web user can submit, approve, track and cancel jobs safely.

Tasks:
1. Postgres schema: `jobs`, `job_events` (append-only), `quotas`, `plans`, `consents`, `moderation`.
2. Queue: `SKIP LOCKED` / pg-boss.
3. State machine (from `04` §4.2), using a **write-ahead `dispatching` state with an idempotency key**.
4. Dispatcher: calls `RunJob` with overrides and labels `job_id` on executions. Separate job definitions for TTS, GPU and render.
5. Reconciler cron (1–2 min). It handles these cases:
   - stuck in `running` past the timeout → cancel and fail
   - an execution with no DB row → cancel
   - all clip markers present → dispatch render
6. Approval gate UI after TTS: the user hears the narration and confirms before any GPU spend.
7. Moderation and validation **before dispatch**: prompt classifier, upload type/size/duration checks, and voice-clone consent capture.
8. App quotas:
   - per-user daily GPU-seconds
   - max output seconds per plan
   - per-user concurrency of 1
   - a global daily GPU-second ceiling
9. Next.js UI: format presets (Reels and YouTube durations, aspect ratios), progress display (clips k/n), cancel.

**Verification:**
- [ ] **Chaos tests:**
  - (a) kill the dispatcher between `dispatching` and `RunJob`
  - (b) kill it right after `RunJob` and before saving `exec_id`
  - (c) reboot Oracle mid-job

  Pass if the reconciler converges every time with no orphan or duplicate GPU executions.
- [ ] **Spend-cap test** in `dev`, using a tiny cap: confirm tasks fail, the dispatcher pauses, and jobs go to `paused_budget`.
- [ ] **Quota test:** a user exceeding daily GPU-seconds is blocked **before** dispatch.
- [ ] **Capacity simulation:** force a capacity-class error and confirm retries, then the fallback region, with no user-visible failure.

---

## Phase 5 — Storage and delivery (≈ weeks 7–8)

Tasks:
1. The render job uploads finals and thumbnails to R2 under `users/{user}/{job}/`.
2. An API endpoint issues **presigned GETs (15–60 min)** after an ownership check. These use the R2 S3 endpoint, because presigned URLs do not work on custom domains.
3. Lifecycle rules:
   - GCS work: 7 days
   - R2 finals: per retention policy
   - Artifact Registry: keep the last N digests
4. Duplicate the model bucket and job definitions in the **secondary region** (fallback 1).
5. Write the Modal/RunPod adapter interface (contract only; implement when needed).

**Verification:**
- [ ] User A cannot fetch user B's object: direct key guessing fails and an expired URL fails.
- [ ] Egress check: the GPU job shows **zero** internet egress, and the render job's egress is roughly equal to the final file size.
- [ ] A fallback-region dry run completes one job end to end.
- [ ] Lifecycle rules confirmed by objects disappearing on schedule in `dev` (use a short TTL in dev).

---

## Phase 6 — Monitoring and production hardening (≈ weeks 8–10)

Tasks:
1. Structured logs from all workers, with log-based metrics:
   - `stage_seconds`, `te_seconds`, `dit_s_per_clip`, `vae_seconds`
   - `peak_vram`, `peak_rss`
   - `exit_class`
2. Alerts for each of these:
   - OOM
   - a stuck job
   - capacity failures over threshold
   - spend at 50/80/100% of the cap
   - Oracle down for more than 2 minutes (external uptime check)
   - WAL archive lag over 15 minutes
3. Cloud Logging exclusions for verbose library output. Set a retention policy.
4. Move Oracle→GCP authentication from an SA key to **Workload Identity Federation (OIDC with uploaded JWKS)**.
5. **POC-10:** measured cost per finished minute, per format and plan, used to set pricing and quotas.
6. Runbooks:
   - Oracle rebuild
   - spend-cap trip
   - region outage, including failover
   - model upgrade (new manifest, canary, rollback)
   - licence/abuse takedown
7. Load test: N queued jobs against GPU concurrency limits. Verify queue fairness and that no job starves.
8. Re-evaluate the **phase-2 triggers**. If staging exceeds 15% of billed GPU time or usage exceeds ~100 busy GPU-hours a month, plan the warm-disk VM pool.

**Verification (production gate):**
- [ ] Lightricks/TTS licence evidence is on file (from Phase 0).
- [ ] All of POC-0 through POC-10 are recorded with evidence.
- [ ] A restore drill passed within the last 30 days.
- [ ] Spend cap, quotas and the approval gate have been verified in prod configuration.
- [ ] p95 end-to-end time and $/minute are within the targets set from POC-10.
- [ ] An incident drill was run: simulate a region capacity loss during business hours.

---

## Benchmark register (summary)

| ID | Phase | What | Decides |
|---|---|---|---|
| POC-0 | 0 | Licences | Whether to build on LTX-2.5 at all |
| POC-1 | 2 | Ephemeral disk on GPU job | Model storage path |
| POC-2 | 2 | Staging paths, page-cache memory | Caching strategy, Direct VPC yes/no |
| POC-3 | 2 | LTX matrix (L4 vs RTX PRO 6000) | GPU SKU, quantisation, resolution tiers |
| POC-4 | 3 | Resume under SIGTERM / cap | Retry count |
| POC-5 | 3 | Clip continuity | Long-video method |
| POC-6 | 3 | TTS real-time factor on CPU | TTS placement |
| POC-7 | 2 | Image cold start | Bake vs copy |
| POC-8 | 0 | Quota grants | Region and fallback readiness |
| POC-9 | 3 | FFmpeg render cost | Render job shape |
| POC-10 | 6 | $/finished minute | Pricing, quotas, phase-2 trigger |
