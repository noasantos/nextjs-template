#!/usr/bin/env bash
# Mirror skills/<name>/SKILL.md → .cursor/skills/<name>/SKILL.md (symlink) for Cursor discovery.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
for d in skills/*/; do
  name="$(basename "$d")"
  [ -f "skills/${name}/SKILL.md" ] || continue
  mkdir -p ".cursor/skills/${name}"
  ln -sf "../../../skills/${name}/SKILL.md" ".cursor/skills/${name}/SKILL.md"
done
