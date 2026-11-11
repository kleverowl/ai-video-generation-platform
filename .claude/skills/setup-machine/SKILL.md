---
name: setup-machine
description: One-time setup of a new development machine (macOS primarily; Linux/Windows best-effort) for this repo. Installs the toolchain (gcloud, Cloudflare wrangler, terraform, docker, node, python/uv, graphify), installs the project plugins, wires graphify and git hooks, and checks project MCP servers. Use when the SessionStart hook says the machine is not set up, or the user says "set up this machine", "bootstrap", or "install prerequisites".
---

# One-time machine setup

The goal is a machine that matches the project's standard tooling.

**Ground rules:**
- **Idempotent.** Check each tool first and skip anything already present.
- **Ask once** for approval of the whole install list. Then proceed without asking per tool.
- **Never handle credentials.** Logins are run by the user (see §5).
- **Never create cloud resources** (see `infra/CLAUDE.md`).
- **Project scope only.**
  - All Claude configuration (skills, plugins, MCP servers, rules, hooks, settings) lives in this repo: `.claude/`, `.mcp.json`, `CLAUDE.md`. Never write to `~/.claude/` or `~/.claude.json`.
  - **The one exception is graphify.** Its CLI and its `/graphify` skill may be installed globally (user-approved).
  - Node CLIs install as **project devDependencies** in the root `package.json` and run via `npx`. Never use `npm -g`.
  - Only OS-level binaries that cannot be project-scoped are installed machine-wide (Homebrew packages, gcloud, Docker, the graphify CLI binary). Their *configuration* still stays in the repo.

## 0. Detect and plan
- OS and architecture: `uname -sm` (Darwin arm64 means an Apple silicon Mac).
- For every tool in §1, record its version or "missing". Show the user one table (tool | status | install command) and get one approval.

## 1. Toolchain (macOS commands; adapt for Linux)

**Prerequisites:**
- Homebrew. If missing, install it from the official command at https://brew.sh. Show the command and let the user run it, because it needs sudo.
- Xcode Command Line Tools. Check with `xcode-select -p`; if missing, run `xcode-select --install`.

| Tool | Why | Install (macOS) | Verify |
|---|---|---|---|
| git | VCS | Xcode CLT (or `brew install git`) | `git --version` |
| gh | GitHub CLI (repos, PRs) | `brew install gh` | `gh --version` |
| python 3.12 | workers, graphify | `brew install python@3.12` | `python3 --version` (≥3.10) |
| uv | Python tool and venv manager | `brew install uv` | `uv --version` |
| node 22 LTS + npm | web app, ctx7, wrangler, gcloud MCP | `brew install node@22`, then `brew link --overwrite node@22` | `node -v` (≥20) |
| **gcloud CLI** | Cloud Run, GCS, Artifact Registry | Official archive. Apple silicon: `curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-arm.tar.gz && tar -xf google-cloud-cli-darwin-arm.tar.gz -C "$HOME" && "$HOME/google-cloud-sdk/install.sh" --quiet --path-update true --command-completion true`. Intel Macs use `…-darwin-x86_64.tar.gz`. Source: https://docs.cloud.google.com/sdk/docs/install-sdk | `gcloud --version` (new shell) |
| gcloud components | beta/alpha commands used by Cloud Run GPU jobs | `gcloud components install beta --quiet` | `gcloud beta --help` |
| **wrangler** (Cloudflare CLI) | R2 buckets, tokens, DNS | **Project-local** (Cloudflare's recommendation): `npm i -D wrangler@latest` in the repo root. If there is no root `package.json`, first create a tooling-only one: `{"name":"vidgen-tooling","private":true}`. | `npx wrangler --version` |
| terraform | infra/terraform | `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` | `terraform -version` |
| Docker | build worker images | Docker Desktop (`brew install --cask docker`), or OrbStack. Ask which the user prefers. | `docker version`, `docker buildx version` |
| ffmpeg | local render-worker tests | `brew install ffmpeg` | `ffmpeg -version` |
| psql (libpq) | Postgres client for the Oracle DB | `brew install libpq && brew link --force libpq` | `psql --version` |
| jq | JSON on the CLI | `brew install jq` | `jq --version` |
| oci CLI | manage the Oracle Always Free VM | `brew install oci-cli` | `oci --version` |
| aws CLI (optional) | only for fallback #4 quota requests | `brew install awscli` | `aws --version` |
| **agent-browser** (Vercel Labs, Apache-2.0) | browser automation for agents: reads pages as an accessibility tree. Used by frontend-dev and qa-security for UI checks and e2e smoke tests | **Project-local:** `npm i -D agent-browser` in the repo root, then `npx agent-browser install` (downloads Chrome for Testing; first time only). Source: https://github.com/vercel-labs/agent-browser | `npx agent-browser --version` |

After both installs, commit `package.json` and `package-lock.json` (`chore(tooling): add wrangler and agent-browser devDependencies`). `node_modules/` is already git-ignored.

**agent-browser skill (project scope):**
1. Run `npx skills add vercel-labs/agent-browser`. When asked, choose **Claude Code** and **project scope**. The skill must land in this repo's `.claude/skills/`, never in `~/.claude/skills/`.
2. Verify with `git status`: the new skill folder should appear under `.claude/skills/`. Commit it with `chore(skills): add agent-browser skill (project scope)`.
3. The installed skill is a stub. Before first use, the agent runs `npx agent-browser skills get core`, so its instructions match the installed CLI version.
4. Add `.claude/skills/agent-browser/` to `.graphifyignore`, because it is third-party skill content.

**Apple silicon note:** Cloud Run needs **linux/amd64** images. Always build with `docker buildx build --platform linux/amd64 …`. Add this as a line to `workers/CLAUDE.md` the first time an image is built on this machine.

## 2. graphify
1. Install if missing: `uv tool install graphifyy` (the PyPI name has a double y). Fallbacks: `pipx install graphifyy` or `python3 -m pip install --user graphifyy`.
2. Global skill, so `/graphify` works in every project: `graphify install --platform claude`. This writes to `~/.claude/skills/graphify`. graphify is the **one allowed global exception**, approved by the user.
3. Project integration: `graphify claude install`. Then **undo its side effects on shared files**:
   - `git checkout -- CLAUDE.md`. The committed graphify section is already condensed, and the root CLAUDE.md must stay minimal.
   - Move its machine-specific PreToolUse hooks into the git-ignored local settings:
     ```bash
     python3 - <<'EOF'
     import json, pathlib
     shared = pathlib.Path(".claude/settings.json"); local = pathlib.Path(".claude/settings.local.json")
     s = json.loads(shared.read_text()); l = json.loads(local.read_text()) if local.exists() else {}
     pre = s.get("hooks", {}).pop("PreToolUse", None)
     if pre: l.setdefault("hooks", {})["PreToolUse"] = pre
     shared.write_text(json.dumps(s, indent=2) + "\n"); local.write_text(json.dumps(l, indent=2) + "\n")
     EOF
     git diff --stat .claude/settings.json   # must show no change vs the committed file
     ```
4. Git hooks and the graph merge driver (these live in `.git/`, so they are not cloned): `graphify hook install`.
5. Refresh the committed graph: `graphify update .`. This is AST-only and makes no LLM calls. If `graphify-out/graph.json` is missing, run `/graphify .` instead.
6. Verify: `graphify query "GPU worker staging" --budget 300` returns nodes.

## 3a. Project plugins (enabled in the committed `.claude/settings.json`)

Enabling a plugin in project settings does **not** download it, so each machine installs it once. For each plugin missing from `claude plugin list`, run:

```bash
for p in context7 feature-dev frontend-design typescript-lsp pyright-lsp chrome-devtools-mcp \
         playwright security-guidance code-simplifier terraform cloudflare; do
  claude plugin install "$p@claude-plugins-official" --scope project
done
# the ui-ux-pro-max marketplace is registered by the project's extraKnownMarketplaces (after you trust the folder)
claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill --scope project
```

Then ask the user to run `/reload-plugins`, or to restart the session.

| Plugin | Used by |
|---|---|
| context7 | everyone: current library docs |
| feature-dev | Lead: architect, explorer and reviewer agents |
| frontend-design, ui-ux-pro-max | frontend-dev |
| typescript-lsp, pyright-lsp | frontend-dev, backend-dev: code intelligence for TS and Python |
| chrome-devtools-mcp, playwright | frontend-dev, qa-security: browser e2e, Lighthouse, a11y |
| security-guidance | qa-security: warns on risky edits |
| code-simplifier | Lead: cleanup pass |
| terraform | devops-deploy: Terraform registry and docs MCP |
| cloudflare | devops-deploy: Cloudflare skills plus the **Cloudflare API MCP** (`mcp.cloudflare.com`, OAuth) |

**Deliberately not carried** (unrelated to this project): laravel-boost, divi, android-cli, n8n, firebase, figma, postman. Also any user-level MCP servers from the original machine (MySQL/DB servers, kspl-backups, google-analytics, aws-mcp). **Never add to this repo or this machine's project config:** MySQL/DB MCP servers, `kspl-backups` (MCP or skill), `aws-mcp`, or the AWS skill set. The optional `aws` CLI in §1 is the only AWS tool, and it is used only for fallback-#4 quota requests.

Built-in skills that come with Claude Code itself: before any push, the Lead runs `/code-review` and `/security-review`.

## 3b. Project MCP servers (`.mcp.json`, committed)

| Server | What | Notes |
|---|---|---|
| `cloudflare-docs` | Cloudflare documentation search | Remote. The Cloudflare API MCP comes from the `cloudflare` plugin above. |
| `gcloud` | Runs gcloud via MCP (`@google-cloud/gcloud-mcp`) | **Preview and not an officially supported Google product.** Needs gcloud installed and logged in, plus node ≥20. It acts with the active gcloud account's permissions. |

- Claude Code asks for approval the first time it sees each project server. Tell the user to approve them.
- The gcloud MCP uses the user's gcloud permissions. Remind the user that `infra/CLAUDE.md` forbids resource-creating commands unless explicitly requested.
- Verify with `claude mcp list` (user runs `! claude mcp list`).
## 4. No user-global rules
Do **not** edit `~/.claude/CLAUDE.md` or `~/.claude/rules/`. The repo already covers what the original machine kept globally:
- the graphify rules are in the root `CLAUDE.md`
- Context7 docs lookups come from the project `/find-docs` skill and the `context7` plugin

## 5. Logins (the user runs these; Claude never handles credentials)
Ask the user to run each one in the prompt with the `!` prefix:
- `! gcloud auth login` and `! gcloud auth application-default login`
- `! gcloud config set project <dev-project-id>` (after Phase 0 creates the project)
- `! wrangler login`
- `! gh auth login`
- `! oci setup config` (Oracle API key)
- Cloudflare MCP: OAuth happens automatically on first tool use.

## 6. Mark done and report
1. Write `.claude/.machine-setup-done` (git-ignored) containing the date, OS/arch, and the version table. From then on, the SessionStart hook stays silent.
2. Report a table of tool | status (present / installed / skipped / needs login).
3. Read `docs/context/current-state.md` and state the single next action.

## Never
- Commit `.claude/settings.local.json`, `.claude/.machine-setup-done`, `.env`, or any credentials.
- Write anything to `~/.claude/`, `~/.claude.json`, or global npm. Every Claude skill, plugin, MCP server and rule is project-scoped. The only exception is the global graphify skill and CLI.
- Run `terraform apply`, `gcloud … create/deploy`, or `wrangler r2 bucket create` during setup.
