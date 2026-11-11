# Dormant skills

Claude Code does **not** load skills from this folder. Only `.claude/skills/` is loaded.

## Remotion (not vendored)

The MVP renders with **FFmpeg only** (decision R-D6). If an ADR later adopts Remotion, install Remotion's official skills at that point, in **project scope**:

```bash
npx skills add remotion-dev/skills
```

When prompted, choose Claude Code and project scope. Resolve the Remotion licence tier first: more than 3 employees requires a paid licence.

Remotion's skills are **not vendored** in this public repo because upstream `remotion-dev/skills` publishes no licence.
