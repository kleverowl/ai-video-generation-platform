# 03 — Technical Debate (Rounds 1–3)

| Field | Value |
|---|---|
| Subject | Review of `architecture.txt`, "Complete Video Generation Platform: System Architecture & Infrastructure Plan" |
| Participants | **Agent 1**: Senior Cloud Solutions Architect (defender/improver). **Agent 2**: Principal DevOps / AI Infrastructure critical reviewer (challenger). **Chief Architect**: coordinator and arbiter. |
| Format | Agent Teams was not available in this Claude Code session. I used two independent subagents, each with a separate context, coordinated by a parent agent. |
| Dates | 2026-11-10 to 2026-11-11 |
| Round 1 | Independent reviews in full: `01-agent-1-review.md`, `02-agent-2-review.md`. Neither agent saw the other's file. |
| Round 2 | Each agent read the other's Round 1 review and responded point by point (Part C below, verbatim). |
| Round 3 | Each agent read the other's Round 2 response and gave a final position (Part D below, verbatim). |
| Labels | **[FACT]** confirmed technical fact with source. **[REC]** evidence-supported recommendation. **[ASSUMPTION]/[POC]** assumption that needs testing. **[TRADE-OFF]** preference or trade-off. |

---

## Part A — Disagreement ledger (Chief Architect summary)

Every material disagreement raised during the debate, how it was resolved, and its final classification.

| # | Topic | Agent 1 (R1) | Agent 2 (R1) | How it was resolved | Final classification |
|---|---|---|---|---|---|
| D1 | Singapore Cloud Run L4 price (4 vCPU / 16 GiB) | $1.2558/h | ~$1.12/h | Agent 2 conceded in R2. The official Cloud Run pricing page gives Singapore L4 at $0.00022404/s, 1.2× Tier 1. **The original document's $1.04652/h is the Tier 1 rate (Iowa/Mumbai) applied to a Tier 2 region.** | **[FACT]** |
| D2 | GPU job task timeout | "12 h is Preview" | "1 h GA cap" | Agent 2 withdrew in R3. Quotas page: "12 hours if using GPUs". The task-timeout page marks 12 h as Preview. Best practices: "one hour or lesser". Maintenance terminates GPU tasks. **Design outcome unchanged: tasks ≤45 min, with checkpoints.** | **[FACT]** |
| D3 | Cloud Run Jobs vs stop/start Compute Engine L4 VM for long videos | Cloud Run Jobs | GCE VM with models on PD | Both converged. **Cloud Run Jobs for the MVP**, because GA budget spend caps cover Cloud Run but not Compute Engine, stopped VMs are zonal (stockout on restart), and a VM adds driver and OS ownership. Move to a warm-disk VM when the measured triggers fire. | Spend-cap coverage **[FACT]**. Break-even (~100 busy GPU-h/month) **[ASSUMPTION]**. Choice **[TRADE-OFF]** |
| D4 | VM vs Cloud Run maintenance notice | — | — | Agent 1 found and Agent 2 confirmed: GCE GPU VMs get **1 h** notice; Cloud Run gets a **10 s** SIGTERM. A real advantage for the VM in phase 2. | **[FACT]** |
| D5 | Is L4 24 GB enough? | "Viable only after POC" | "May not suffice" | Converged. Lightricks' official minimum is **32 GB+ VRAM and 32 GB system RAM** (re-verified by the Chief Architect). The Q4 GGUF is community-made, not official. The official int8 DiT (21.5 GB) is unlikely to be fully VRAM-resident on 24 GB. **POC baseline on spec-compliant hardware; L4 is the cost-down experiment.** | Minimums **[FACT]**. L4 fit **[POC]** |
| D6 | 4 vCPU / 16 GiB | Too small; 8/32 | Too small; 8/32 | Agreed from Round 1. The in-memory filesystem counts against RAM. | **[FACT]** |
| D7 | Model staging path | Direct VPC + Private Google Access + parallel download to ephemeral disk | Ephemeral disk quota and GPU compatibility unclear; FUSE "requires" Direct VPC | Both corrected. (a) GCS is reachable **without** Direct VPC. (b) Direct VPC is capped at **1 Gbps per instance**, with startup delays of a minute or more (+30 s with NAT). (c) The 100 GiB regional ephemeral-disk quota is auto-granted; the **10 GiB per-instance default** is the gate. (d) **Ephemeral disk + GPU jobs compatibility is undocumented.** Default egress is the baseline; Direct VPC is a benchmark arm. | Limits **[FACT]**. GPU compatibility and fastest path **[POC]** |
| D8 | Cloud Run budget spend caps | GA 2026-10-12 | (not raised) | Agent 2 verified independently: "Jobs: new task executions fail to start, and in-progress tasks fail to complete." Caps are estimated, monthly, per project + service. **A cap trip kills in-flight GPU work, so checkpointing is mandatory.** | **[FACT]** |
| D9 | Pipeline order | TTS → Whisper → LTX (A2V) | Narration first; TTS + Whisper off GPU | Converged on **narration first**, then the clip plan from measured durations. TTS runs **before** the GPU job so the user approves the script and voice before GPU spend. Alignment on CPU. | **[REC]** / **[TRADE-OFF]** |
| D10 | Audio-to-video (A2V) mode requirements | Official ComfyUI A2V uses the distilled model | A2V needs the dev DiT + distilled LoRA | **Both partly right, per source.** The PyTorch `ltx-pipelines` A2Vid uses dev + LoRA (LTX-2 README). The **official ComfyUI workflow `LTX-2.5_A2V_Two_Stage_Distilled.json` loads the distilled bf16 checkpoint, CFG 1, two stages with a 2× upscale** (re-verified by the Chief Architect at docs.ltx.io). Either way it is heavier than single-stage T2V/I2V, so it is **not the MVP default**. | **[FACT]** |
| D11 | Two images, one GPU execution | Contradictory; one image | Contradictory; one image | Agreed. "The GPU can only be attached to one container." | **[FACT]** |
| D12 | "VoiceStudio" | Likely debpalash/VoiceStudio (AGPL-3.0); call the OmniVoice engine directly | Same identification; AGPL app, not a library | Agreed. The **OmniVoice weights licence is unverified**. Voice-clone consent is required. | **[FACT]** (repo licence). Weights **[ASSUMPTION]** |
| D13 | Intermediate storage | Same-region GCS; R2 only for finals | Cloud NAT and egress costs | Converged. **The GPU job writes only to GCS; the CPU render job uploads finals to R2.** GCP→internet egress is ~$0.12/GiB. | **[FACT]** pricing. **[REC]** design |
| D14 | Fallback order | AWS g6 Mumbai | Other GCP region first | Agent 1 conceded. AWS G/VT on-demand quota **defaults to 0**. Mumbai Cloud Run L4 is **invitation-only**. Order: other Cloud Run region → other Cloud Run GPU → Modal/RunPod → AWS g6/g6e after quota. | **[FACT]** quotas. Order **[REC]** |
| D15 | Default GPU region | Tier 1 (europe-west4) unless residency forbids | Tier 1 unless residency forbids | Converged in R3. Async batch has no latency requirement. Tier 1 is 16.7% cheaper. | **[FACT]** prices. **[TRADE-OFF]** residency |
| D16 | Drain-the-queue worker | Proposed (amortise cold start) | Idle-waiting wastes GPU time; multi-tenant hygiene | Converged on **drain-on-lease only**: process what is queued at start, never wait idle, per-job scratch directories. | **[REC]** |
| D17 | Oracle → GCP authentication | WIF possible | No off-the-shelf OCI WIF; scoped SA key | Converged. Use a narrowly scoped SA key (custom role on one job, rotated) for the MVP. Move to **WIF OIDC with an uploaded JWKS** before paid launch. | **[FACT]** WIF docs. **[TRADE-OFF]** timing |
| D18 | Per-video cost target | $0.15–0.25 | Unsupported | Agent 1 withdrew. **No per-video target until the POC measures $/output-second.** | **[ASSUMPTION]** withdrawn |
| D19 | LTX-2.x licence Attachment A item 20 ("directly competes") | Missed in R1 | Critical | Agent 1 conceded. **Gate 0: written clarification from Lightricks before building.** | Text **[FACT]**. Applicability is a legal question |
| D20 | Remotion | Licence required above 3 employees | Same | Converged on an **FFmpeg-only MVP**. Remotion later if templating is needed. `@remotion/cloudrun` is alpha and not actively developed. | **[FACT]** / **[TRADE-OFF]** |

### Items that remained open at the end of Round 3 (both agents)

Ephemeral disk on GPU jobs · fastest staging path · LTX-2.5 fit, speed and quality on L4 · page-cache accounting against the memory limit · TTS placement (CPU vs GPU) · clip-to-clip visual consistency · actual quota grants · data-residency choice · whether licence item 20 applies. These are carried into `05-implementation-roadmap.md` as named POCs.

### Valid arguments each agent explicitly acknowledged from the other

- **Agent 1 acknowledged from Agent 2:**
  - licence item 20
  - AWS quota defaults to 0
  - the Direct VPC 1 Gbps cap invalidating Agent 1's 200–500 MB/s estimate
  - Cloud NAT cost
  - a spec-compliant POC baseline
  - the write-ahead `dispatching` state machine
  - TTS-before-GPU approval UX
  - a Tier 1 region as default
  - drain mode giving little benefit at low volume
  - no unbenchmarked cost target
  - voice-clone consent
  - Oracle hardening detail
- **Agent 2 acknowledged from Agent 1:**
  - Singapore pricing
  - spend caps are GA
  - no "1 h GA" wording in the docs
  - Direct VPC is an optimisation, not a requirement
  - ephemeral-disk quota detail
  - the 1 h maintenance notice on VMs
  - int8 DiT unlikely to fit in 24 GB
  - the GPU→GCS / render→R2 split
  - the documented WIF JWKS path
  - same-region GCS transfer is free
  - exact model file sizes
  - the 32 GB RAM minimum
  - the auto-download and prompt-enhancer hazards
  - R2 presigned URLs do not work on custom domains

---

## Part B — Round 1 (independent evaluations)

The full Round 1 texts are in `01-agent-1-review.md` and `02-agent-2-review.md`. They are not repeated here to avoid duplication.

---

## Part C — Round 2: Agent 1 responds to Agent 2 (verbatim)


### Round 2: Agent 1's Response to Agent 2's Review

| Field | Value |
|---|---|
| Author | Agent 1 (Senior Cloud Solutions Architect) |
| Date | 2026-11-11 |
| Inputs | `02-agent-2-review.md` (read in full) and my own `01-agent-1-review.md` |
| Method | I re-checked every contested claim against official sources on 2026-11-10/11. For the Cloud Run price I parsed the per-region data embedded in the official pricing page. I also re-read the LTX-2.x licence text, the Cloud Run quotas, task-timeout, ephemeral-disk and billing-settings pages, the Cloud Billing spend-cap guide, the Compute Engine GPU host-maintenance page, the WIF OIDC and X.509 guides, the AWS EC2 quota table, and AWS's public price JSON. |
| Labels | **[FACT]** confirmed technical fact (URL given). **[REC]** evidence-supported recommendation. **[ASSUMPTION]** requires testing. **[TRADE-OFF]** preference. |

---

#### Part A: Contested points

##### A1. Singapore Cloud Run L4 price: $1.2558/h (mine) or ~$1.12/h (Agent 2)?

**Verdict: Agent 2 is wrong. I keep $1.2558/h for 4 vCPU/16 GiB and $1.7051/h for 8 vCPU/32 GiB.** [FACT + arithmetic]

**Where the numbers come from.** The official page https://cloud.google.com/run/pricing renders its tables client-side from per-region data embedded in the HTML. I parsed the **Singapore (asia-southeast1)** block of the **Jobs** table. I identified it because it lists only *non-zonal* GPU rows, which matches the Jobs table, and jobs support only non-zonal GPUs (per https://docs.cloud.google.com/run/docs/configuring/jobs/gpu). It shows:

| Rate | Singapore (Tier 2) | Iowa / Mumbai (Tier 1) | Ratio |
|---|---|---|---|
| CPU | $0.0000216 per vCPU-second | $0.000018 | 1.2 |
| Memory | $0.0000024 per GiB-second | $0.000002 | 1.2 |
| NVIDIA L4, non-zonal | **$0.00022404 per second** | $0.0001867 | 1.2 |
| RTX PRO 6000, non-zonal | $0.00043826 per second | $0.00036522 | 1.2 |

- Every Singapore block on the page that contains an L4 row (services, jobs, delayed jobs, worker pools) shows $0.00022404.
- The Tier 2 uplift of exactly 1.2× applies to the GPU too, not only to CPU and memory.
- Jobs are billed for the whole instance lifecycle (instance-based). The GPU page says "GPU is billed for the entire duration of the instance lifecycle."

**Arithmetic, 4 vCPU / 16 GiB / L4, Singapore**

| Item | Calculation | $/h |
|---|---|---|
| GPU | 0.00022404 × 3600 | 0.806544 |
| CPU | 4 × 0.0000216 × 3600 | 0.311040 |
| Memory | 16 × 0.0000024 × 3600 | 0.138240 |
| **Total** | | **$1.255824/h** |

**Arithmetic, 8 vCPU / 32 GiB / L4, Singapore**

| Item | Calculation | $/h |
|---|---|---|
| GPU | 0.00022404 × 3600 | 0.806544 |
| CPU | 8 × 0.0000216 × 3600 | 0.622080 |
| Memory | 32 × 0.0000024 × 3600 | 0.276480 |
| **Total** | | **$1.705104/h** |

**Why Agent 2's figure is low.** Agent 2's table uses the **Tier 1 GPU rate** ($0.67212/h) and labels it "Tier 2 GPU rate not verified". Their uplift reached only CPU and memory, so they understate by $0.134/h:
- 4 vCPU / 16 GiB: $1.12 against the correct $1.256, a 10.8% understatement.
- 8 vCPU / 32 GiB: $1.57 against the correct $1.705, a 7.9% understatement.

Every per-video figure in Agent 2's Hidden-cost table B should be scaled up by those factors. Their sensitivity *conclusions* (the 1 h cap is exceeded at 30 clips × 3 min) are unaffected.

**Free tier.** It covers CPU and memory only: 240k vCPU-s and 450k GiB-s per month, worth at most about $5.22. The GPU has none. Both reviews agree on this.

##### A2. A stop/start Compute Engine L4 VM against Cloud Run Jobs for 2–3 minute videos

**Verdict: Partially agree.** A G2 VM has a lower unit price and two real technical advantages. For the MVP, though, Cloud Run Jobs wins on risk and cost at low volume, and the "1 h cap" argument disappears once the work is chunked, which both reviews already require. I would make the VM the **phase-2 path for sustained volume**, not the MVP default.

**Numbers I can source**
- **g2-standard-8 (L4, 8 vCPU / 32 GB) in asia-southeast1: $1.0531/h on demand.** This is a third-party figure (Holori, data 2026-11-08). The official GCE pricing page is client-rendered and I could not extract it. **Unverified.** Spot shows $0.9083/h, an unusually small discount, so treat it as suspect.
- **Cloud Run L4 8/32 in Singapore: $1.7051/h** [FACT]. The VM is about **38% cheaper per busy hour**, if the Holori figure holds.
- **Persistent disk while stopped: price unverified this round.** I assume roughly $0.10–0.12/GB-month for balanced PD, so a 200 GB disk costs about **$20–24/month fixed** [ASSUMPTION].
- **GPU host maintenance on GCE.** Instances with GPUs "can't be live migrated" and "must be stopped", but the metadata server gives **1 hour of advance notice**. Maintenance "typically occur[s] once every two weeks". Source: https://docs.cloud.google.com/compute/docs/gpus/gpu-host-maintenance [FACT]. **Cloud Run gives only 10 s of SIGTERM** [FACT]. This is a genuine VM advantage that Agent 2 did not claim.
- **Stockout on start.** A stopped VM and its PD are zonal. Restarting can fail with `ZONE_RESOURCE_POOL_EXHAUSTED`. Moving to another zone means a snapshot or disk clone and recreating the VM. Source: https://docs.cloud.google.com/compute/docs/troubleshooting/troubleshooting-resource-availability [FACT for the error class]. A Cloud Run GPU job "routes job executions to other zones only if sufficient GPU capacity is available" [FACT]. Neither is guaranteed, but the VM needs **more orchestration to recover**.
- **Spend caps.** Spend-cap budgets cover only **Gemini API, Vertex/Agent Platform, Cloud Run and Cloud Run functions**. **Compute Engine is not eligible.** Source: https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps [FACT]. A runaway G2 VM ($1.05/h, about $769/month) has **no platform-level hard stop**. A Cloud Run job does.
- **Boot to first denoising step:** not documented. **POC** for both platforms.

**Illustrative monthly comparison.** These figures are not measurements. Assumptions [ASSUMPTION]:
- Cloud Run staging per execution: 3 min.
- VM: 2 min boot plus a 10 min idle tail per wake.
- 200 GB PD at $22/month.

Formulas:
- Cloud Run = 1.7051 × H + E × 0.05 h × 1.7051
- VM = 1.0531 × (H + E × 0.2 h) + 22

where H is busy GPU-hours and E is executions (Cloud Run) or wakes (VM).

| Busy GPU-h per month (H) | Executions/wakes (E) | Cloud Run | GCE VM | Cheaper |
|---|---|---|---|---|
| 10 | 40 | 17.05 + 3.41 = **$20.5** | 1.0531 × 18 + 22 = **$41.0** | Cloud Run |
| 100 | 300 | 170.5 + 25.6 = **$196.1** | 1.0531 × 160 + 22 = **$190.5** | about even |
| 300 | 600 | 511.5 + 51.2 = **$562.7** | 1.0531 × 420 + 22 = **$464.3** | VM (−17%) |

**On the "1 h cap".**
- The current quota page lists the GPU maximum task timeout as "**12 hours if using GPUs**" (https://docs.cloud.google.com/run/quotas).
- The task-timeout page labels long-running GPU jobs as **Preview** and adds: "For tasks using GPUs, the maximum available timeout is 12 hours (preview)." The best-practices page says "Set a task timeout of one hour or lesser" [FACT].
- So ≤1 h is the safe GA envelope. I found no current page that states "1 h GA" verbatim; Agent 2's citation is "as surfaced by search".
- Either way, both reviews already split videos into checkpointed tasks of 40–60 minutes or less, so the cap no longer argues for VMs.

**On re-staging every execution.** This is a real Cloud Run cost. It is mitigated by (a) drain or batch mode, where one execution serves many clips or videos, and (b) a slim model set. The VM's genuine edge is **warm models across consecutive jobs** without that design work.

**Operational overhead of a VM driven from Oracle:**
- start and stop API calls;
- handling `ZONE_RESOURCE_POOL_EXHAUSTED` by retrying another zone, which requires a pre-replicated disk image;
- an idle self-shutdown watchdog plus an external alert;
- OS, driver and CUDA patching;
- a golden image pipeline.

That is roughly a week of extra engineering plus ongoing patching [ASSUMPTION], and none of it exists on Cloud Run.

**Classification.** Unit prices: FACT for Cloud Run, third-party for G2. Maintenance and spend-cap scope: FACT. Break-even: ASSUMPTION. Overall: **TRADE-OFF**. **Decision rule:** move to a VM, MIG or GKE when measured busy GPU time exceeds roughly 100 h/month, or when the measured per-execution staging exceeds about 20% of execution time.

##### A3. Fallback order

**Verdict: I concede that Agent 2's order is better for the next 3–6 months.** I keep one correction on AWS pricing.

- **AWS default quota is 0.** "Running On-Demand G and VT instances | 0 | Yes (adjustable)". Source: https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html [FACT]. My Round 1 said quotas "often start low". The correct statement is **0 by default**, which makes AWS non-functional until quota is granted.
- **A second Cloud Run region** uses the same image, IAM, job contract and spend-cap coverage, with no new integration, and gets an automatic 3-GPU grant per region on first deploy [FACT]. It is also **cheaper**: us-central1 and europe-west4 are Tier 1, so L4 8/32 = 0.67212 + 8 × 0.000018 × 3600 + 32 × 0.000002 × 3600 = 0.67212 + 0.5184 + 0.2304 = **$1.42092/h**, which is **16.7% below Singapore** [FACT + arithmetic].
  - Caveats: us-central1 L4 "might require a quota increase request" to scale [FACT]. The model bucket must be replicated to that region (about $1/month). Data residency must be acceptable.
  - **Because work is async batch, I would even consider europe-west4 or us-central1 as primary.** [TRADE-OFF]
- **Correction to Agent 2:** the g6.xlarge Mumbai price **is** officially verifiable. AWS's public on-demand price JSON gives **$0.9664/h** (g6.2xlarge **$1.1739/h**, g6e.xlarge **$2.235/h**). A read-only `DescribeInstanceTypeOfferings` call shows g5, g6 and g6e offered in **ap-south-1a and 1b** [FACT]. AWS keeps the lowest L4 unit price of any option I found, but only after a quota request and a second-cloud integration.

**Revised fallback order (my position now):**
1. Cloud Run L4 in a Tier 1 region (europe-west4 or us-central1).
2. Cloud Run RTX PRO 6000 in Singapore or Delhi (if the L4 POC fails on VRAM) [FACT: regions].
3. Modal or RunPod serverless (no quota ticket; same container).
4. AWS g6/g6e in Mumbai, only after G/VT quota is granted and volume justifies a second cloud.

**Required now:** file every quota request in week 1. Agent 2 and I agree on this.

##### A4. Intermediate assets: GCS in the same region, R2 only for finals

**Verdict: Agree. We converged independently.**
- GCS to Cloud Run in the same location is **free**. The GCS pricing page says "Data moves within the same location" is free. Agent 2 marked this "ASSUMED"; it is in fact confirmed [FACT, https://cloud.google.com/storage/pricing].
- GCP to R2 is Premium-tier internet egress, about **$0.12/GiB** for the first TiB [FACT, https://cloud.google.com/vpc/network-pricing].

**One addition from Agent 2 that I missed: Cloud NAT.** Google's model-loading guidance prescribes Direct VPC egress `all-traffic` plus Private Google Access [FACT, gpu-best-practices]. With that setting, any internet egress (R2, Oracle callbacks or leases) needs **Cloud NAT**: gateway, IP at $0.005/h [FACT, network-pricing], plus per-GiB processing (rate not verified).

**Refinement [REC]:**
- The **GPU job writes only to GCS**: clip checkpoints, progress markers, manifest.
- The **CPU render job runs without Direct VPC**, reads from GCS, and uploads the final file to R2.
- Oracle learns progress by polling execution state and GCS markers, not from worker callbacks.
- That takes R2 and NAT out of the GPU job entirely.
- If drain mode needs the worker to lease jobs from Oracle over the internet, NAT returns. The alternative is to pass the batch of job IDs in the execution overrides. That choice is a [TRADE-OFF], resolved by POC #2 (throughput with and without Direct VPC).

##### A5. Do Cloud Run budget spend caps exist, are they GA, and do they stop jobs?

**Verdict: Re-verified. I do not retract.** [FACT]
- Release notes, 2026-10-12: "Support for Budget spend caps to pause your Cloud Run workloads is in **General Availability (GA)**." (https://docs.cloud.google.com/run/docs/release-notes)
- Cloud Run billing settings: "When you configure Cloud Billing Budget spend caps … those caps automatically apply to all Cloud Run resource types in your project … **Jobs: new task executions fail to start, and in-progress tasks fail to complete.**" (https://docs.cloud.google.com/run/docs/configuring/billing-settings)

Caveats from the Cloud Billing guide (https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps):
- The cap uses "gross, estimated usage costs". It does not include savings or credits.
- Each budget covers "a single Google Cloud project and a single eligible service".
- The budget period is monthly only.
- Persistent resources keep accruing charges.
- Eligible services are Gemini API, Agent Platform/Vertex, **Cloud Run**, and Cloud Run functions. **Compute Engine is not eligible** (relevant to A2).
- Billing settings also note that Serverless VPC Access connector VMs are not covered. Use Direct VPC.

**Implication:** set the cap below the true ceiling, keep app-level quotas, and note that a cap trip kills in-flight tasks. Checkpointing is what makes that tolerable.

##### A6. Oracle-to-GCP authentication

**Verdict: Partially agree.** A narrowly scoped SA key is acceptable for the MVP. I disagree that the only alternative is "a self-run OIDC issuer" with nothing better to offer. Two **documented** WIF paths remove the long-lived *Google* credential:
1. **WIF with OIDC and an uploaded JWKS.** "You can upload an OIDC JWKS file directly to Google Cloud … when [the] URL isn't publicly accessible" (up to 8 keys) [FACT, https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-other-providers].
   - The VPS signs short-lived JWTs (5 minutes) with a local key.
   - Google STS exchanges them for a 1 h access token.
   - An attribute condition pins `sub`/`aud`.
   - No public issuer endpoint is needed.
2. **WIF with X.509 certificates (mTLS).** Register your own CA as a trust anchor. Workloads "obtain short-lived Google Cloud credentials through a mutual TLS (mTLS) connection" [FACT, https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-x509-certificates]. Keep the CA offline and issue 30-day client certificates to the VPS.

**Honest assessment.** Both still put *a* private key on the VPS. The gains are [REC]:
- Google tokens are short-lived.
- The org policy `iam.disableServiceAccountKeyCreation` can be enforced.
- Revocation happens at the pool or provider in one step.
- Attribute conditions apply.

The marginal security gain over a well-scoped, rotated SA key is **modest**. The larger controls are the **custom role** (only `run.jobs.runWithOverrides`, `run.executions.get/list/cancel` on one job, as both reviews say) and the **spend cap**, which bounds the blast radius of a key leak.

**Recommendation:** an SA key for the MVP, then WIF-OIDC with an uploaded JWKS before paid launch [TRADE-OFF]. I did not verify whether OCI Identity Domains can act as a native OIDC issuer for this. I make no claim about it.

##### A7. Agent 2 claims I consider wrong, overstated or unsupported

| Agent 2 claim | My position | Evidence |
|---|---|---|
| Singapore L4 is about $1.12/h (Tier 1 GPU rate) | **Wrong.** The GPU is also uplifted to $0.00022404/s. | A1 [FACT] |
| "Cloud Run ephemeral disk … **regional quota 0 GiB by default**", and failure scenario 3: "deployment fails … quota request takes days" | **Overstated.** The doc says projects start at 0 GiB but "are **automatically granted 100 GiB per region** the first time a resource with an ephemeral disk is deployed". The real blocker is the **10 GiB per-instance default**, which needs a quota increase for a 40–60 GiB model disk. | https://docs.cloud.google.com/run/docs/configuring/jobs/ephemeral-disk [FACT] |
| "Cloud Storage FUSE **requires** Direct VPC egress with all-traffic + PGA", and NAT "which the FUSE path requires" | **Overstated.** Google says you "must use Direct VPC … to *optimize* ML model loading". It is a performance requirement, not a functional one. FUSE works without it, only slower. | gpu-best-practices [FACT] |
| Same-region GCS to Cloud Run transfer "ASSUMED" free | **Under-claimed.** It is confirmed free. | GCS pricing [FACT] |
| G6 Mumbai price "unverified on official pages" | **Under-claimed.** It is officially $0.9664/h. | AWS price JSON [FACT] |
| Run the POC with "official int8/FP8 checkpoints rather than community Q4", because "L4 has FP8 tensor cores" | **Partially disagree.** The official int8-convrot DiT is **21.5 GB** [FACT, HF file listing]. That leaves about 2.5 GB of a 24 GB L4 for the CUDA context, activations and VAE, so it almost certainly needs per-step partial offload on an L4 [ASSUMPTION]. `fp8-cast` is a runtime option in `ltx-pipelines`. Whether it uses FP8 tensor-core matmuls or only FP8 storage with upcast is not documented [ASSUMPTION]. Q4/Q5 GGUF (13.6–15.6 GB) is the only variant likely to be **fully resident**. Test both. Official checkpoints are not automatically the safer L4 choice. | HF API sizes |
| "The 1 h GA cap" | **Not verbatim in current docs** (see A2). Treat ≤1 h as the safe envelope. The design conclusion is unchanged. | quotas, task-timeout |
| "Ephemeral disk … compatibility with GPU jobs is **not stated**" | **Correct. I accept it.** I implicitly assumed compatibility in Round 1. Neither the GPU nor the ephemeral-disk pages mention it. It is now **POC step 0** (a dry-run deploy). If incompatible, the L4 path falls back to model-in-image or FUSE buffered reads at 32 GiB, which strengthens the VM option. | Searched both pages [FACT: not stated] |
| RunPod pod L4 $0.59/h | I did not verify it; no opinion. | n/a |

---

#### Part B: Response to each Agent 2 finding

| # | Agent 2 finding | Position | Argument | Class |
|---|---|---|---|---|
| ES1 / F2 licence | Attachment A **item 20** ("directly competes with Licensor's commercial products … without obtaining a separate commercial license") may cover an AI-video SaaS | **Agree. I missed this.** | Verified verbatim in LICENSE-2_x, lines 603–607. Item 19 forbids circumventing watermarking and provenance. Lightricks/LTX sells hosted generation (LTX API; fal.ai lists the model). A consumer prompt-to-video SaaS is plausibly "designed to … substitute Licensor's offerings". **This is the #1 gating item, above infrastructure.** Get written clearance or a commercial licence. | FACT (text) + legal judgment |
| F1 Cloud Run fit | Good for under-1 h bounded units; poor as one execution per full video | **Agree** | Same conclusion as my Round 1 W5/W6. Timeout details in A2. | REC |
| F1 option table | G2 VM is the long-form path | **Partially agree** | See A2. Phase 2, driven by volume. | TRADE-OFF |
| F2 model and VRAM | 32 GB+ guidance; Q4 is community; serial TE/DiT | **Agree** | Matches my figures. Lightricks' system-requirements page also requires **32 GB system RAM** [FACT, docs.ltx.io], which strengthens the case. Exception: the int8 vs Q4 POC choice (A7). | FACT / POC |
| F3 4/16 too small | 8/32 and an ephemeral disk | **Agree** | The services GPU page says "8 CPU recommended … 32 GiB recommended" [FACT]. For jobs, 8/32 is also the ceiling of the L4 tier (memory-limits page: max 32 GiB, 8 vCPU) [FACT]. Corrections on quota and GPU compatibility are in A7. | FACT |
| F4 availability and quotas | Mumbai invite-only; AWS quota 0; G2/G4 zones | **Agree** | Verified the AWS quota is 0. GCE zone list not re-verified. | FACT |
| F5 cold start / GCS | Slim model set, parallel cp, consider baking, VM amortization | **Agree**, with one nuance | Baking roughly 30 GB into the image goes against Google's "<10 GB" guidance, but the benchmark should decide. I add **drain/batch mode** as the Cloud Run answer to amortization. Agent 2's "never one execution per clip" is correct. | REC / POC |
| F6 unified image | One GPU image | **Agree** | Same finding as my W4 [FACT: GPU attaches to one container]. | FACT |
| F6 narration first | TTS, then durations, then clip plan, then LTX | **Agree** | I proposed the same order. Agent 2's failure scenario 7 (narration/visual mismatch) is the clearest statement of why. | REC |
| F7 TTS/Whisper off the GPU | Run them on CPU or an API | **Partially agree** | **Whisper/alignment on CPU: agree.** faster-whisper small int8 transcribed 13 min of audio in 1m42s on 8 threads (official benchmark, per Agent 2), and forced alignment of a known script is cheaper still. **TTS on CPU: depends on the engine.** For a heavy multilingual engine, roughly 3 min of narration on CPU could take longer than the GPU seconds it saves. Inside an already-running GPU job, before LTX loads, the marginal cost is just GPU-seconds × $0.000474. Decide by CPU real-time factor [POC]. | REC + POC |
| F7 VoiceStudio | AGPL app; embed the engine; consent | **Agree** | Same conclusion. Agent 2 adds the consent workflow, the README's owner-permission line, and that the OmniVoice **weights** licence is not stated on GitHub. I accept the weights-licence point as a gap in my review. | FACT |
| F8 Remotion | CPU, licence, alpha Cloud Run package, FFmpeg-only option | **Agree** | Identical findings. Agent 2's point that NVENC on the L4 helps encodes on a GPU VM is valid for option B. | FACT |
| F9 Oracle | SPOF, only 5 free volume backups, WAL-G/pgBackRest to R2, rebuild runbook, consider managed Postgres | **Agree** | Agent 2 is more complete here (Cloudflare in front, an external uptime check, the 5-backup limit). Managed Postgres (Neon/Supabase) is a valid [TRADE-OFF] against latency and vendor sprawl. | FACT / REC |
| F10 queue / reconciliation | Postgres state machine, `dispatching` written before `jobs.run`, labels, reconciler | **Agree. Better than mine.** | My Round 1 said "reconciliation polling". Agent 2's write-ahead `dispatching` state plus execution labels closes the orphan and duplicate-execution window (scenario 5) that my version left open. | REC |
| F11 retries / timeout | taskCount = ⌈N/k⌉, tasks under 40 min, maxRetries 1–2, failure classification | **Agree** | Note: parallel tasks each pay staging, so at quota 3 parallelism trades cost for latency. Prefer sequential tasks for cost, parallel for paid priority. | REC |
| F12 R2 / egress / NAT | Intermediates in GCS; NAT hidden cost | **Agree** | See A4. NAT was my omission. | FACT |
| F13 AWS fallback | G6 over G5; quota 0; Modal/RunPod; GCP region first | **Agree** | See A3. My only correction is that the price is officially verifiable. | FACT |
| F15 security | Custom role; key rotation; presigned GET ≤15–60 min; moderation; consent; validate media before GPU spend | **Agree** | I accept the shorter presigned TTL (mine left it unspecified; R2 allows up to 7 days [FACT]). Upload validation before GPU spend is a good catch. | REC |
| Hidden cost A | Tier 2 correction | **Partially agree** | The direction is right, but the GPU uplift is missing (A1). | FACT |
| Hidden cost B | Parametric per-video table | **Agree with the method** | Rescale by ×1.121 (4/16) or ×1.086 (8/32). | Arithmetic |
| Hidden cost D | Egress about $0.09 per video, $90/month per 1,000 | **Agree** | Consistent with my estimate. | ASSUMPTION (sizes) |
| Hidden cost F | Artifact Registry $0.10/GB-month | **Accept** | I left it unverified. Agent 2 cites the official page. I have not re-checked it. | (Agent 2: FACT) |
| Hidden costs I, L | Logging volume; runaway-VM watchdog | **Agree** | Spend caps do not cover GCE (A5), so the watchdog is mandatory on option B. | FACT |
| Alternative D | RTX PRO 6000 "price not verified" | **Resolved** | Singapore: $0.00043826/s GPU. At 20/80 that is $3.824/h, so break-even needs ≥2.24× the speed of L4 8/32 [FACT + arithmetic]. | FACT |
| Open Q10 | Clip continuity across 15–30 clips | **Agree** | This is a product-quality risk that neither GPU choice solves. LTX-2.5 multishot, I2V chaining and LoRA all need a POC. | POC |

---

#### Part C: Points I concede

1. **LTX-2.x licence item 20 (competing products)** is a potentially existential risk that I missed. It outranks every infrastructure issue in either review.
2. **Ephemeral disk compatibility with GPU jobs is undocumented.** My Round 1 treated it as a working solution. It is now POC step 0.
3. **AWS G/VT on-demand quota defaults to 0.** My "often start low" understated this. AWS cannot be the first fallback.
4. **The fallback order** should start with another Cloud Run region (Tier 1, about 16.7% cheaper), not AWS.
5. **Cloud NAT** is a hidden cost and an extra component once Direct VPC `all-traffic` is used. I omitted it.
6. **Agent 2's state machine** (write-ahead `dispatching`, execution labels, failure classification by exit code) is more rigorous than my reconciliation proposal.
7. **The OmniVoice weights licence is unverified.** I verified only the code licence. Voice-cloning consent was missing from my review.
8. **Oracle hardening** details: the 5-backup limit, an external uptime check, a rebuild runbook.
9. **GCE GPU VMs get 1 h maintenance notice against 10 s on Cloud Run** (I found this while checking Agent 2's VM argument). It is a genuine point in favour of the VM for long-running work.

#### Part D: Positions I maintain

1. Singapore L4 is **$1.2558/h (4/16)** and **$1.7051/h (8/32)**. Agent 2's $1.12/$1.57 are wrong (A1).
2. **Cloud Run Jobs stays the MVP platform.** Reasons: spend-cap coverage (GCE is not eligible), zone failover handled by the platform, and lower cost below roughly 100 busy GPU-hours a month. Move to a VM, MIG or GKE on measured volume (A2).
3. **Spend caps are GA and stop jobs.** Quoted in A5.
4. Q4/Q5 GGUF must be in the L4 POC alongside official int8. The official int8 DiT (21.5 GB) is unlikely to be fully resident on 24 GB.
5. Cloud Run RTX PRO 6000 (priced, available in Singapore) is the pre-approved escape hatch if the L4 fails.

#### References (accessed 2026-11-10/11)

- Cloud Run pricing (embedded regional data): https://cloud.google.com/run/pricing
- Cloud Run GPU jobs: https://docs.cloud.google.com/run/docs/configuring/jobs/gpu
- Cloud Run GPU services (8 CPU / 32 GiB recommended): https://docs.cloud.google.com/run/docs/configuring/services/gpu
- Cloud Run quotas: https://docs.cloud.google.com/run/quotas
- Task timeout: https://docs.cloud.google.com/run/docs/configuring/task-timeout
- Ephemeral disk (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/ephemeral-disk
- GPU best practices (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/gpu-best-practices
- Billing settings (spend-cap effect on jobs): https://docs.cloud.google.com/run/docs/configuring/billing-settings
- Release notes: https://docs.cloud.google.com/run/docs/release-notes
- Spend cap budgets: https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps
- GCE GPU host maintenance: https://docs.cloud.google.com/compute/docs/gpus/gpu-host-maintenance
- GCE resource availability errors: https://docs.cloud.google.com/compute/docs/troubleshooting/troubleshooting-resource-availability
- WIF with other providers (OIDC, uploaded JWKS): https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-other-providers
- WIF with X.509: https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-x509-certificates
- GCS pricing: https://cloud.google.com/storage/pricing
- VPC network pricing: https://cloud.google.com/vpc/network-pricing
- LTX-2.x licence: https://github.com/Lightricks/LTX-2/blob/main/LICENSE-2_x
- LTX-2.5 files: https://huggingface.co/api/models/Lightricks/LTX-2.5/tree/main
- LTX system requirements: https://docs.ltx.io/open-source-model/getting-started/system-requirements
- AWS EC2 quotas: https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html
- AWS Mumbai on-demand price data: https://b0.p.awsstatic.com/pricing/2.0/meteredUnitMaps/ec2/USD/current/ec2-ondemand-without-sec-sel/Asia%20Pacific%20(Mumbai)/Linux/index.json
- G2 price (third party, unverified): https://calculator.holori.com/gcp/vm/g2-standard-8/asia-southeast1


---

## Part C — Round 2: Agent 2 challenges Agent 1 (verbatim)

### Round 2: Agent 2's response to Agent 1

| Field | Value |
|---|---|
| Author | Agent 2 (Principal DevOps / AI Infrastructure, critical reviewer) |
| Date | 2026-11-11 |
| Input | `01-agent-1-review.md` (read in full). My Round 1 is `02-agent-2-review.md`. Neither file was edited. |
| New verification this round | Raw HTML of the Cloud Run pricing page (regional tables parsed); Cloud Run release notes; Cloud Run billing-settings page; Cloud Billing spend-caps doc; ephemeral-disk-for-jobs page; Direct VPC egress page; LTX-2 GitHub README (pipelines list); docs.ltx.io system requirements; a read-only `ec2:DescribeInstanceTypeOfferings` call in ap-south-1. My `servicequotas:GetServiceQuota` call was denied (AccessDenied), so I could not read the account's actual G/VT quota. |
| Labels | **[FACT]** confirmed, with source. **[REC]** evidence-supported recommendation. **[ASSUMPTION]** requires testing. **[TRADE-OFF]** preference. |

---

#### Part A: The seven contested points

##### A1. Singapore Cloud Run L4 price: Agent 1 is right, I was wrong

**Verdict: Agree with Agent 1 and correct my own number.**

I downloaded `https://cloud.google.com/run/pricing?hl=en` and parsed the embedded regional tables. In the tables preceded by the `asia-southeast1` label, the values are:

- `CPU (per vCPU-second) $0.0000216`
- `Memory (per GiB-second) $0.0000024`
- `GPU Type NVIDIA L4 non-zonal redundancy (per Second) $0.00022404`
- `GPU Type NVIDIA RTX PRO 6000 non-zonal redundancy (per second) $0.00043826`

The Tier 1 L4 value, `$0.0001867`, appears in the tables for us-central1 and asia-south1. Note that 0.00022404 = 1.2 × 0.0001867, the same 20% Tier 2 uplift that applies to CPU and memory. **[FACT]** (https://cloud.google.com/run/pricing).

Arithmetic:

| Shape (asia-southeast1, jobs) | GPU $/h | CPU $/h | Mem $/h | Total $/h |
|---|---|---|---|---|
| L4, 4 vCPU / 16 GiB | 0.00022404 × 3600 = **0.80654** | 4 × 0.0000216 × 3600 = **0.31104** | 16 × 0.0000024 × 3600 = **0.13824** | **$1.25582** |
| L4, 8 vCPU / 32 GiB | 0.80654 | 0.62208 | 0.27648 | **$1.70510** |
| RTX PRO 6000, 20 vCPU / 80 GiB | 0.00043826 × 3600 = **1.57774** | 1.55520 | 0.69120 | **$3.82414** |

My Round 1 figures ($1.12/h and $1.57/h) were wrong. I flagged the Tier 2 GPU rate as "not verified" and then used the Tier 1 L4 rate anyway. That understated the price by about 11% and 8% respectively. **Agent 1's $1.2558/h and $1.7051/h stand.** Every per-video figure in my Round 1 cost table (Hidden costs B) should be scaled by 1.12× for the 4/16 column and 1.086× for the 8/32 column.

##### A2. "Budget spend caps GA 2026-10-12, can stop jobs": verified

**Verdict: Agree (I missed this), with two qualifications.**

- Release notes, Oct 12 2026: "Support for Budget spend caps to pause your Cloud Run workloads is in General Availability (GA)." **[FACT]** (https://docs.cloud.google.com/run/docs/release-notes)
- On the Cloud Run billing-settings page, for jobs: "new task executions fail to start, and in-progress tasks fail to complete." Caps "automatically apply to all Cloud Run resource types in your project." **[FACT]** (https://docs.cloud.google.com/run/docs/configuring/billing-settings)

Qualifications, from the Cloud Billing spend-caps doc (https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps):

1. Enforcement uses **estimated** list-price costs and "isn't instantaneous". Overage is billed normally, and the period is **monthly only**.
2. The cap applies to **one project and one service**. It does **not** cover Artifact Registry, GCS, Cloud NAT or egress, and it would not cover a Compute Engine VM.
3. Because in-progress tasks are failed, a cap hit **destroys in-flight GPU work**. This reinforces per-clip checkpointing.

**[REC]** Use the cap as a monthly **backstop** set about 10–20% below the true ceiling. Daily and per-user admission control in Postgres remains the primary control.

This also counts against my own Compute Engine VM proposal: **a GCE VM gets no equivalent Cloud Run spend-cap kill switch**. I give that weight in A3.

##### A3. Agent 1's long-lived "drain the queue" worker vs my stop/start GCE VM

**Verdict: Partially agree. Drain mode is a good optimisation inside Cloud Run's limits, but it does not solve the core problem at this product's volume.**

Constraints, all **[FACT]**:
- The GA GPU task timeout is 1 h; up to 12 h is Preview.
- GPU tasks are not live-migrated: "routine infrastructure maintenance terminates them."
- GPU is billed for the whole instance lifecycle.

Sources: https://docs.cloud.google.com/run/docs/configuring/task-timeout and https://docs.cloud.google.com/run/docs/configuring/jobs/gpu.

**Where drain mode is consistent.** Agent 1 bounds each execution with a ~45 min time budget. That respects the 1 h GA cap, so there is **no conflict with the timeout** as long as the budget is enforced *per clip boundary*. The worker should not lease a new clip if `elapsed + p95(t_clip) > budget`.

**Where drain mode is weak:**
1. **Amortisation only works if the queue is deep at execution start.** The doc targets "a handful of videos per month", so the queue will almost always hold 0–1 jobs. Drain mode then degenerates into one execution per video. Making the worker *wait* for new jobs means paying $1.71/h for an idle L4. **[ASSUMPTION** about arrival rate; the reasoning about the mechanism is sound.]
2. **It amortises only within an execution, never across executions.** Every new execution re-stages the roughly 32 GB working set. A VM with a persistent disk amortises across *days*.
3. **Maintenance blast radius.** One termination interrupts every job currently leased. Lease expiry plus heartbeats handles this (Agent 1's lease API already implies it), but it must be designed in.
4. **Multi-tenant isolation inside one container.** Different users' prompts, uploaded images, voice-reference clips and outputs share `/tmp`, the ComfyUI input/output directories and the model and LoRA caches. The worker must wipe per-job directories and never load per-user LoRAs into shared state. This is manageable, but it is new risk that per-execution isolation avoided. **[REC]**

**My corrected position on the GCE VM.** I still think a VM is the better engine **for long-form (2–3+ min) work at steady volume**, because it has no 1 h cap and no per-run re-download. Agent 1's points and the new evidence weaken it for the MVP, though:

- No spend-cap equivalent (A2).
- I have no verified Singapore G2 price. My $0.872/h figure is third-party.
- GCE GPU quota for new projects is unverified.
- Runaway-VM risk needs a watchdog.

**Revised recommendation [TRADE-OFF]:**
- **MVP:** Cloud Run Jobs with tasks of at most 45 min, per-clip checkpoints and drain-on-lease. Do not idle-wait.
- **Trigger to move long-form to a VM** (or AWS g6/g6e with NVMe): the POC shows staging above ~15% of billed GPU time, **or** sustained volume makes warm-model reuse worthwhile.

The two proposals are complementary rather than either/or.

##### A4. Ephemeral disk + parallel GCS download over Direct VPC / Private Google Access

**Verdict: Partially agree. Agent 1 is right about the quota; I was partly wrong. GPU compatibility is still undocumented, and Agent 1 underestimates the network side.**

From the ephemeral-disk page for jobs (https://docs.cloud.google.com/run/docs/configuring/jobs/ephemeral-disk), all **[FACT]**:
- "Volume size limit: each volume must be between 1Gi and 100Gi."
- "each instance is limited to 10 GiB of total space by default. Configuring more than 10 GiB per instance requires requesting a quota increase."
- "each project starts with a total regional allocation limit of 0 GiB by default. **Projects are automatically granted 100 GiB per region the first time a resource with an ephemeral disk is deployed in that region.**"
- "Ephemeral disk is only available in the second generation execution environment." Also: "Live migration is not supported."
- Ephemeral disk went GA on 2026-11-04 (release notes).

**Correction to my Round 1.** I said the regional quota was "0 GiB by default" as if a request were required. In fact it is **auto-granted at 100 GiB on first deploy**. The real blocker is the **10 GiB per-instance default**: a 40–60 GiB volume still needs a quota increase. Agent 1's statement ("10 GiB per instance … 100 GiB per region") is correct.

**GPU compatibility: still unverified.** The ephemeral-disk page does not mention GPUs at all, either to include or to exclude them. This remains a **day-1 POC check**: deploy an L4 job with a 50 Gi ephemeral disk. **[ASSUMPTION]**

**Network findings Agent 1 underweights.** From the Direct VPC page (https://docs.cloud.google.com/run/docs/configuring/vpc-direct-vpc), all **[FACT]**:

1. "Cloud Run supports throughput of up to **1 Gbps per individual container instance**. Exceeding this amount results in performance throttling."
   - 1 Gbps is at most ~125 MB/s. Agent 1's illustrative 200–500 MB/s (64–160 s for 31.8 GB) is **above the documented ceiling** for Direct VPC traffic.
   - The floor is 31.8 GB ÷ 0.125 GB/s ≈ **254 s ≈ 4.2 min per execution**.
   - At $1.7051/h ($0.0004736/s) that is about **$0.12 of staging per execution**, before ComfyUI init and model load. This is arithmetic on a documented cap. Real throughput NEEDS BENCHMARK and could be lower, not higher.
2. "You might experience connection establishment delays of **a minute or more** on instance startup when using Direct VPC egress." More billed GPU seconds.
3. "With Cloud NAT, you might experience cold start delays of **30s or more** on instance startup when using Direct VPC egress. For better startup performance, we recommend using Serverless VPC Access connectors with Cloud NAT."
4. On the jobs ephemeral-disk and GCS-mount guidance: "This method works if you don't need the Cloud Run resource to access the internet. **If you do need internet access, either set up Cloud NAT**, or see Internal traffic to a Google API."

**So yes: with `all-traffic` Direct VPC egress, uploads to R2 and callbacks to Oracle require Cloud NAT**, which adds startup delay and NAT charges. Agent 1 mentions NAT parenthetically. I treat it as a design driver.

**[REC]** Benchmark three variants:
- (a) **Default (non-VPC) egress** and plain `gcloud storage cp`. It is not covered by the Direct VPC 1 Gbps statement, but its throughput is undocumented.
- (b) **Direct VPC with `private-ranges-only` + Private Google Access via `private.googleapis.com`/`restricted.googleapis.com` DNS** (the "Internal traffic to a Google API" route). GCS goes over the VPC and R2/Oracle go direct, with **no NAT**.
- (c) Agent 1's all-traffic + NAT.

Also benchmark **baking a slim model set into the image**. Image streaming is not subject to the Direct VPC cap, and Google says only that models above 10 GB make deploys slower and that GCS is "more predictable". If staging is about 4 min per execution, the image route may win despite Google's general advice.

##### A5. AWS fallback: g6.2xlarge ($1.17/h) and g6e.xlarge (L40S 48 GB) in ap-south-1

**Verdict: Agree on availability. Partially agree on L40S as primary.**

- **Availability [FACT].** My own read-only `DescribeInstanceTypeOfferings` (ap-south-1, AZ level) returned g5.xlarge, g6.xlarge, g6.2xlarge, g6e.xlarge and g6e.2xlarge, **each in ap-south-1a and ap-south-1b**. This matches Agent 1. I did not re-verify the $/h figures (Agent 1 cites the AWS public price JSON). g6.xlarge at $0.9664 agrees with the third-party figures I found in Round 1.
- **Quota [FACT].** The default for "Running On-Demand G and VT instances" and "All G and VT Spot Instance Requests" is **0 vCPUs** (https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html). The quota is counted in **vCPUs**: g6.2xlarge needs ≥ 8, g6e.xlarge ≥ 4, g6e.2xlarge ≥ 8. Agent 1 wrote "often start low … [ASSUMPTION]". The official default is **0**, not "low". Until an increase is granted the fallback cannot launch a single instance. I could not read this account's applied value (AccessDenied on `servicequotas:GetServiceQuota`).
- **Is L40S a better PRIMARY than L4? Partially agree.**
  - LTX's own system-requirements page says: minimum "NVIDIA GPU with a minimum 32GB+ VRAM", **32 GB system RAM**, 100 GB disk; recommended "A100 (80GB) or H100", 64 GB+ RAM. **[FACT]** (https://docs.ltx.io/open-source-model/getting-started/system-requirements)
  - g6e.xlarge (48 GB VRAM, 32 GiB RAM, local NVMe) is the **cheapest verified spec-compliant option** in either review: $2.235/h vs $3.824/h for Cloud Run RTX PRO 6000.
  - So I agree the **POC baseline should be a spec-compliant GPU**, with L4 treated as a cost-down experiment rather than the default assumption. **[REC]**
  - But I would not make it production primary yet. It adds a second cloud's IAM, AMI, quota and lifecycle management. VM boot plus model load replaces Cloud Run's ~5 s start. It has no spend-cap kill switch. And 4 vCPU / 32 GiB sits exactly at the 32 GB RAM minimum with no headroom.
  - **Pick primary by measured $/output-second.** [TRADE-OFF / POC]

##### A6. Pipeline order TTS → Whisper → LTX (audio-to-video): is A2V official?

**Verdict: Agree that it is official. Disagree that it is a free choice on L4.**

- The LTX-2 README lists **"A2VidPipelineTwoStage – Audio-to-video generation conditioned on an input audio file"** among the official pipelines in `ltx-pipelines`. It also lists **DubItPipeline** ("matching speaker identity and lip movements"). **[FACT]** (https://github.com/Lightricks/LTX-2)
- The same README says the **dev (full) transformer** is "used by the guided two-stage pipelines (TI2Vid, Keyframe, **A2Vid**)". The **distilled LoRA** is "required by the two-stage pipeline implementations that run the full model in stage 1 (… **A2Vid**; not DistilledPipeline …)". **[FACT]**
- Consequence: A2V needs the **dev DiT** (42.02 GB bf16 per Agent 1's HF listing) **plus the 8.9 GB distilled LoRA**, with guided (CFG) sampling in stage 1. That costs more steps, more VRAM and more host RAM than the 8-step distilled path. On a 24 GB L4 that is a heavier lift than the distilled T2V/I2V path both of us analysed. **[Evidence-supported inference; NEEDS POC]**
- I found no confirmation that A2V ships in the official **ComfyUI** templates (the secondary source lists T2V, I2V and FLF2V templates). **[ASSUMPTION]**

**[REC]** Narration-first ordering is right; we both proposed it. Use the narration **for timing** (clip count and per-clip `num_frames`), with the distilled T2V/I2V pipeline as the default. Treat A2V/lip-sync as a **premium feature to POC on ≥ 48 GB hardware**, not the MVP path.

On *where* TTS runs: Agent 1 puts TTS and faster-whisper in the GPU image, while I put them off the GPU. This is a **[TRADE-OFF]**:
- Running inside the GPU job avoids a second job but bills L4 seconds for TTS model load and inference.
- Running separately lets the script and voice be previewed or approved by the user before any GPU spend. That is a UX and cost win for paid tiers.

I keep my preference, but concede that it is a preference.

##### A7. Cloud Run RTX PRO 6000 (96 GB, min 20 vCPU / 80 GiB, $3.824/h)

**Verdict: Agree on facts and arithmetic. Agree that it is a legitimate POC arm.**

- Jobs regions for RTX PRO 6000: `asia-southeast1`, `asia-south2`, `europe-west4`, `us-central1`. Minimum is "20 CPU and 80 GiB". Quota is 3,000 milliGPU auto-granted, "subject to availability". **[FACT]** (https://docs.cloud.google.com/run/docs/configuring/jobs/gpu)
- GA was 2026-04-13 (release notes). **[FACT]**
- $3.82414/h is verified in A1 above. Agent 1's break-even of **≥ 2.24× faster than L4 8/32** is correct arithmetic (3.82414 / 1.70510 = 2.243).

**My additions:**
- (a) The RTX PRO 6000 is Blackwell, so the **official NVFP4 distilled checkpoint** (18.72 GB) and the bf16 Gemma encoder can stay resident together with no offload. It is the only verified Cloud Run option that runs LTX-2.5 the way Lightricks documents it.
- (b) The 80 GiB host RAM also holds models in page cache, but the Direct VPC 1 Gbps cap (A4) still governs staging. Staging is billed at $3.82/h, so **reducing staging time matters 2.2× more** on this SKU.
- (c) The blast radius is larger: a looping job burns about $92/day. That makes the spend cap (A2) and the per-job watchdog mandatory. **[REC]**

---

#### Part B: Agent 1's other major positions

| # | Agent 1 position | My verdict | Argument | Class |
|---|---|---|---|---|
| B1 | Core pattern is sound: free control plane + scale-to-zero GPU batch | **Agree** | Correct economics at "handful per month" volume. My Round 1 says the same. | [REC] |
| B2 | LTX-2.5 official minimum is 32 GB VRAM / 32 GB RAM; "Q4" means community GGUF; 16 GiB host RAM is the binding constraint | **Agree** | I verified the docs.ltx.io page this round. Agent 1's exact HF file sizes are more precise than my arithmetic. | [FACT] |
| B3 | Two images in one GPU execution is impossible; use one image | **Agree** on the impossibility; **partially** on the remedy | One image for ComfyUI + LTX. TTS placement is a trade-off (A6). | [FACT] / [TRADE-OFF] |
| B4 | Retries ≥ 1, per-clip checkpoints, tasks ≲ 1 h | **Agree** | Identical to my Round 1. Spend-cap behaviour (in-progress tasks fail) strengthens it. | [FACT]-based [REC] |
| B5 | Start at 8 vCPU / 32 GiB, the max for the L4 tier | **Agree** | Matches Google's recommended 8/32 for L4. | [FACT] |
| B6 | Model path: Direct VPC all-traffic + PGA → parallel `gcloud storage cp` → ephemeral disk | **Partially agree** | The 1 Gbps per-instance cap, startup delays of a minute or more, and NAT delays of 30 s+ are documented. Test `private-ranges-only` + private Google API DNS and image baking (A4). | [FACT] + [POC] |
| B7 | Singapore is the right primary region | **Partially agree** | Correct as the closest to users with L4 and RTX PRO 6000. But generation is async batch, so user latency to the GPU region barely matters. Tier 1 `us-central1` / `europe-west4` are 20% cheaper on every line (L4 $0.0001867/s), and us-central1 also has RTX PRO 6000. Data residency is the only real constraint. I would make a Tier 1 region the default **unless** residency requires APAC. | [FACT] prices, [TRADE-OFF] |
| B8 | Keep intermediates in GCS and send only finals to R2 | **Agree** | Same as my Round 1. | [REC] |
| B9 | Remotion needs Automators ($100/mo minimum) if > 3 employees; FFmpeg-only MVP | **Agree** | Same finding. | [FACT] / [TRADE-OFF] |
| B10 | VoiceStudio = debpalash (AGPL); call the OmniVoice engine directly | **Agree** | Same identification. OmniVoice **code** is Apache-2.0, but neither of us has verified the **weights** licence on HF. That must be checked before relying on it. | [FACT] + open item |
| B11 | The orchestrator needs reconciliation polling, not only callbacks | **Agree** | Same. I would add the `dispatching` state written *before* `RunJob` to close the orphan window. | [REC] |
| B12 | Oracle SA key scoped to `run.jobs.runWithOverrides` + execution read | **Agree** | Same. | [REC] |
| B13 | Oracle A1 suits an MVP; reclamation is unlikely; back up off-box | **Agree** | Same. | [FACT] / [ASSUMPTION] |
| B14 | "Per-video target ~$0.15–0.25" (Section 6) | **Disagree** | No benchmark supports any per-video target. Under A4's documented 1 Gbps cap, staging alone is about $0.12 per execution at 8/32 Singapore. A 2–3 min video is 15–30 clips. The target should be derived from POC $/output-second, not stated up front. | [ASSUMPTION] flagged |
| B15 | LTX-2.x licence: free below $10M revenue, so it is compliant | **Partially agree; important omission** | Agent 1 does not discuss **Attachment A item 20**: no use "in any product, service, or application that directly competes with Licensor's commercial products or services … without obtaining a separate commercial license". It also omits item 19 (no circumventing watermarking or provenance). A consumer AI video generation SaaS may be "competing" regardless of revenue. **I keep this as the #1 risk.** It is legal interpretation, so get a written answer from Lightricks. | [FACT] text, legal [ASSUMPTION] |
| B16 | AWS Batch on EC2 g6/g6e is the primary fallback | **Partially agree** | g6/g6e are correct over g5. But a cheaper-to-operate *first* fallback is **Cloud Run in a second GCP region** (same image, IAM and spend cap). AWS sits behind the quota-0 gate (A5). | [FACT] / [TRADE-OFF] |
| B17 | Delayed jobs (Preview) don't discount GPU, so they matter little | **Agree** | Accepted as stated. I did not independently re-verify. | Agent 1 [FACT] |
| B18 | Jobs CPU/memory max is 8/32, which conflicts with the RTX PRO 6000 20/80 minimum (verify) | **Agree it needs a dry run** | The GPU page explicitly states 20/80 for RTX PRO 6000 jobs. The GPU-specific page likely overrides the generic table, but only a deploy proves it. | [POC] |

---

#### Part C: Points I concede

1. **Price:** Agent 1's Singapore figures ($1.2558/h at 4/16, $1.7051/h at 8/32, $3.8241/h for RTX PRO 6000) are correct. Mine were wrong because I used the Tier 1 L4 rate. (A1)
2. **Budget spend caps** are GA (2026-10-12), apply to Cloud Run jobs, and fail in-progress tasks. I missed this control entirely. (A2)
3. **Ephemeral disk regional quota** is auto-granted at 100 GiB per region on first deploy. My "0 GiB default" framing overstated the blocker; the real gate is the 10 GiB per-instance default. Agent 1 also reported the GA date correctly; I had it too, but tied it to the wrong quota conclusion. (A4)
4. **A spec-compliant GPU should be the POC baseline.** Agent 1's framing (L4 is "below both minimums"; g6e and RTX PRO 6000 meet spec) is more decisive than mine. I now rank ≥ 32 GB hardware as the baseline and L4 as the cost-down experiment. (A5, A7)
5. **The AWS fallback inventory** in ap-south-1 (g5/g6/g6e in 1a/1b) is correct. I verified it independently.
6. **Things Agent 1 found that I missed:**
   - exact HF file sizes (DiT int8 21.5 GB, Gemma TE int8 15.37 GB, NVFP4 18.72 GB);
   - the official **32 GB system RAM** minimum;
   - ComfyUI LTX nodes **auto-download models** on first use (block this in production);
   - the **prompt enhancer** (`gemma4_e2b_it`) is enabled by default (an extra model load);
   - **R2 presigned URLs do not work on custom domains**;
   - the Jobs free tier is worth at most about $5.22/month and **GPU has no free tier**;
   - ComfyUI is GPL-3.0 (fine server-side).
7. **OmniVoice (Apache-2.0 code)** as the engine to call directly is a sound recommendation; we both reached it. The weights licence is still unverified by either of us.

#### Part D: Points I maintain against Agent 1

1. **The LTX licence competing-product clause (item 20)** is missing from Agent 1's review. It is the single biggest risk to the plan.
2. **The Direct VPC 1 Gbps per-instance cap and startup delays** make Agent 1's staging assumptions optimistic. Image baking and non-NAT egress variants must be in the POC.
3. **Drain mode** gives little benefit at the stated volume and adds multi-tenant isolation duties. Long-form work at steady volume still favours a warm-disk VM (GCE or AWS g6/g6e NVMe), within the limits conceded in A3.
4. **A2V** is official but runs on the heavier dev-model two-stage path. Do not make it the MVP default on L4.
5. **A Tier 1 region** should be the default GPU region for async batch unless data residency forbids it. It is 20% cheaper on every line.

---

#### References (accessed 2026-11-11)

**Cloud Run**
- Pricing (raw page, regional tables parsed): https://cloud.google.com/run/pricing
- Release notes: https://docs.cloud.google.com/run/docs/release-notes
- Billing settings (spend caps): https://docs.cloud.google.com/run/docs/configuring/billing-settings
- GPU for jobs: https://docs.cloud.google.com/run/docs/configuring/jobs/gpu
- Task timeout: https://docs.cloud.google.com/run/docs/configuring/task-timeout
- Ephemeral disk for jobs: https://docs.cloud.google.com/run/docs/configuring/jobs/ephemeral-disk
- Direct VPC egress: https://docs.cloud.google.com/run/docs/configuring/vpc-direct-vpc

**Cloud Billing**
- Budget spend caps: https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps

**Lightricks / LTX**
- LTX-2 README: https://github.com/Lightricks/LTX-2
- LTX system requirements: https://docs.ltx.io/open-source-model/getting-started/system-requirements
- LTX-2.x Community License: https://github.com/Lightricks/LTX-2/blob/main/LICENSE-2_x

**AWS**
- EC2 instance quotas: https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html
- `ec2:DescribeInstanceTypeOfferings`, ap-south-1, read-only API call, 2026-11-11


---

## Part D — Round 3: Agent 1 final position (verbatim)

### Round 3: Agent 1's Final Position

| Field | Value |
|---|---|
| Author | Agent 1 (Senior Cloud Solutions Architect) |
| Date | 2026-11-11 |
| Inputs | `architecture.txt`, `01-agent-1-review.md`, `02-agent-2-review.md`, `_round2-agent1.md`, `_round2-agent2.md` |
| Labels | **[FACT]** confirmed technical fact, with source. **[REC]** recommendation supported by evidence. **[ASSUMPTION]** requires testing. **[TRADE-OFF]** preference. |

#### 0. New items re-verified this round

Three new or contested items from Agent 2's Round 2 were checked against official sources.

##### 0.1 Direct VPC throughput cap: confirmed, and I underweighted it

From https://docs.cloud.google.com/run/docs/configuring/vpc-direct-vpc, under "Limitations" (applies to services, functions, jobs and worker pools) [FACT]:

- "Cloud Run supports throughput of up to **1 Gbps per individual container instance**. Exceeding this amount results in performance throttling."
- "connection establishment delays of a minute or more on instance startup"
- "With Cloud NAT … cold start delays of 30s or more"

Consequences:

- Google's prescribed model-loading path is Direct VPC with `all-traffic` egress plus Private Google Access. On that path, staging is capped at about **125 MB/s**.
- For my 31.8 GB working set, that is **≥ 254 s, or about $0.12 per execution** at $1.7051/h. That is arithmetic on a documented cap [FACT-based].
- My Round 1 illustrative figure of 200–500 MB/s was **above the documented ceiling** for that path. **I withdraw it.**
- The default (non-VPC) path to GCS is functional: "Cloud Run can read and write from Cloud Storage without any additional networking setup" (https://docs.cloud.google.com/run/docs/configuring/jobs/ephemeral-disk) [FACT]. Its throughput is **undocumented** [POC].
- Agent 2's variant (b) is `private-ranges-only` plus `private.googleapis.com` DNS. That egress setting "sends only traffic to internal addresses through the VPC network" [FACT, same page]. The `private.googleapis.com` VIP is not an RFC 1918 range, so whether it is routed through the VPC under that setting is **unverified** [ASSUMPTION]. A Private Service Connect endpoint for Google APIs on an internal IP would be the reliable form. Either way, it still falls under the 1 Gbps per-instance statement.

##### 0.2 Audio-to-video: Agent 2 is right about the PyTorch pipeline, wrong about the ComfyUI path

- The LTX-2 README says the dev transformer is "used by the guided two-stage pipelines (TI2Vid, Keyframe, **A2Vid**)". It also says the distilled LoRA is "required by … A2Vid" (https://github.com/Lightricks/LTX-2) [FACT]. That applies to `ltx-pipelines`.
- The **official ComfyUI A2V workflow is `LTX-2.5_A2V_Two_Stage_Distilled.json`**. It loads **`ltx-2.5-22b-distilled-transformer-bf16`**, says "It uses the same two-stage **distilled** architecture", and "Both stages use CFG 1". Its model list includes the bf16 Gemma TE, the prompt enhancer, the DiffVAE, the audio VAE and the 2× spatial upscaler. Source: https://docs.ltx.io/open-source-model/usage-guides/audio-to-video [FACT].
- So in the ComfyUI stack the plan uses, A2V **does not** require the dev DiT or the distilled LoRA.
- It does still require a **two-stage workflow with a 2× upscale**, which costs more VRAM and time than single-stage T2V/I2V. The guide warns that "Higher resolution and longer audio need more VRAM" [FACT].
- Agent 2's statement that A2V does not ship in the official ComfyUI templates is contradicted by this guide.

##### 0.3 Per-video cost target: I withdraw the "$0.15–0.25" framing

That figure in my Section 6 was derived from the original doc's unbenchmarked 7.5-minute assumption. Agent 2 is right that no per-video target should be stated before the POC measures $/output-second [concession].

---

#### 1. Original decisions that should REMAIN

| # | Decision | Reason | Class |
|---|---|---|---|
| R1 | Oracle Always Free VPS as the control plane (Next.js, API, Postgres, queue) for the MVP/beta | Free, enough for 1–3 concurrent jobs, and decoupled from the GPU. It needs off-box backups and a rebuild runbook. | [REC]; limits [FACT] (Oracle Always Free docs) |
| R2 | Scale-to-zero GPU batch, with no persistent GPU | An idle GPU costs $1.05–1.71/h. "Handful per month" volume makes on-demand the only sane option. | [REC] |
| R3 | **Cloud Run Jobs as the MVP GPU platform** | Covered by **spend caps** (GA; "Jobs: new task executions fail to start …"), which Compute Engine is not eligible for. GPU jobs GA. ~5 s instance start. 3-GPU quota auto-granted. Zone failover handled by the platform (best effort). | [FACT] billing-settings, budgets-spend-caps, jobs/gpu |
| R4 | GCS as the model store | Free same-location transfer. One copy of the models. | [FACT] GCS pricing |
| R5 | Cloudflare R2 for user-facing finals | Zero egress. Presigned URLs (S3 endpoint only, ≤ 7 days). | [FACT] R2 docs |
| R6 | Sequential GPU stages (text encoder, then DiT, then VAE) | Required by VRAM: TE int8 is 15.37 GB and DiT Q4 is 13.58 GB on a 24 GB card. | [FACT] HF file sizes |
| R7 | CPU rendering, separate from the GPU | Rendering on an L4 instance wastes $0.81/h of GPU time. | [FACT]-based arithmetic |
| R8 | A provider-agnostic job contract, with fallback only on capacity errors | Lets other regions and providers be added cheaply. | [REC] |
| R9 | Concurrency 1 at launch | Fine. Admission control belongs in Postgres. | [REC] |

#### 2. Original decisions that should CHANGE

| # | From | To | Reason | Class |
|---|---|---|---|---|
| C1 | Singapore as the default GPU region | **europe-west4 (or us-central1) as the default for async batch, unless data residency or privacy policy requires APAC.** Then Singapore. | Tier 1 is 1/1.2 of Singapore on every line: L4 8/32 costs $1.4209/h vs $1.7051/h. europe-west4 has both L4 and RTX PRO 6000 for jobs with no "may require quota increase" caveat. us-central1 L4 carries that caveat. User latency does not matter for a minutes-long async job. | Prices and regions [FACT] (run/pricing, jobs/gpu); choice [TRADE-OFF] |
| C2 | L4 with 4 vCPU / 16 GiB | **8 vCPU / 32 GiB** (the L4 maximum) plus an **ephemeral disk** sized to the working set | LTX docs require 32 GB system RAM. ComfyUI offload needs host RAM. The default filesystem is in-memory. | [FACT] docs.ltx.io, container-contract, memory-limits |
| C3 | L4 as the assumed production GPU | **POC baseline on a spec-compliant GPU** (Cloud Run RTX PRO 6000 in the same region; g6e as an off-platform reference), with **L4 as a cost-down experiment** | LTX minimum is "32GB+ VRAM". The L4 is below it. RTX PRO 6000 runs the official NVFP4 18.72 GB plus the TE resident. | [FACT] + [REC] (concession to Agent 2) |
| C4 | Two Docker images in one GPU execution | **One GPU image** (ComfyUI + LTX nodes, pinned). **TTS in a separate step before the GPU job**, so the user can approve the script and voice before any GPU spend. **Whisper/alignment on CPU** (faster-whisper, or forced alignment of the known script). | "The GPU can only be attached to one container" [FACT]. Agent 2's UX and cost argument for TTS, which I accept. | [FACT] + [TRADE-OFF] |
| C5 | Video, then voice | **Narration first**: TTS, then measured durations, then the clip plan (`num_frames % 8 == 1`), then LTX | Timing correctness. | [REC] (both agents) |
| C6 | One monolithic execution, timeout 60–90 min, retries 0 | **Tasks capped at ≤ 45 min**, a per-clip checkpoint to GCS (deterministic seed, skip existing clips), **maxRetries 1–2**, failure classification by exit code, and a per-clip watchdog | GPU tasks are not live-migrated. >1 h is Preview ("12 hours (preview)"). Spend caps kill in-flight tasks. | [FACT] task-timeout, quotas, billing-settings |
| C7 | Billing alerts only | **Spend cap** (monthly backstop set 10–20% below the true ceiling) **plus** Postgres per-user/daily GPU-second quotas plus a reaper | Caps are estimated-cost based, monthly only, and limited to one service per project. | [FACT] budgets-spend-caps |
| C8 | Clips, audio and intermediates in R2 | **Intermediates in same-region GCS** (7-day lifecycle). The **GPU job writes only to GCS**. The CPU render job uploads finals and thumbnails to R2. | GCP→internet egress is about $0.12/GiB. The GPU job needs no internet access, so no NAT if it can avoid Direct VPC. | [FACT] vpc/network-pricing, GCS pricing |
| C9 | Callback-driven status | **Postgres state machine** (`queued → dispatching → running(exec_id) → clips k/n → rendering → done/failed`). Write `dispatching` plus an idempotency key **before** `RunJob`. Label executions. Run a reconciler every 1–2 min that reads Cloud Run executions and GCS markers. | Closes the orphan and duplicate window (Agent 2). | [REC] |
| C10 | Fallback: Mumbai Cloud Run, then AWS G5 | **(1)** Cloud Run in a second region, **(2)** Cloud Run RTX PRO 6000, **(3)** Modal or RunPod serverless, **(4)** AWS g6/g6e in Mumbai, only after G/VT quota is granted | AWS "Running On-Demand G and VT instances" default is **0**. Mumbai Cloud Run L4 is "by invitation only". | [FACT] AWS quota doc, jobs/gpu |
| C11 | "VoiceStudio" | **Call a named TTS engine directly** (e.g. OmniVoice: code Apache-2.0, **weights licence still unverified**). Add a voice-cloning consent record. | VoiceStudio is AGPL-3.0 and an app, not a library. | [FACT] GitHub API |
| C12 | Remotion + FFmpeg from day one | **FFmpeg-only MVP** (concat, ASS captions, amix, two-pass loudnorm). Remotion later, budgeting $100/mo if headcount > 3. | Removes Chrome, licence cost and RAM. | [FACT] licence + [TRADE-OFF] |
| C13 | "Commercial licensing to validate" (generic) | **Gate 0: written answer from Lightricks on LTX-2.x Attachment A item 20** ("directly competes … without obtaining a separate commercial license"), plus item 19 (watermark/provenance) | An existential risk. I missed it in Round 1. | [FACT] text (LICENSE-2_x, ll. 598–607); applicability is a legal [ASSUMPTION] |
| C14 | Cost table ($1.0465/h, 7.5 min per video) | **Tier-correct rates.** No per-video target until POC $/output-second. Include staging (≥ 254 s on the Direct VPC path), egress, spend-cap slack, and licences. | The doc's rates are Tier 1. Runtime is unbenchmarked. | [FACT] + concession |

#### 3. Decisions that remain UNCERTAIN (and the exact test that resolves each)

| # | Uncertainty | POC / benchmark (pass criterion) |
|---|---|---|
| U1 | Do GPU jobs accept an ephemeral disk? Both pages are silent. | **Day 1:** deploy an L4 job (europe-west4) with `--add-volume type=ephemeral-disk,size=50Gi` and request the per-instance quota above 10 GiB. Pass if the deploy succeeds and `df` shows ≥ 50 GiB. |
| U2 | Does the RTX PRO 6000 20/80 minimum deploy, despite the jobs table maximum of 8 vCPU / 32 GiB? | Dry-run deploy of `nvidia-rtx-pro-6000` with `--cpu 20 --memory 80Gi`. |
| U3 | Fastest staging path | Time to copy 24–32 GB to the ephemeral disk via: (a) default egress with `gcloud storage cp`; (b) Direct VPC all-traffic + PGA (cap 125 MB/s, plus a minute or more connection delay); (c) a PSC endpoint for Google APIs with private-ranges-only; (d) a slim model set **baked into the image** (image streaming); (e) GCS FUSE with `enable-buffered-read`; (f) Rapid Cache. **Pass: staging ≤ 15% of billed time per execution.** |
| U4 | LTX-2.5 on L4: fit, speed, quality | Matrix: {L4 8/32: Q4_K_M, Q5_K_M, Q8_0 GGUF, official int8-convrot} vs {RTX PRO 6000: NVFP4 / bf16}. Distilled single-stage, 720p and 1080p, 121 and 241 frames. Measure peak VRAM, peak host RSS, TE/DiT/VAE seconds, and a blinded quality score against the RTX PRO 6000 baseline. **Output: $/output-second. Pick the cheapest arm that passes quality.** |
| U5 | Does a smaller text encoder hurt? | Community Gemma Q4 GGUF (8.41 GB) vs official int8 (15.37 GB), compared on prompt adherence (same seeds). |
| U6 | Is A2V viable for lip-sync or premium features? | Official ComfyUI `A2V_Two_Stage_Distilled` on RTX PRO 6000, then on L4 with int8/GGUF swaps. Measure VRAM and time against single-stage T2V. |
| U7 | TTS placement (CPU job vs GPU job) | Real-time factor of the chosen engine on 8 vCPU vs L4 for 3 minutes of narration. Choose CPU if RTF ≤ 1 and quality is equal. |
| U8 | Does page cache from reading models off the disk count toward the container memory limit (OOM risk at 32 GiB)? | Monitor memory while loading 32 GB from the ephemeral disk on 32 GiB. |
| U9 | Image pull/stream time for an 8–15 GB ComfyUI image | Measure execution start to first log line, cold. |
| U10 | Clip continuity across 15–30 clips | Compare multishot, I2V last-frame chaining and LoRA on a 2-minute script. Use a human rating. |
| U11 | When to move long-form work to a warm-disk VM (GCE G2 or AWS g6/g6e NVMe) | Trigger: measured staging > ~15% of billed GPU time **or** > ~100 busy GPU-h/month. G2 Singapore price ($1.0531/h) is **third-party, unverified**. Confirm via the Billing Catalog API first. |
| U12 | Does the Lightricks item 20 clause apply? | A written response from Lightricks or counsel. **This blocks paid launch.** |

#### 4. Proposed alternatives I REJECT, and why

| # | Alternative | Why rejected (for the MVP) | Class |
|---|---|---|---|
| X1 | Stop/start **GCE G2 VM as the MVP primary** (Agent 2, Round 1) | No spend-cap eligibility (only Gemini API, Vertex/Agent Platform, Cloud Run, Cloud Run functions). A stopped VM and its PD are zonal, so a stockout blocks restart (`ZONE_RESOURCE_POOL_EXHAUSTED`). Adds OS, driver and image ownership plus a watchdog. Fixed PD cost. Agent 2 now concurs: phase-2 only. | [FACT] budgets-spend-caps, GCE troubleshooting docs; [TRADE-OFF] |
| X2 | **AWS as primary or first fallback** (my own Round 1) | G/VT quota defaults to 0. Second-cloud IAM/AMI/lifecycle. No equivalent kill switch. It keeps the best L4 unit price ($0.9664/h g6.xlarge, Mumbai), so it is retained as fallback #4. | [FACT] AWS quota doc, AWS price JSON |
| X3 | Direct VPC `all-traffic` + Cloud NAT as the **default** network path (my Round 1) | 1 Gbps per-instance cap, a minute or more connection delay, and 30 s+ more with NAT. Default egress may be faster [POC U3]. Adopt it only if the benchmark proves it wins. | [FACT] vpc-direct-vpc |
| X4 | Serverless VPC Access connector + NAT (Google's suggestion for faster NAT startup) | Connector VMs are billed by Compute Engine, run continuously, and "spend caps ignore them". | [FACT] billing-settings |
| X5 | A2V or lip-sync as the MVP default path | A two-stage workflow with a 2× upscale is heavier, and unproven on L4. Use narration only for timing in the MVP. (I agree with Agent 2's conclusion, but the reason is the **two-stage distilled** cost, not a dev-model requirement; see 0.2.) | [FACT] docs.ltx.io A2V guide |
| X6 | GKE (Autopilot/Standard) now | Control-plane and ops overhead are out of proportion for 1–3 GPUs. Revisit at sustained volume. | [TRADE-OFF] |
| X7 | The 12 h GPU task timeout | Preview. Maintenance terminates GPU tasks, so expect interruption. Chunk work at ≤ 45 min instead. | [FACT] task-timeout |
| X8 | Delayed jobs for GPU cost savings | GPU price is unchanged (only CPU and memory are discounted, −15.8% on 8/32 total). Provisioning can be delayed up to 12 h. At most an "economy tier". | [FACT] run/pricing, delayed-jobs |
| X9 | Drain mode with **idle-waiting** for new jobs | Agent 2 is right that it pays ~$1.71/h for idle GPU at low arrival rates. I keep **drain-on-lease only** (process what is queued, never wait). It is a minor optimization, not a core cost lever, at MVP volume. | [REC] |
| X10 | `@remotion/cloudrun` | "Alpha … not actively being developed". | [FACT] remotion.dev |
| X11 | VoiceStudio app as the TTS component | AGPL-3.0 desktop/server app, not a library. | [FACT] GitHub |

#### 5. Valid arguments from Agent 2 that I explicitly acknowledge

1. **LTX-2.x Attachment A item 20** (competing products) is the #1 risk, and I missed it. [FACT, LICENSE-2_x]
2. **AWS G/VT on-demand quota is 0 by default**, not merely "low". [FACT]
3. **The Direct VPC 1 Gbps per-instance cap and startup delays** invalidate my 200–500 MB/s staging illustration. Staging is a first-order cost (≥ $0.12 per execution at 8/32 Singapore on that path). [FACT]
4. **Cloud NAT** is a cost and a cold-start driver once Direct VPC `all-traffic` is used. [FACT]
5. **A spec-compliant GPU should be the POC baseline**, with L4 as the cost-down experiment. [REC]
6. **The write-ahead `dispatching` state machine and reconciler** close the orphan/duplicate GPU-spend window better than my polling proposal. [REC]
7. **TTS before the GPU job enables user approval before GPU spend.** I adopt it. [TRADE-OFF]
8. **A Tier 1 region as the batch default** (latency does not matter for async generation). I adopt it, subject to residency. [FACT prices / TRADE-OFF]
9. **Drain mode gives little amortization at "handful per month" volume** and adds multi-tenant hygiene duties (per-job dirs, no shared per-user LoRAs). [ASSUMPTION about arrival rate; mechanism sound]
10. **No per-video cost target before benchmarking.** [concession]
11. The **OmniVoice weights licence is unverified**, and **voice-cloning consent** is required. Oracle hardening: only 5 free volume backups, an external uptime check, a rebuild-in-1h runbook. **Validate user media before GPU spend.**
12. **GCE GPU VMs get 1 h maintenance notice vs 10 s on Cloud Run.** I found this while testing Agent 2's argument; it is a genuine point for the VM in the long-form phase. [FACT gpu-host-maintenance]

#### 6. Recommended MVP architecture (15 bullets)

1. **Gate 0, licence:** get a written Lightricks answer on item 20 (and confirm item 19 compliance), the TTS weights licence, and the Remotion tier. No paid launch before this. [FACT text / legal ASSUMPTION]
2. **Control plane:** Oracle A1 (ARM64) running Next.js, API, Postgres, a `SKIP LOCKED` queue, the state machine and the reconciler. pgBackRest/WAL-G to R2. External uptime check. IaC rebuild runbook. [REC]
3. **GPU region:** **europe-west4** Cloud Run Jobs (Tier 1; L4 and RTX PRO 6000 both available). Use **asia-southeast1** only if residency requires APAC. Both regions get GPU quota and ephemeral-disk quota requests in week 1. [FACT regions/prices; TRADE-OFF]
4. **GPU SKU:** chosen by POC U4. **Baseline RTX PRO 6000** (20 vCPU / 80 GiB, NVFP4 distilled + TE resident; Tier 1 in europe-west4 = 0.00036522×3600 + 20×0.000018×3600 + 80×0.000002×3600 = 1.3148 + 1.2960 + 0.5760 = **$3.1868/h**). **Cost-down arm:** L4 at 8 vCPU / 32 GiB ($1.4209/h). Ship whichever has the lowest $/output-second that passes quality. [FACT prices / POC]
5. **Model set (L4 arm):** distilled only. Q4/Q5 GGUF or official int8 DiT, int8 or Q4 Gemma TE, Conv VAE, and audio VAE only if LTX audio is used. Prompt enhancer **off**. Auto-download **blocked**. Hashes pinned. Mirrored in a regional GCS bucket. [FACT file sizes / REC]
6. **Staging:** an ephemeral disk (50–60 GiB, after quota) filled by parallel `gcloud storage cp` over the **default** network path, or baked into the image, whichever U3 shows is faster. Never write models to the in-memory filesystem. [FACT limits / POC]
7. **One GPU image:** ComfyUI + ComfyUI-LTXVideo (pinned), driven headless by `worker_entrypoint.py`. Per-job temp dirs, wiped after each job. [FACT one-GPU-container / REC]
8. **Pipeline:** TTS CPU job, then user approves script and voice, then a clip plan (`num_frames % 8 == 1`) from narration durations, then the GPU job (distilled T2V/I2V), then the CPU render job (FFmpeg-only, two-pass loudnorm, ASS captions). Alignment by forced alignment or faster-whisper on CPU. [REC / TRADE-OFF]
9. **GPU job shape:** `RunJob` with overrides (job IDs and clip ranges). **Tasks capped at ≤ 45 min.** Per-clip checkpoint to `gs://work/{job}/clips/{i}.mp4`. Deterministic seeds. maxRetries 1–2. Drain-on-lease with no idle wait. Exit codes classify capacity vs deterministic failures. [FACT timeout/maintenance / REC]
10. **Storage:** intermediates in regional GCS (7-day lifecycle). The GPU job has **no internet egress requirement**. The render job uploads finals and thumbnails to R2. Presigned GETs of 15–60 min after an ownership check. [FACT pricing / REC]
11. **Orchestration identity:** a dedicated SA with a custom role (`run.jobs.runWithOverrides`, `run.executions.get/list/cancel` on one job). Key rotated every 90 days. Move to **WIF-OIDC with an uploaded JWKS** before paid launch. Worker SA: models read-only, work bucket read/write. R2 token in Secret Manager. [FACT WIF docs / REC]
12. **Cost controls:** a Cloud Run **spend cap** at 80–90% of the ceiling, per-user and daily GPU-second quotas in Postgres, a max output duration per plan, a stuck-execution reaper, and log-level WARNING plus exclusions. [FACT spend caps / REC]
13. **Safety:** prompt, image and voice moderation and validation **before** dispatch. Voice-clone consent records. No removal of watermarking or provenance. [FACT licence item 19 / REC]
14. **Fallback:** (1) the other Cloud Run region, (2) the other GPU SKU, (3) Modal/RunPod with the same container, (4) AWS g6/g6e Mumbai after quota. Fallback triggers only on capacity or quota errors. [FACT quota/regions / REC]
15. **Scale trigger:** move long-form work to a warm-disk VM pool (GCE G2/G4 or AWS g6/g6e with NVMe, with watchdog) when measured staging exceeds 15% of billed GPU time or busy time exceeds ~100 GPU-h/month. Otherwise stay on Cloud Run. [ASSUMPTION thresholds / TRADE-OFF]

##### References (accessed 2026-11-10/11)

- Direct VPC egress limits: https://docs.cloud.google.com/run/docs/configuring/vpc-direct-vpc
- Ephemeral disk (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/ephemeral-disk
- GPU jobs: https://docs.cloud.google.com/run/docs/configuring/jobs/gpu
- GPU best practices: https://docs.cloud.google.com/run/docs/configuring/jobs/gpu-best-practices
- Task timeout: https://docs.cloud.google.com/run/docs/configuring/task-timeout
- Quotas: https://docs.cloud.google.com/run/quotas
- Pricing: https://cloud.google.com/run/pricing
- Billing settings: https://docs.cloud.google.com/run/docs/configuring/billing-settings
- Spend caps: https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps
- GCE GPU maintenance: https://docs.cloud.google.com/compute/docs/gpus/gpu-host-maintenance
- LTX-2 README: https://github.com/Lightricks/LTX-2
- LTX A2V ComfyUI guide: https://docs.ltx.io/open-source-model/usage-guides/audio-to-video
- LTX requirements: https://docs.ltx.io/open-source-model/getting-started/system-requirements
- LTX licence: https://github.com/Lightricks/LTX-2/blob/main/LICENSE-2_x
- AWS EC2 quotas: https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html
- WIF (OIDC, uploaded JWKS): https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-other-providers


---

## Part D — Round 3: Agent 2 final position (verbatim)

### Round 3: Agent 2's Final Position

| Field | Value |
|---|---|
| Author | Agent 2 (Principal DevOps / AI Infrastructure, critical reviewer) |
| Date | 2026-11-11 |
| Inputs | `01-agent-1-review.md`, `_round2-agent1.md`, my `02-agent-2-review.md` and `_round2-agent2.md`. None of them were edited. |
| Re-verification this round | Raw HTML of current pages: Cloud Run quotas, task-timeout, GPU best practices for jobs, and Compute Engine GPU host maintenance (fetched 2026-11-11). |
| Labels | **[FACT]** confirmed (source given). **[REC]** evidence-supported recommendation. **[ASSUMPTION]** requires testing. **[TRADE-OFF]** preference. |

#### 0. Re-verification of the two items still contested

**0.1 GPU job task timeout. I withdraw "1 h GA cap"; Agent 1 is right.**

The current pages say:
- **Quotas page:** "Maximum tasks timeout value: 168 hours (7 days), or **12 hours if using GPUs**." [FACT] https://docs.cloud.google.com/run/quotas
- **Task-timeout page** (it carries a "Preview: Long running GPU jobs" banner): "For tasks using GPUs, the maximum available timeout is 12 hours (preview)." It also says: "Tasks that use GPUs are not live migrated, so routine infrastructure maintenance terminates them. A task configured with a multi-hour timeout should be expected to be interrupted at least once before it completes." [FACT] https://docs.cloud.google.com/run/docs/configuring/task-timeout
- **GPU best practices page:** "Set a task timeout of **one hour or lesser** for job executions." [FACT] https://docs.cloud.google.com/run/docs/configuring/jobs/gpu-best-practices

My "1 h GA" wording came from search snippets of an older revision. It is not in the current docs. The correct framing is that **≤1 h is Google's recommended envelope**, while anything longer runs on a Preview feature and is interruption-prone. The design conclusion is unchanged: chunked, checkpointed tasks of 45 minutes or less.

**0.2 Does Cloud Run need Direct VPC or NAT to reach GCS? No. Agent 1 is right.**

The best-practices text reads: "To **optimize** ML model loading … you must use Direct VPC with the egress setting value set to all-traffic, along with Private Google Access." [FACT] (same URL). That is a performance prescription, not a functional requirement. Default Cloud Run egress reaches Google APIs and R2 without a VPC. My Round 1 phrasing ("FUSE requires Direct VPC") was overstated.

Two consequences follow:
- (a) The baseline should be **no VPC, no NAT**. Adopt Direct VPC only if the POC shows it is materially faster. [REC]
- (b) The Direct VPC page also says: "Cloud Run supports throughput of up to 1 Gbps per individual container instance", with startup delays of "a minute or more" and "30s or more" when Cloud NAT is involved. [FACT] https://docs.cloud.google.com/run/docs/configuring/vpc-direct-vpc. So Direct VPC is not a free win, and whether it helps is an open benchmark question.

**0.3 Compute Engine GPU maintenance notice.** Confirmed: "For compute instances that have attached GPUs, Compute Engine provides this notice **1 hour** before the compute instance stops". Maintenance "typically occur[s] once every two weeks". [FACT] https://docs.cloud.google.com/compute/docs/gpus/gpu-host-maintenance

---

#### 1. Original decisions that should REMAIN

| # | Decision | Reason | Class |
|---|---|---|---|
| R1 | Control plane (Next.js, API, Postgres, queue, orchestrator) on the existing Oracle Always Free A1 VM, **for MVP/beta** | Free compute (2 OCPU / 12 GB / 200 GB). Load is light. Reclamation needs p95 CPU, network and memory all under 20% over 7 days, which is unlikely with Postgres + Node resident. | [FACT] Oracle Always Free docs; [ASSUMPTION] about the reclamation likelihood |
| R2 | Scale-to-zero GPU on **Cloud Run Jobs** | Jobs are GA with GPU. Instances start in about 5 s. There is no idle cost. A 3-GPU quota is auto-granted. It is the **only GPU option covered by GA budget spend caps** (Compute Engine is not eligible). | [FACT] configuring/jobs/gpu; billing-settings; budgets-spend-caps |
| R3 | Models in **GCS** (same region as the job), copied to local storage before load, with no random FUSE reads | Same-location GCS to Cloud Run transfer is free. Google recommends GCS (`gcloud`/API parallel download) for models over 10 GB. | [FACT] GCS pricing; gpu-best-practices |
| R4 | **Sequential stages** on one GPU, never concurrent | VRAM: the int8 Gemma 4 text encoder (15.37 GB) and any DiT variant cannot be co-resident on 24 GB. | [FACT] HF file sizes (Agent 1) + arithmetic |
| R5 | AI generation separated from final assembly, which runs on a **CPU job** | Rendering on a GPU-billed instance wastes $0.81/h of L4 time in Singapore. | [FACT] pricing + [REC] |
| R6 | **Cloudflare R2 for user delivery**, using signed and expiring URLs | Egress is free. Presigned URLs allow 1 s to 7 days (S3 endpoint only, not custom domains). | [FACT] R2 docs |
| R7 | **Concurrency 1** at launch, and fallback only on capacity errors | Correct admission control and failure taxonomy. | [REC] |
| R8 | **Common job interface**, so the GPU provider is replaceable | It enables the fallback chain and the later VM migration. | [REC] |
| R9 | **Staged roadmap with a production gate** (VRAM, load time, licences) | Correct, but the gate must move to the front (see C1). | [REC] |

---

#### 2. Original decisions that should CHANGE (from → to)

| # | From | To | Reason | Class |
|---|---|---|---|---|
| C1 | Licence check as the last "production gate" | **Gate 0, before any build:** get written clearance or a commercial licence from Lightricks under LTX-2.x Attachment A item 20 (competing products). Also confirm the OmniVoice weights licence, the Gemma 4 encoder terms, and the Remotion tier (more than 3 employees means Automators at a $100/month minimum). | Item 20 text verified. Both agents agree it is the #1 risk. | [FACT] text; legal judgment needed |
| C2 | L4 24 GB as "the" GPU | **The POC baseline is spec-compliant hardware** (Cloud Run RTX PRO 6000 96 GB, Singapore, $3.824/h). **L4 8/32 is the cost-down candidate** and needs ≥2.24× better $/clip on RTX PRO 6000 to lose. | Lightricks requires a minimum of 32 GB+ VRAM and 32 GB RAM. The L4 is below both. | [FACT] docs.ltx.io; [FACT] pricing arithmetic |
| C3 | 4 vCPU / 16 GiB | **8 vCPU / 32 GiB** for L4 (the tier maximum and Google's recommendation). 20/80 for RTX PRO 6000. | 16 GiB cannot hold an offloaded text encoder plus DiT. The in-memory filesystem counts against RAM. | [FACT] services/gpu; container-contract |
| C4 | Copy models into "temporary local storage" (which is RAM-backed) | **Ephemeral disk (GA 2026-11-04), 50–60 Gi.** Request the per-instance quota above the 10 GiB default (the regional 100 GiB is auto-granted on first deploy). **Fallback if the disk is unsupported with GPU:** a slim model set baked into the image. | Ephemeral disk compatibility with GPU jobs is not stated anywhere. | [FACT] ephemeral-disk page; [ASSUMPTION] GPU compatibility |
| C5 | Cost $1.04652/h | **Singapore: $1.2558/h (4/16), $1.7051/h (8/32), $3.8241/h (RTX PRO 6000).** Tier 1 (us-central1/europe-west4) L4 8/32 is **$1.4209/h**. | The doc used Tier 1 rates for a Tier 2 region. | [FACT] run/pricing + arithmetic |
| C6 | One monolithic execution per video, timeout 60–90 min, retries 0 | **Tasks of ≤45 min** (`taskCount = ⌈clips/k⌉`). **Per-clip checkpoint** to GCS with deterministic seeds. **maxRetries 1–2.** Classify failures by exit code. A per-clip watchdog. | GPU tasks are terminated on maintenance with a 10 s SIGTERM. A spend-cap trip fails in-progress tasks. Google recommends ≤1 h. | [FACT] task-timeout; billing-settings; gpu-best-practices |
| C7 | Two Docker images in "one shared GPU execution" | **One GPU image** (ComfyUI + LTX, pinned commits, auto-download disabled, prompt enhancer off). | Only one container can hold the GPU. | [FACT] configuring/jobs/gpu |
| C8 | Video first, then voice | **Narration first.** TTS, then measured durations, then the clip plan (`num_frames % 8 == 1`), then LTX. | Otherwise narration and visuals do not match. | [REC] |
| C9 | VoiceStudio (AGPL app) + Whisper on the GPU | **Call the TTS engine directly** (OmniVoice, Apache-2.0 code; weights licence TBD), on CPU if its real-time factor is acceptable, otherwise as the first stage in the GPU job. **Use forced alignment or faster-whisper on CPU** for captions. | Both agents agree on alignment on CPU. TTS placement is decided by the POC. | [FACT] licences; [TRADE-OFF] |
| C10 | Assets bounce GPU job → R2 → render → R2 | **The GPU job writes only to GCS** (same region; intermediates expire after 7 days). **The CPU render job uploads finals to R2.** | Removes R2 egress and any NAT from the GPU job. GCP to R2 is internet egress at about $0.12/GiB. | [FACT] GCS pricing / pricing-announce; [REC] (Agent 1's refinement) |
| C11 | Queue on Oracle + callbacks | **Postgres state machine** (`SKIP LOCKED`/pg-boss) with a write-ahead `dispatching` state and an idempotency key, Cloud Run execution labels, and a reconciler polling `executions.get/list` plus GCS markers. Callbacks are hints only. | Closes the orphan and duplicate GPU-spend window. | [REC] |
| C12 | Billing alerts only | **GA budget spend cap** on the Cloud Run project, set 10–20% below the ceiling, plus per-user GPU-second quotas and max output seconds per plan. | Caps are GA. Enforcement is estimated, monthly, and per project + service. | [FACT] release notes 2026-10-12; budgets-spend-caps |
| C13 | Fallback: Mumbai L4 → AWS G5 | **1)** Cloud Run L4 in a Tier 1 region. **2)** Cloud Run RTX PRO 6000 (Singapore/Delhi). **3)** Modal/RunPod. **4)** AWS g6/g6e in ap-south-1, only after the G/VT quota (default 0) is granted. | Mumbai Cloud Run L4 is invitation-only. AWS G/VT quota defaults to 0 vCPU. | [FACT] jobs/gpu; EC2 quotas; DescribeInstanceTypeOfferings |
| C14 | Oracle VM with ad-hoc backups | **WAL-G/pgBackRest to R2 with restore drills**, a rebuild runbook/IaC, an external uptime check, and Cloudflare in front. Consider managed Postgres before taking payments. | Single point of failure, no SLA, only 5 free volume backups. | [FACT] Oracle docs; [REC] |
| C15 | "Securely authenticated service account" | **A custom role** limited to `run.jobs.runWithOverrides` + `run.executions.get/list/cancel` on one job, with a rotated SA key for the MVP. Move to **WIF OIDC with an uploaded JWKS** before paid launch. | Agent 1's documented WIF path is better than my "self-run issuer" framing. | [FACT] WIF other-providers doc (per Agent 1); [TRADE-OFF] |

---

#### 3. Decisions that remain UNCERTAIN, and the POC that resolves each

| # | Uncertainty | Resolving POC / benchmark (pass criteria) |
|---|---|---|
| U1 | Does LTX-2.5 work on an L4 at all, and at what quality and speed? | **POC-1 matrix.** {L4 8/32: Q4_K_M, Q5_K_M, official int8-convrot with offload} × {RTX PRO 6000 20/80: NVFP4/bf16}. Distilled pipeline, conv VAE, 720p and 1080p, 121 and 241 frames, fixed prompts. Record peak VRAM, peak RSS (OOM?), text-encoder time, sampling time, VAE decode time, and blinded quality against the bf16/RTX baseline. **Output: $/output-second.** Pass: the L4 is no worse in quality and ≤1/2.24 of the RTX $/s. |
| U2 | Does ephemeral disk attach to GPU jobs? | **POC-0.** A dry-run deploy of an L4 job with a 50 Gi ephemeral disk (after the per-instance quota increase). Pass: it deploys and `df` shows the volume. |
| U3 | What is the fastest model staging path? | **POC-2.** Stage the slim working set (about 30 GB) via: (a) default egress + `gcloud storage cp`; (b) Direct VPC all-traffic + Private Google Access; (c) Direct VPC private-ranges-only + private Google API DNS; (d) a slim model set baked into the image (image streaming); (e) FUSE buffered-read. Measure wall time to first denoising step. Note the documented 1 Gbps Direct VPC cap. |
| U4 | Is the page cache from model reads counted toward the memory limit and causing OOM? | Inside POC-2: read the full model set from ephemeral disk at 32 GiB and watch container memory metrics. |
| U5 | Should TTS run on CPU or in the GPU job? | **POC-3.** Measure the chosen engine's real-time factor on 8 vCPU against its L4 seconds. Pick CPU if a 3-minute narration renders in ≤5 minutes. Also confirm the weights licence. |
| U6 | Does checkpoint/resume survive a mid-clip kill? | **POC-4.** Send SIGTERM mid-clip and trip the spend cap in a test project. Pass: the retry skips completed clips and no duplicate output appears. |
| U7 | Can 15–30 clips stay visually consistent across a video? | **POC-5.** Compare LTX-2.5 multishot, I2V last-frame chaining and a character LoRA. This is a quality-gate rubric. |
| U8 | Should long-form move to a VM, and when? | Measure busy GPU-h/month and staging share. Move when **>~100 busy GPU-h/month or staging >15–20%** of execution time (Agent 1's illustrative break-even, which I accept as a decision rule, not a fact). Requires a verified G2 Singapore price, which is currently only third-party. |
| U9 | Is Remotion needed, or is FFmpeg alone enough? | **POC-6.** A 3-minute 1080p composition on CPU 8/32: vCPU-s per output minute and peak RAM. Use FFmpeg-only unless templated motion graphics are a product requirement. |
| U10 | Which region should be primary? | Data-residency and latency requirements from the product owner. If APAC residency is not required, use a Tier 1 region (16.7% cheaper). |
| U11 | Are the quotas actually granted? | File requests in week 1: Cloud Run L4 (Singapore + Tier 1), RTX PRO 6000, ephemeral-disk per-instance limit, and AWS G/VT. Record turnaround. |

---

#### 4. Proposed alternatives I REJECT, and why

| Alternative | Why rejected | Class |
|---|---|---|
| A persistent always-on GPU | About $770–1,250/month idle, against "a handful of videos per month". | [FACT] pricing + arithmetic |
| GKE for the MVP | The cluster fee and operational load are disproportionate for at most 3 GPUs. | [TRADE-OFF] |
| **My own Round 1 "GCE VM as the long-form path now"** | Withdrawn for the MVP. It has no spend-cap coverage (GCE is not eligible), needs zonal stockout recovery, and requires a patching pipeline. Its G2 price is unverified. It stays as the phase-2 option, gated by U8. (The 1-hour maintenance notice is a real VM advantage, acknowledged in §5.) | [FACT] budgets-spend-caps; [TRADE-OFF] |
| A single execution running 12 h (Preview) for long videos | Preview status. Google itself says such a task should be expected to be interrupted at least once. | [FACT] task-timeout |
| **Agent 1's drain mode with idle-waiting for new jobs** | It bills $1.71/h for an idle L4 at low arrival rates. I accept drain-*on-lease* only: process jobs already queued, then exit. Each job must get its own scratch directory, wiped after use. | [ASSUMPTION] arrival rate; [REC] |
| **Agent 1's Direct VPC all-traffic + NAT as the default model path** | It is not functionally required. It has a documented 1 Gbps cap plus startup and NAT delays. Make it a benchmark arm (U3), not the default. | [FACT] vpc-direct-vpc; gpu-best-practices |
| **Agent 1's LTX audio-to-video (A2V) as the pipeline's mode** | The official A2Vid pipeline uses the **dev** DiT plus the distilled LoRA in a guided two-stage flow. That is heavier than distilled T2V/I2V. Use it as a premium POC on ≥48 GB hardware only. | [FACT] LTX-2 README |
| Community Q4 GGUF **as the only** L4 option, or official int8 **as the only** option | Each has a weakness. Q4 is not validated by Lightricks and carries supply-chain risk. The int8 DiT (21.5 GB) is unlikely to fit fully. Test both (U1). | [FACT] sizes; [ASSUMPTION] fit |
| AWS Batch as the first fallback | Default quota 0, a second cloud, and boot latency. It comes fourth in the order. | [FACT] EC2 quotas |
| VoiceStudio (the AGPL desktop app) inside the worker | AGPL network obligations if modified, and an app architecture rather than a library. Call the engine directly. | [FACT] repo licence |
| `@remotion/cloudrun` | "Alpha and not actively being developed". | [FACT] remotion.dev |
| A Cloud Run "per-video target ~$0.15–0.25" (Agent 1, Round 1) | Unsupported. Staging alone may cost about $0.05–0.12 per execution. Derive the target from POC-1 $/output-second. | [ASSUMPTION] flagged |

---

#### 5. Valid arguments from Agent 1 that I explicitly acknowledge

1. **Singapore pricing:** L4 $0.00022404/s, so $1.2558/h at 4/16 and $1.7051/h at 8/32. My $1.12/$1.57 were wrong. [FACT]
2. **Budget spend caps** are GA (2026-10-12). For jobs, new tasks fail to start and in-progress tasks fail. Compute Engine is not eligible. [FACT]
3. **No "1 h GA" wording in the current docs.** It is 12 h (Preview), with ≤1 h as the recommended envelope (§0.1). [FACT]
4. **Direct VPC is an optimisation, not a requirement** for GCS (§0.2). [FACT]
5. **Ephemeral disk:** the regional 100 GiB is auto-granted. The real gate is the 10 GiB per-instance default. [FACT]
6. **Compute Engine GPU VMs get 1-hour maintenance notice**, against Cloud Run's 10 s SIGTERM. [FACT]
7. **The official int8 DiT (21.5 GB) is unlikely to be fully resident on 24 GB.** My "prefer official int8/FP8 on L4" was too strong; Q4/Q5 GGUF must be in the matrix. [FACT] sizes + [ASSUMPTION] fit
8. **"GPU job → GCS only; CPU render → R2"** removes NAT and egress from the GPU job. [REC]
9. **WIF OIDC with an uploaded JWKS / X.509** is a documented path for Oracle to GCP. My "self-run issuer only" framing was incomplete. [FACT] (per Agent 1's cited docs)
10. **Same-region GCS to Cloud Run is confirmed free.** **g6 Mumbai at $0.9664/h** is officially verifiable via the AWS price JSON. [FACT]
11. The exact HF file sizes, the **32 GB system-RAM minimum**, the auto-download and default prompt-enhancer hazards, and that **R2 presigned URLs do not work on custom domains**. [FACT]
12. A Tier 1 region is **16.7% cheaper** ($1.4209/h at L4 8/32). I agree it could even be primary for async batch. [FACT] + [TRADE-OFF]

---

#### 6. Recommended MVP architecture (15 bullets)

1. **Gate 0, legal:** written LTX-2.x item-20 clearance or a commercial licence. Confirm the TTS weights, Gemma and Remotion licence tiers before any build. [FACT: licence text; REC]
2. **Control plane:** the Oracle A1 VM (2 OCPU / 12 GB, arm64 builds) runs Next.js, the API, auth and Postgres. Cloudflare sits in front. WAL-G/pgBackRest go to R2, with an external uptime check. [FACT/REC]
3. **Queue and orchestration:** a Postgres `SKIP LOCKED` queue (pg-boss) and a state machine: `queued → dispatching(idem-key) → running(exec-id) → clips k/n → rendering → done/failed`. A reconciler polls Cloud Run executions and GCS markers every 1–2 minutes. [REC]
4. **Region:** Tier 1 `us-central1` or `europe-west4` by default (L4 8/32 at $1.4209/h). Use `asia-southeast1` ($1.7051/h) only if data residency or ops proximity requires it. The model bucket, intermediates bucket, Artifact Registry and jobs all live in the same region. [FACT pricing; TRADE-OFF]
5. **GPU:** start with the **POC-1 matrix** (L4 8/32 against RTX PRO 6000 20/80) and pick by $/output-second at acceptable quality. The job definition switches between `nvidia-l4` and `nvidia-rtx-pro-6000` with one flag. Use `--no-gpu-zonal-redundancy`. [FACT/POC]
6. **Host sizing:** L4 at 8 vCPU / 32 GiB (or RTX PRO 6000 at 20 / 80 GiB). The **2nd-gen execution environment** with a 50–60 Gi **ephemeral disk** for models, after a quota request and the POC-0 GPU-compatibility check. [FACT; POC]
7. **Model path:** a slim, pinned, hash-verified working set (distilled DiT variant + text encoder + conv VAE + audio VAE only) in GCS. Parallel `gcloud storage cp` to the ephemeral disk over **default egress**. Direct VPC is only adopted if POC-2 shows a gain. A baked slim image is the fallback. No runtime downloads. [FACT/REC/POC]
8. **GPU worker:** **one image** (ComfyUI headless, pinned commits, prompt enhancer off). A task processes clips `[i·k, (i+1)·k)`. Each task is **≤45 min**. Each clip is uploaded to GCS immediately with deterministic seeds. `maxRetries=1–2`, resume skips completed clips, and a per-clip watchdog runs. Exit codes classify failures (capacity vs deterministic). [FACT/REC]
9. **Batching:** drain-on-lease only (jobs already queued at start). No idle waiting. Scratch directories are per job and wiped after use. `parallelism` stays below the GPU quota (3), sequential by default and parallel for priority tiers. [REC]
10. **Pipeline order:** TTS (engine called directly; CPU if POC-3 passes, else the first GPU stage) → durations → clip plan → LTX distilled T2V/I2V → captions via forced alignment or faster-whisper on CPU. A2V/lip-sync is premium only, after a ≥48 GB POC. [FACT/REC]
11. **Render:** a Cloud Run **CPU job** (8 vCPU / 16–32 GiB, with an ephemeral disk) reads GCS intermediates. MVP uses FFmpeg-only (concat, ASS subtitles, `amix`/ducking, two-pass `loudnorm`). Remotion is added via `@remotion/renderer` only when templating requires it and the licence tier is resolved. [FACT/TRADE-OFF]
12. **Storage:** GCS `work` bucket with a 7-day lifecycle for intermediates. **Only finals, thumbnails and previews go to R2**, uploaded by the render job. Delivery uses presigned GET URLs valid 15–60 minutes, issued after an ownership check. [FACT/REC]
13. **Cost controls:** a GA budget spend cap on the Cloud Run project (10–20% below the ceiling), per-user GPU-second quotas, max output seconds per plan, a reaper for executions over budget, and logs at WARNING level. [FACT/REC]
14. **Security:** an Oracle SA with a custom role on a single job (rotated key), moving to WIF OIDC with an uploaded JWKS before paid launch. The worker SA gets read on models and write on work. The R2 token sits in Secret Manager, scoped to one bucket. Prompts and inputs are moderated and media validated *before* any GPU spend. Voice cloning requires recorded consent. [REC]
15. **Fallback chain** (same job contract): Cloud Run in a second region → Cloud Run RTX PRO 6000 → Modal/RunPod → AWS g6/g6e (ap-south-1, after the G/VT quota is granted from its default of 0). **Phase-2 trigger** to a warm-disk VM/MIG: more than ~100 busy GPU-h/month or staging above 15–20% of execution time. [FACT/TRADE-OFF]

---

#### References (accessed 2026-11-11)

**Cloud Run**
- Quotas: https://docs.cloud.google.com/run/quotas
- Task timeout: https://docs.cloud.google.com/run/docs/configuring/task-timeout
- GPU best practices (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/gpu-best-practices
- Direct VPC egress: https://docs.cloud.google.com/run/docs/configuring/vpc-direct-vpc
- GPU (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/gpu
- Ephemeral disk (jobs): https://docs.cloud.google.com/run/docs/configuring/jobs/ephemeral-disk
- Billing settings: https://docs.cloud.google.com/run/docs/configuring/billing-settings
- Release notes: https://docs.cloud.google.com/run/docs/release-notes
- Pricing: https://cloud.google.com/run/pricing

**Compute Engine and Cloud Billing**
- GPU host maintenance: https://docs.cloud.google.com/compute/docs/gpus/gpu-host-maintenance
- Budget spend caps: https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps

**Lightricks / LTX**
- LTX-2 README: https://github.com/Lightricks/LTX-2
- LTX-2.x licence: https://github.com/Lightricks/LTX-2/blob/main/LICENSE-2_x
- System requirements: https://docs.ltx.io/open-source-model/getting-started/system-requirements

**AWS**
- EC2 quotas: https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-quotas.html

**Prior debate files**
- `01-agent-1-review.md`
- `_round2-agent1.md`
- `02-agent-2-review.md`
- `_round2-agent2.md`
