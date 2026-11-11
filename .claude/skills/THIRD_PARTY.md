# Third-party skills: sources and licences

The skills below are vendored copies of upstream projects. Each keeps its own licence. Where a skill folder ships a LICENSE file, that file governs. Project-authored skills (adr, cost-estimate, handoff, poc-record, setup-machine, tts-pronunciation, video-editing-ffmpeg) are not listed.

| Skill | Upstream | Licence | Notes |
|---|---|---|---|
| impeccable | Impeccable v4.8 (engine 0.1.18) | Apache-2.0 | `scripts/bin/` is not vendored. The launcher downloads the verified platform binary using `engine-checksums.txt`. |
| emil-design-eng, apple-design | github.com/emilkowalski/skills | MIT | |
| design-taste-frontend | github.com/Leonxlnx/taste-skill | MIT | |
| gsap-core, gsap-react, gsap-timeline, gsap-performance | github.com/greensock/gsap-skills | MIT | Official GSAP skills |
| ui-styling | claudekit | MIT (see the skill's LICENSE.txt) | |
| ui-ux-pro-max | github.com/nextlevelbuilder/ui-ux-pro-max-skill | MIT | Replaces the ui-ux-pro-max plugin, which was removed to avoid a duplicate |
| find-skills | github.com/vercel-labs/skills | MIT | |
| find-docs | github.com/upstash/context7 | MIT | Modified to use npx only |
| ltx-2-5-prompter | "Hermes Agent" | MIT (per SKILL.md) | |
| animate | the user's FactoryOS project | **not stated** | Copied at the user's request. Confirm reuse rights before relying on it. |

All licences were checked on 2026-11-11 through the GitHub API where an upstream repository is known.
