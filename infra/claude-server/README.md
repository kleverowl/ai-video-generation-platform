# Production-server Claude: video-editing skill bundle

**Goal:** the Claude Code instance on the production server gets the video-editing skills the platform needs, and nothing else. It installs them in **project scope** only: they go into the server project's `.claude/skills/`, never `~/.claude`.

## Bundle (`skills.txt` is the source of truth)

| Skill | Why it's on the server |
|---|---|
| `video-editing-ffmpeg` | assemble, fix and QA final videos (concat, captions, ducking, loudnorm) |
| `ltx-2-5-prompter` | write and repair LTX-2.5 prompts for regeneration |
| `tts-pronunciation` | respell narration for the TTS engine |
| `cost-estimate` | price a regeneration or re-render before running it |
| `poc-record` | record measured runtimes and costs with evidence |
| `find-docs` | current FFmpeg, LTX and Cloud Run docs (via npx ctx7) |

**Optional**, only if an ADR adopts Remotion: install `remotion-dev/skills` on the server from upstream (`npx skills add remotion-dev/skills`, project scope). These are not vendored, because upstream publishes no licence.

**Excluded on purpose:** design and frontend skills, setup-machine, and any DB, backup or AWS MCP servers or skills.

## Install (devops-deploy prepares; the user approves running it on the server)

```bash
scripts/claude-server/install-skills.sh <server-project-dir>            # copies the bundle (project scope)
scripts/claude-server/install-skills.sh <server-project-dir> --dry-run  # prints what would be copied
```

- The script copies only the folders listed in `skills.txt` into `<server-project-dir>/.claude/skills/`. It overwrites older copies and never touches `~/.claude`.
- Run it after each release, so the server's skills match the tagged repo version.

## Security (qa-security gate)

- The server Claude runs with a **least-privilege** OS user:
  - no access to `.env` files beyond what video editing needs
  - no cloud admin credentials
  - no database superuser
- Its `.claude/settings.json` has deny rules for `Read(./.env*)`, `Bash(terraform *)`, `Bash(gcloud * create*)`, `Bash(gcloud * deploy*)` and `Bash(git push*)`.
- Which server hosts it (the Oracle A1 control plane or a separate worker) is an open decision: **U-8** in `plan.md`.
