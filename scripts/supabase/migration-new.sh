#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=guard.sh
source "$SCRIPT_DIR/guard.sh"

while [[ "${1:-}" == "--" ]]; do
  shift
done

if [[ $# -lt 1 ]]; then
  echo "usage: pnpm supabase:migration:new -- <name>" >&2
  exit 1
fi

before_file="$(mktemp)"
after_file="$(mktemp)"
cleanup() {
  rm -f "$before_file" "$after_file"
}
trap cleanup EXIT

find supabase/migrations -maxdepth 1 -name "*.sql" -print 2>/dev/null | LC_ALL=C sort > "$before_file" || true

# Never wrap `supabase migration new` in $(...). Command substitution attaches a pipe to
# stdout; some CLI versions buffer or never close it, so bash waits forever for EOF.
# stdin is /dev/null so non-TTY runs (CI/agents) never block waiting for interactive input.
# stdout is discarded so agents/humans get one line from this script (the path), not duplicate CLI banners.
if ! supabase_cli migration new "$@" </dev/null >/dev/null; then
  echo "ERROR: supabase migration new failed." >&2
  exit 1
fi

find supabase/migrations -maxdepth 1 -name "*.sql" -print 2>/dev/null | LC_ALL=C sort > "$after_file" || true

new_path=""
new_count=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  new_path="$line"
  new_count=$((new_count + 1))
done < <(comm -13 "$before_file" "$after_file")

if [[ "$new_count" -eq 0 || -z "$new_path" ]]; then
  echo "ERROR: could not locate newly created migration file (before/after diff empty)." >&2
  exit 1
fi

if [[ "$new_count" -gt 1 ]]; then
  echo "ERROR: expected exactly one new migration file; comm found $new_count:" >&2
  comm -13 "$before_file" "$after_file" >&2
  exit 1
fi

if [[ ! -f "$new_path" ]]; then
  echo "ERROR: migration path is not a file: $new_path" >&2
  exit 1
fi

MIGRATION_QUIET=1 stamp_migration_header "$new_path"
echo "$new_path"
