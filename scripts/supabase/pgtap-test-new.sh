#!/usr/bin/env bash
# Create a timestamped pgTAP file under supabase/tests/pgtap/ (stable sort order, no hand-picked prefixes).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=guard.sh
source "$SCRIPT_DIR/guard.sh"

while [[ "${1:-}" == "--" ]]; do
  shift
done

if [[ $# -lt 1 ]]; then
  echo "usage: pnpm supabase:pgtap:new -- <descriptive_snake_case_name>" >&2
  echo "example: pnpm supabase:pgtap:new -- profiles_select_own_or_admin" >&2
  exit 1
fi

joined=$(printf '%s_' "$@" | sed 's/_$//')
slug=$(
  printf '%s' "$joined" |
    tr '[:upper:]' '[:lower:]' |
    tr ' -' '__' |
    tr -s '_' '_' |
    tr -cd 'a-z0-9_'
)

if [[ -z "$slug" || "$slug" == "_" ]]; then
  echo "ERROR: invalid name after normalization (use letters, numbers, underscores, hyphens, spaces)." >&2
  exit 1
fi

dir="supabase/tests/pgtap"
ts=$(date -u +%Y%m%d%H%M%S)
path="${dir}/${ts}_${slug}.sql"

mkdir -p "$dir"

if [[ -f "$path" ]]; then
  echo "ERROR: file already exists: $path" >&2
  exit 1
fi

utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Human-readable title line (underscores → spaces) for the SQL comment.
title=$(printf '%s' "$slug" | tr '_' ' ')

cat >"$path" <<EOF
-- test-created-via: pnpm supabase:pgtap:new
-- created-at-utc: ${utc}
--
-- pgTAP: ${title}

begin;
select plan(1);

select ok(
  true,
  'replace this assertion — template only; see supabase/tests/pgtap/examples/minimal_pgtap.sql.example'
);

select * from finish();
rollback;
EOF

echo "$path"
