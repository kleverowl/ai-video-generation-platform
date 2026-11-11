# Graph Report - exp01  (2026-11-11)

## Corpus Check
- 47 files · ~40,560 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 225 nodes · 380 edges · 14 communities
- Extraction: 80% EXTRACTED · 19% INFERRED · 1% AMBIGUOUS · INFERRED: 74 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c4e48a37`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Original Cloud Run Plan
- Claude Workflow Skills
- Control Plane & Job Contract
- GPU Options & Fallbacks
- Final MVP Pipeline
- Decisions & Open Questions
- Cost Control & Storage
- LTX Model & Licensing
- plan.md: Autonomous Work Plan
- backend-dev.md
- frontend-dev.md
- devops-deploy.md
- qa-security.md
- LTX-2.5 22B Q4

## God Nodes (most connected - your core abstractions)
1. `Final Recommended Architecture (Chief Architect Arbitration)` - 30 edges
2. `Cloud Run GPU Job (On Demand)` - 18 edges
3. `Complete Video Generation Platform Architecture Plan` - 14 edges
4. `Architecture Review Round 1: Agent 1 (Senior Cloud Solutions Architect)` - 14 edges
5. `Technical Requirement Specification & System Architecture` - 13 edges
6. `Implementation Roadmap` - 13 edges
7. `Decision Matrix` - 13 edges
8. `Architecture Review Round 1: Agent 2 (Critical Infrastructure Reviewer)` - 12 edges
9. `One-time machine setup` - 10 edges
10. `/adr skill (ADR workflow)` - 10 edges

## Surprising Connections (you probably didn't know these)
- `GCP Billing API Dashboard with Manual Refresh + Cache` --semantically_similar_to--> `Cloud Run Budget Spend Cap (GA)`  [INFERRED] [semantically similar]
  system_architecture_technical_specification.md → architecture-review/01-agent-1-review.md
- `Architecture guard rule checklist` --semantically_similar_to--> `No idle-cost resources without an ADR`  [INFERRED] [semantically similar]
  .claude/agents/architecture-guard.md → infra/CLAUDE.md
- `Cloud Run On-Demand/Preemptible GPU Instances` --semantically_similar_to--> `Cloud Run GPU Job (On Demand)`  [INFERRED] [semantically similar]
  system_architecture_technical_specification.md → architecture.txt
- `Architecture guard rule checklist` --references--> `R-D12 Tasks <=45 min, per-clip checkpoints, retries 1-2`  [INFERRED]
  .claude/agents/architecture-guard.md → docs/context/decisions.md
- `Layered CLAUDE.md context placement` --semantically_similar_to--> `Load context on demand`  [INFERRED] [semantically similar]
  .claude/skills/handoff/SKILL.md → CLAUDE.md

## Hyperedges (group relationships)
- **Narration-First MVP Job Pipeline** — architecture_review_04_final_architecture_tts_worker, architecture_review_04_final_architecture_user_approval_gate, architecture_review_04_final_architecture_gpu_worker_image, architecture_review_04_final_architecture_gcs_work_bucket, architecture_review_04_final_architecture_render_worker [EXTRACTED 1.00]
- **Orchestration Correctness (state machine, write-ahead dispatch, reconciler)** — architecture_review_04_final_architecture_job_state_machine, architecture_review_04_final_architecture_write_ahead_dispatch, architecture_review_02_agent_2_review_postgres_state_machine_reconciler, architecture_review_05_implementation_roadmap_chaos_tests [INFERRED 0.85]
- **GPU Fallback Options** — architecture_aws_g5_fallback, architecture_review_01_agent_1_review_aws_g6_g6e, architecture_review_02_agent_2_review_modal_runpod, architecture_review_04_final_architecture_fallback_chain, architecture_review_06_decision_matrix_d11_fallback [INFERRED 0.85]
- **Video job pipeline (TTS -> approval -> GPU -> render -> R2)** — workers_tts_worker_readme, docs_context_project_brief_approval_gate, workers_gpu_worker_readme, workers_render_worker_readme, docs_context_project_brief_video_pipeline [EXTRACTED 1.00]
- **Resumable job orchestration (write-ahead dispatch, reconciler, done-markers)** — services_claude_write_ahead_dispatch, docs_context_project_brief_dispatcher, docs_context_project_brief_reconciler, docs_context_project_brief_done_marker, workers_claude_per_clip_checkpoint, docs_context_decisions_r_d7 [INFERRED 0.85]
- **Decision and evidence governance workflow** — _claude_skills_adr_skill, _claude_skills_poc_record_skill, _claude_skills_handoff_skill, _claude_agents_architecture_guard, docs_context_decisions, docs_context_open_questions [INFERRED 0.85]

## Communities (14 total, 0 thin omitted)

### Community 0 - "Original Cloud Run Plan"
Cohesion: 0.10
Nodes (33): Artifact Registry, AWS G5 A10G Mumbai Fallback, Cloud Run GPU Job (On Demand), Provider-Agnostic Common Job Interface, Complete Video Generation Platform Architecture Plan, Oracle Always Free VPS Control Plane, Pay for GPU Only When Needed Principle, PostgreSQL + Video Job Queue (+25 more)

### Community 1 - "Claude Workflow Skills"
Cohesion: 0.16
Nodes (24): architecture-guard agent, /adr skill (ADR workflow), Claim labels [FACT]/[REC]/[POC]/[TRADE-OFF], /cost-estimate skill, RTX PRO 6000 vs L4 break-even (>=2.24x), /handoff skill, Layered CLAUDE.md context placement, /poc-record skill (+16 more)

### Community 2 - "Control Plane & Job Contract"
Cohesion: 0.07
Nodes (33): Architecture guard rule checklist, Verified Cloud Run GPU/CPU unit rates, No number without a log, apps/web Next.js frontend + dashboard, Admin dashboard (job status, metrics, cancel, cost panel), R-D5 One GPU image; TTS and render as CPU jobs, R-D6 FFmpeg-only rendering for MVP, R-D8 Oracle A1 control plane (WAL backups to R2) (+25 more)

### Community 3 - "GPU Options & Fallbacks"
Cohesion: 0.14
Nodes (19): GCS video-models Bucket, NVIDIA L4 24 GB GPU, RTX PRO 6000 2.24x Break-even, Cloud Run Ephemeral Disk (GA 2026-11-04), Architecture Review Round 1: Agent 1 (Senior Cloud Solutions Architect), Cloud Run RTX PRO 6000 96 GB, Singapore Tier 2 Pricing Correction, Cloud NAT Hidden Cost with Direct VPC (+11 more)

### Community 4 - "Final MVP Pipeline"
Cohesion: 0.12
Nodes (21): GPU job cost formula (04 §15.2), k2-fsa OmniVoice TTS Engine, Final Recommended Architecture (Chief Architect Arbitration), gpu-worker Image (ComfyUI + LTX only), Postgres Job State Machine, Final MVP Architecture, POC Register (POC-0..POC-10), tts-worker CPU Job (+13 more)

### Community 5 - "Decisions & Open Questions"
Cohesion: 0.07
Nodes (36): db/migrations Postgres schema, job_events append-only table, ADR-0002: Backend language (FastAPI vs Node/TS), JSON-Schema-first job contract, pg-boss, Phase 0 gates (licence, TTS, residency, quotas), R-D10 Region europe-west4 unless APAC residency, R-D11 Fallback order (+28 more)

### Community 6 - "Cost Control & Storage"
Cohesion: 0.18
Nodes (10): 0. Detect and plan, 1. Toolchain (macOS commands; adapt for Linux), 2. graphify, 3a. Project plugins (enabled in the committed `.claude/settings.json`), 3b. Project MCP servers (`.mcp.json`, committed), 4. No user-global rules, 5. Logins (the user runs these; Claude never handles credentials), 6. Mark done and report (+2 more)

### Community 7 - "LTX Model & Licensing"
Cohesion: 0.20
Nodes (11): Cloudflare R2 video-output Bucket, Remotion + FFmpeg CPU Rendering, Remotion Company License (Automators), faster-whisper on CPU / Forced Alignment, GCS work Bucket (7-day lifecycle), render-worker FFmpeg CPU Job, Phase 1 Infrastructure Foundation, D6 Rendering Decision (+3 more)

### Community 8 - "plan.md: Autonomous Work Plan"
Cohesion: 0.22
Nodes (8): 0. The team, 1. Protocol: the Lead follows this every iteration, 2. Needs you (the Lead keeps this list current), 3. Task queue, 4. Log (one line per task completion; newest last), Delegation rules, Hard limits (no agent crosses these without the user's explicit "yes" in the current session), plan.md: Autonomous Work Plan

### Community 9 - "backend-dev.md"
Cohesion: 0.33
Nodes (5): Before you start, Done, Engineering standards, Non-negotiable design rules (04-final-architecture), Scope

### Community 10 - "frontend-dev.md"
Cohesion: 0.33
Nodes (5): Before you start, Done, Engineering standards, Product rules (from the spec and the review), Scope

### Community 11 - "devops-deploy.md"
Cohesion: 0.40
Nodes (4): Architecture rules you own, Done, Hard safety rules (also enforced in `infra/CLAUDE.md` and settings), Scope

### Community 12 - "qa-security.md"
Cohesion: 0.50
Nodes (3): Gate procedure (for each task handed to you), Scope, Standing duties (when the lead asks)

### Community 13 - "LTX-2.5 22B Q4"
Cohesion: 0.38
Nodes (7): ComfyUI API, LTX-2.5 22B Q4, Community GGUF Q4_K_M (unsloth), Gemma 4 12B Text Encoder, 16 GiB Host RAM Binding Constraint, LTX-2.x Community License (<$10M revenue), LTX License Item 20 Competing Products Clause

## Ambiguous Edges - Review These
- `PostgreSQL + Video Job Queue` → `Oracle Database Session State`  [AMBIGUOUS]
  system_architecture_technical_specification.md · relation: conceptually_related_to
- `Cloud Run On-Demand/Preemptible GPU Instances` → `Per-Clip Checkpointing + Idempotent Resume`  [AMBIGUOUS]
  system_architecture_technical_specification.md · relation: conceptually_related_to

## Knowledge Gaps
- **53 isolated node(s):** `0. Detect and plan`, `1. Toolchain (macOS commands; adapt for Linux)`, `2. graphify`, `3a. Project plugins (enabled in the committed `.claude/settings.json`)`, `3b. Project MCP servers (`.mcp.json`, committed)` (+48 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `PostgreSQL + Video Job Queue` and `Oracle Database Session State`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Cloud Run On-Demand/Preemptible GPU Instances` and `Per-Clip Checkpointing + Idempotent Resume`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Final Recommended Architecture (Chief Architect Arbitration)` connect `Final MVP Pipeline` to `Original Cloud Run Plan`, `Claude Workflow Skills`, `GPU Options & Fallbacks`, `Decisions & Open Questions`, `LTX Model & Licensing`?**
  _High betweenness centrality (0.308) - this node is a cross-community bridge._
- **Why does `Root README (AI Video Generation Platform)` connect `Claude Workflow Skills` to `Control Plane & Job Contract`, `Decisions & Open Questions`?**
  _High betweenness centrality (0.117) - this node is a cross-community bridge._
- **Why does `services/api backend orchestrator` connect `Decisions & Open Questions` to `Control Plane & Job Contract`, `Final MVP Pipeline`?**
  _High betweenness centrality (0.093) - this node is a cross-community bridge._
- **What connects `0. Detect and plan`, `1. Toolchain (macOS commands; adapt for Linux)`, `2. graphify` to the rest of the system?**
  _53 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Original Cloud Run Plan` be split into smaller, more focused modules?**
  _Cohesion score 0.10227272727272728 - nodes in this community are weakly interconnected._