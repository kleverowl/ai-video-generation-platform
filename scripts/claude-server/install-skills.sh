#!/usr/bin/env sh
# Copy the production-server Claude skill bundle into a target project's .claude/skills (project scope only).
# Usage: install-skills.sh <target-project-dir> [--dry-run]
set -eu
REPO=$(cd "$(dirname "$0")/../.." && pwd)
TARGET=${1:?usage: install-skills.sh <target-project-dir> [--dry-run]}
DRY=${2:-}
LIST="$REPO/infra/claude-server/skills.txt"
DEST="$TARGET/.claude/skills"
case "$DEST" in "$HOME/.claude"*) echo "refusing: target must be a project, not ~/.claude" >&2; exit 2;; esac
[ "$DRY" = "--dry-run" ] || mkdir -p "$DEST"
grep -v -E '^\s*(#|$)' "$LIST" | while IFS= read -r s; do
  src="$REPO/.claude/skills/$s"
  [ -f "$src/SKILL.md" ] || { echo "missing skill: $s" >&2; exit 1; }
  if [ "$DRY" = "--dry-run" ]; then echo "would copy $s -> $DEST/$s"
  else rm -rf "${DEST:?}/$s"; cp -R "$src" "$DEST/$s"; echo "installed $s"; fi
done
