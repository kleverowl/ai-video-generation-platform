#!/usr/bin/env bash
# Readiness gate: everything must be installed before any coding task starts.
# Exit 0 only if every REQUIRED check passes. Run from anywhere inside the repo.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
fail=0; warn=0
ok()   { printf "  PASS  %s\n" "$1"; }
bad()  { printf "  FAIL  %s  -> %s\n" "$1" "$2"; fail=$((fail+1)); }
opt()  { printf "  WARN  %s  -> %s\n" "$1" "$2"; warn=$((warn+1)); }
have() { command -v "$1" >/dev/null 2>&1; }
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }  # ver_ge actual min

echo "== Toolchain"
for t in git gh uv terraform docker ffmpeg ffprobe psql jq oci gcloud graphify claude; do
  if have "$t"; then ok "$t"; else bad "$t" "run /setup-machine §1"; fi
done
if have python3 && ver_ge "$(python3 -c 'import platform;print(platform.python_version())')" 3.10; then ok "python3 >= 3.10"; else bad "python3 >= 3.10" "brew install python@3.12"; fi
if have node && ver_ge "$(node -p 'process.versions.node')" 22.0.0; then ok "node >= 22 (taste-skill needs 22+)"; else bad "node >= 22" "brew install node@22"; fi
if have docker && docker buildx version >/dev/null 2>&1; then ok "docker buildx"; else bad "docker buildx" "install Docker Desktop/OrbStack"; fi
if [ "$(uname -s)" = "Darwin" ]; then
  if [ -d "/Applications/Google Chrome.app" ] || [ -d "/Applications/Microsoft Edge.app" ]; then ok "Chrome/Edge (taste-skill inspector)"; else bad "Chrome/Edge" "brew install --cask google-chrome"; fi
fi
have aws && ok "aws CLI (optional)" || opt "aws CLI" "optional; fallback #4 only"

echo "== Project-local Node tools"
for p in wrangler agent-browser; do
  if [ -x "node_modules/.bin/$p" ]; then ok "$p (devDependency)"; else bad "$p" "npm i -D $p (repo root)"; fi
done
if [ -x node_modules/.bin/agent-browser ] && npx --no-install agent-browser --version >/dev/null 2>&1; then ok "agent-browser runs"; else bad "agent-browser runs" "npx agent-browser install"; fi

echo "== Skills (project scope)"
for s in adr cost-estimate handoff poc-record setup-machine tts-pronunciation video-editing-ffmpeg ltx-2-5-prompter find-docs \
         impeccable emil-design-eng design-taste-frontend apple-design ui-styling ui-ux-pro-max animate find-skills \
         gsap-core gsap-react gsap-timeline gsap-performance agent-browser; do
  if [ -s ".claude/skills/$s/SKILL.md" ]; then ok "skill $s"; else bad "skill $s" "missing .claude/skills/$s (agent-browser: npx skills add vercel-labs/agent-browser, project scope)"; fi
done
if sh .claude/skills/impeccable/scripts/impeccable engine-probe >/dev/null 2>&1; then ok "impeccable engine binary"; else bad "impeccable engine" "run: sh .claude/skills/impeccable/scripts/impeccable engine-probe (downloads verified binary)"; fi

echo "== Plugins (project scope)"
if have claude; then
  plist=$(claude plugin list 2>/dev/null || true)
  for p in context7 feature-dev frontend-design typescript-lsp pyright-lsp chrome-devtools-mcp playwright security-guidance code-simplifier terraform cloudflare; do
    if printf '%s' "$plist" | grep -q "$p"; then ok "plugin $p"; else bad "plugin $p" "claude plugin install $p@claude-plugins-official --scope project"; fi
  done
fi

echo "== graphify wiring"
grep -q graphify .git/hooks/post-commit 2>/dev/null && ok "git hooks" || bad "graphify git hooks" "graphify hook install"
grep -q hook-guard .claude/settings.local.json 2>/dev/null && ok "Claude hooks (local)" || bad "graphify Claude hooks" "graphify claude install + move hooks to settings.local.json"
[ -s graphify-out/graph.json ] && ok "graph.json" || bad "graph.json" "graphify update ."
[ -d "$HOME/.claude/skills/graphify" ] && ok "/graphify skill (global, allowed)" || bad "/graphify skill" "graphify install --platform claude"

echo "== Safety"
git diff --quiet -- .claude/settings.json && ok "shared settings unchanged" || bad "shared .claude/settings.json modified" "move machine-specific hooks to settings.local.json"
grep -rqE "mysql|kspl-backups|aws-mcp" .mcp.json && bad ".mcp.json" "remove forbidden MCP servers" || ok ".mcp.json has no forbidden servers"

echo
if [ "$fail" -eq 0 ]; then echo "READY: all required checks passed ($warn warnings)."; exit 0
else echo "NOT READY: $fail required check(s) failed. Fix them with /setup-machine before any coding."; exit 1; fi
