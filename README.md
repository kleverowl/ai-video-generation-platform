# AI Video Generation Platform

A low-cost AI video generation platform (Reels, YouTube, custom formats). It rents GPUs only while a job runs.

**Status:** pre-code. The architecture has been reviewed; Phase 0 (licence and quota gates) is next.

| Start here | |
|---|---|
| Current state and next actions | `docs/context/current-state.md` |
| Architecture (authoritative) | `architecture-review/04-final-architecture.md` |
| Roadmap and POC register | `architecture-review/05-implementation-roadmap.md` |
| Open questions (spec vs review) | `docs/context/open-questions.md` |
| Decisions | `docs/context/decisions.md`, `docs/adr/` |

## Layout

```
apps/web/              Next.js UI + dashboard (Oracle A1, arm64)
services/api/          API, auth, quotas, dispatcher, reconciler
workers/gpu-worker/    Cloud Run GPU job: ComfyUI + LTX-2.5
workers/tts-worker/    Cloud Run CPU job: narration
workers/render-worker/ Cloud Run CPU job: FFmpeg assembly → R2
packages/job-contract/ JSON Schemas shared by API and workers
infra/                 Terraform (GCP, Cloudflare), Oracle VM setup
db/migrations/         Postgres schema
docs/                  context/, adr/, poc/, runbooks/
architecture-review/   Architecture review deliverables (01–06)
```

## Claude Code setup

**Context files.** The root `CLAUDE.md` is kept minimal. Each of `workers/`, `services/` and `infra/` has its own `CLAUDE.md`, which loads only when Claude works in that folder.

**Project skills:**

| Skill | Purpose |
|---|---|
| `/handoff` | Updates the context files at the end of a session |
| `/adr` | Records an architecture decision |
| `/poc-record` | Records benchmark evidence |
| `/cost-estimate` | Estimates job cost from verified rates |

**Skills carried over from the earlier video project:**

| Skill | Purpose |
|---|---|
| `/ltx-2-5-prompter` | LTX-2.5 prompt writing |
| `/tts-pronunciation` | Respelling Indian names for TTS |
| `/find-docs` | Current docs via Context7 |

**Remotion** skills are not vendored. See `.claude/skills-dormant/README.md` for how to install them if an ADR adopts Remotion.

**Plugins** are enabled in `.claude/settings.json`. `/setup-machine` installs them on each new machine.

**Agent team** (`.claude/agents/`). The main session is the Lead: it assigns work and commits. Ownership and gates are set out in `plan.md` §0.

| Agent | Role |
|---|---|
| `frontend-dev` | `apps/web` |
| `backend-dev` | API, database, job contract, worker code |
| `qa-security` | Tests and security; must approve before every commit |
| `devops-deploy` | Docker, Terraform, scripts, CI; dry-runs first |
| `architecture-guard` | Read-only architecture review |

**graphify:** builds a knowledge graph in `graphify-out/`, which is committed. Its git hooks rebuild the graph on commit. Its Claude Code hooks live in `.claude/settings.local.json`, which is per machine.

## New machine (e.g. a second laptop)

1. `git clone <repo> && cd <repo> && claude`
2. On the first session, a SessionStart hook detects that the machine has not been set up and tells Claude to run **`/setup-machine`**. That skill:
   - installs graphify if missing
   - wires its skill and hooks
   - installs the git hooks
   - refreshes the graph
   - checks python, node and git
   - offers optional gcloud/terraform installs
3. When it finishes, it writes `.claude/.machine-setup-done` (git-ignored), and the hook stays silent from then on.
