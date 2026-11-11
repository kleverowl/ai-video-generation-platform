# plan.md: Autonomous Work Plan

> **How to start (on any machine):**
> - Goal mode: `claude`, then type **"Execute plan.md"**.
> - Loop mode: **`/loop 3m continue plan.md`**. For a self-paced loop, use `/loop continue plan.md`.
>
> This file is the work queue. `docs/context/current-state.md` is the status snapshot. Architecture authority is `architecture-review/04-final-architecture.md` plus `docs/adr/`.

---

## 0. The team

The main Claude session is the **Lead**. The Lead plans, assigns, integrates and commits. It writes **no feature code itself** except trivial glue. All specialists are defined in `.claude/agents/` and travel with the repo.

| Agent | Owns | Never touches |
|---|---|---|
| **Lead** (main session) | `plan.md`, `docs/context/`, ADR drafting, research, integration, git commits, the *Needs you* list | — |
| **`frontend-dev`** | `apps/web/**` (Next.js UI + dashboard) | services, workers, infra, db |
| **`backend-dev`** | `services/**`, `db/**`, `packages/job-contract/**`, `workers/*` application code and tests | Dockerfiles, infra, apps/web |
| **`qa-security`** | Tests everywhere, `tests/e2e/**`, security review. **Mandatory gate before every commit.** | Production code (it reports fixes; the owning agent fixes) |
| **`devops-deploy`** | Dockerfiles, `infra/**`, `scripts/**` (POC/bench), CI, runbooks, compose | Application logic, UI |
| `architecture-guard` (reviewer) | Read-only check against 04 and the ADRs | Everything (read-only) |

### Delegation rules
1. **One owner per task.** Use the `Agent` column in §3. Brief the agent with:
   - the task row (ID, task, Done when)
   - the relevant 04/ADR sections
   - any upstream outputs, such as contract files from earlier tasks
2. **Parallel lanes.** Tasks whose deps are all `[x]` and that touch **disjoint folders** run **in parallel**: several `Agent` calls in one message, each with `isolation: "worktree"`. The Lead merges each worktree back.
   - **Same-folder tasks run sequentially.**
   - **Example lanes:** after T-04 is done, T-07, T-09 and T-10 are three backend-dev instances in parallel, and T-13 runs on devops-deploy alongside them.
3. **Gate every task**, in this order:
   1. The owner reports back.
   2. `qa-security` reviews it (**PASS** or **FAIL**).
   3. Changes under `infra/`, `workers/*/Dockerfile` or `services/` orchestration also get an `architecture-guard` review.
   4. On FAIL, send the findings back to the **owning agent**, at most 2 fix rounds. Then mark the task `[!]` with the reason.
4. **Contract changes.** Only `backend-dev` edits `packages/job-contract`. Other agents request changes through the Lead.
5. **Cross-agent hand-offs** (e.g. backend adds an API, frontend consumes it): the Lead sequences them through deps and never lets two agents edit the same file concurrently.

---

## 1. Protocol: the Lead follows this every iteration

1. **Machine check.** If `.claude/.machine-setup-done` is missing, run `/setup-machine` first.
2. **Orient.** Read `docs/context/current-state.md` and §3 below. Use `graphify query "<topic>"` before broad reads.
3. **Pick the ready set.** That is every task in §3 that:
   - has status `[ ]` or `[~]`
   - has all of its **Deps** at `[x]`
   - is not owned by the user

   Resume `[~]` tasks first.
4. **Plan lanes.** Group the ready set into parallel lanes (disjoint folders, see §0 rule 2). In loop mode, start at most **3 lanes** per iteration. Large tasks are split into bounded sub-steps.
5. **Delegate.** Lead-owned tasks are done directly. Every other task is dispatched to its agent, with worktree isolation when it runs in parallel.
6. **Gate.** Run `qa-security` on each returned task, plus `architecture-guard` where required. Loop fixes back to the owner.
7. **Integrate and commit.** For each PASS:
   - merge the worktree
   - re-run the affected tests on the merged tree
   - tick the task (`[x]`)
   - commit locally with a conventional message, e.g. `feat(job-contract): add clip manifest schema (T-04)`

   **Never push. Never commit secrets.**
8. **Record.** Append one line per task to §4 Log: date, task, agent, gate verdict, evidence. Measurements go through `/poc-record`. Decisions go through `/adr` (status `Proposed`).
9. **Blocked?** If a task needs the user, add the item to §2 *Needs you* with exactly what is needed, mark the task `[!]`, and continue with other lanes.
10. **Stop condition.** When no task is ready, run `/handoff`, report the *Needs you* list, and **stop the loop**.

### Hard limits (no agent crosses these without the user's explicit "yes" in the current session)
- No cloud resource creation, deploys or executions. That means no `terraform apply`, no `gcloud … create/deploy/execute`, and no `wrangler … create`.
- No spending money. That includes GPU POC runs and quota requests filed on the user's behalf.
- No emails or messages sent to third parties. Agents **draft**; the user sends.
- No contradicting 04 or an ADR without a `Proposed` ADR first.
- No invented numbers (benchmarks, runtimes, per-video costs).

Status legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked · `[-]` dropped (give a reason).

---

## 2. Needs you (the Lead keeps this list current)

- [ ] **U-1:** Send the licence question to Lightricks. Drafted in T-02.
- [ ] **U-2:** Data residency. Is APAC processing required? The answer sets the region: `europe-west4` vs `asia-southeast1`.
- [ ] **U-3:** Accept or amend the ADRs drafted in T-03 (OQ-1 to OQ-4) and T-05 (backend language).
- [ ] **U-4:** Logins on the new machine: `! gcloud auth login`, `! wrangler login`, `! gh auth login`, `! oci setup config`.
- [ ] **U-5:** Create the GCP projects and billing, and file quota requests. Checklist comes from T-02.
- [ ] **U-6:** Approve spend for the GPU POC runs (T-15). devops-deploy prepares dry-runs first.
- [x] **U-7:** Remote is `https://github.com/kleverowl/ai-video-generation-platform` (public). The plan protocol still says agents **never push**; the user pushes.

---

## 3. Task queue

Gate column: `Q` = qa-security · `A` = architecture-guard.

| ID | Status | Agent | Deps | Gate | Task | Done when |
|---|---|---|---|---|---|---|
| T-01 | [ ] | Lead | — | — | **Machine setup** via `/setup-machine`, including agent-browser (project devDependency + project-scope skill) | Marker file exists; tool table reported |
| T-02 | [ ] | Lead | — | — | **Phase 0 pack** in `docs/phase0/`: (a) draft email to Lightricks on LTX-2.x Attachment A items 19 and 20, for a text-to-video SaaS; (b) TTS-engine shortlist with **verified** weight licences, sources linked; (c) quota-request checklist (Cloud Run L4 + RTX PRO 6000 in both candidate regions, ephemeral-disk per-instance limit, AWS G/VT); (d) GCP project, billing and spend-cap setup steps | Four files exist; every vendor fact has a source URL; U-1 and U-5 updated |
| T-03 | [ ] | Lead | — | — | **Draft ADRs** for OQ-1 (database), OQ-2 (asset storage), OQ-3 (preemptible GPU), OQ-4 (billing data), all with status `Proposed` | ADRs plus rows in `decisions.md`; U-3 listed |
| T-04 | [ ] | backend-dev | — | Q | **Job contract** in `packages/job-contract/`: JSON Schemas (draft 2020-12) for job request, GPU task overrides (clip ranges), clip manifest, done-marker, exit-code classes, model manifest (SHA-256); valid and invalid example fixtures; one-command validation (e.g. `uvx check-jsonschema`) | All fixtures validate or fail as expected via one documented command |
| T-05 | [ ] | backend-dev | — | Q | **ADR-0002 evidence**: hello-world FastAPI vs Node service idle RSS in Docker on arm64, recorded via `/poc-record`. The Lead updates the ADR recommendation (`Proposed`) | POC note plus ADR updated; U-3 updated |
| T-06 | [ ] | backend-dev | T-04 | Q | **DB schema**: plain-SQL migrations for jobs, job_events, quotas, plans, consents, moderation; state-transition enforcement. devops-deploy supplies `docker-compose.dev.yml` (Postgres 16) as T-06b | Migrations apply on compose Postgres; illegal-transition test passes |
| T-06b | [ ] | devops-deploy | — | Q | **Local dev compose**: Postgres 16 plus a fake-GCS emulator option; `.dockerignore`; `make dev` / `make test` entrypoints | `docker compose -f docker-compose.dev.yml up` is healthy |
| T-07 | [ ] | backend-dev | T-04 | Q | **gpu-worker app code** (Python, uv): staging plus manifest verification; clip loop with skip-existing; done-markers; SIGTERM handler; exit codes; `Generator` interface plus a **fake generator** (ffmpeg testsrc) | `pytest` passes, including SIGTERM-resume and skip-existing tests, with no GPU |
| T-08 | [ ] | devops-deploy | T-07 | Q, A | **gpu-worker image**: Dockerfile (CUDA base, pinned ComfyUI and ComfyUI-LTXVideo commits as build args, auto-download disabled); `buildx --platform linux/amd64` | Image builds; size recorded via `/poc-record`; no weights inside |
| T-09 | [ ] | backend-dev | T-04 | Q | **render-worker**: FFmpeg pipeline (concat, ASS captions from an alignment JSON, ducking, two-pass loudnorm, 9:16 and 16:9 presets) plus QA checks (ffprobe, ±1 LU via `ebur128`, black-frame detection), using synthetic inputs | `pytest` passes; qa-security tests caption-text injection |
| T-10 | [ ] | backend-dev | T-04 | Q | **tts-worker skeleton**: engine interface plus a stub engine (silent audio of the correct duration plus a durations JSON) | Tests pass; interface documented |
| T-11 | [ ] | backend-dev | T-05 (accepted), T-06 | Q, A | **Dispatcher + reconciler core** in `services/api/`: `JobRunner` interface, **fake** Cloud Run runner, write-ahead `dispatching` with an idempotency key, reconciler | Chaos tests (by qa-security) pass: crash windows plus reconciler convergence, no duplicates |
| T-12 | [ ] | backend-dev | T-11 | Q | **Quotas, approval gate and live cost estimator** (`/cost-estimate` rates); API endpoints for the UI | Over-quota requests are blocked before dispatch; API tests pass |
| T-13 | [ ] | devops-deploy | U-2 | Q, A | **Terraform skeleton** `infra/terraform/{gcp,cloudflare}` per 04 §1, §10, §16. Variables only, no real IDs. Remote state templated | `terraform fmt -check` and `terraform validate` pass. **No apply** |
| T-14 | [ ] | devops-deploy | T-08, T-13 | Q, A | **POC scripts (dry-run)**: `scripts/poc/poc1_gpu_disk.sh`, `poc2_staging_bench.sh`, `poc3_ltx_matrix.py`, each with `--dry-run` printing commands plus estimated billed seconds × rates | Dry-runs print plans; real runs listed under U-6 |
| T-15 | [ ] | devops-deploy + User | U-5, U-6, T-14 | Q | **Run POC-1 → POC-2 → POC-3** (real spend, each command approved). Results via `/poc-record`; the Lead drafts the R-D2 and R-D4 ADRs | POC records with logs; GPU SKU ADR `Proposed` |
| T-16 | [ ] | frontend-dev | T-05 (accepted), T-12 | Q | **Web app**: submit → narration approval → progress (clips k/n) → download; dashboard (job list, cancel, cost panel *estimate* vs *reconciled* with manual refresh) against the fake runner | Lint, typecheck and unit tests pass; Playwright smoke e2e passes |
| T-17 | [ ] | backend-dev | T-15 | Q, A | **Integrate ComfyUI + LTX** into the gpu-worker `Generator` with the POC-3 winning config | One real clip in the cloud (approved run) |
| T-18 | [ ] | qa-security | T-11, T-16 | — | **Pre-push hardening**: secret scan of the full history (gitleaks), dependency audit, authZ tests (cross-user object access), presigned-URL expiry test | Report in `docs/security/`; all high findings fixed by their owners |

When the queue is exhausted, the Lead re-plans from `architecture-review/05-implementation-roadmap.md` Phases 4–6 and assigns agents using §0. Don't invent scope beyond 04 and the ADRs.

---

## 4. Log (one line per task completion; newest last)

| Date | Task | Agent | Gate | Evidence |
|---|---|---|---|---|
| 2026-11-11 | — | Lead | — | Plan and team created on the Windows machine; repo bootstrapped |
