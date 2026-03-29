#!/usr/bin/env bash
# Repo root + Supabase CLI wrapper for scripts under scripts/supabase/
# shellcheck disable=SC2034
_GUARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_GUARD_DIR/../.." && pwd)"

cd "$REPO_ROOT" || {
  echo "guard: could not cd to repo root: $REPO_ROOT" >&2
  return 1 2>/dev/null || exit 1
}

supabase_cli() {
  pnpm exec supabase "$@"
}

# Prepend the standard migration header (migration-created-via + created-at-utc).
# Idempotent: if the first line already contains migration-created-via, no-op.
stamp_migration_header() {
  local path="$1"
  if [[ -z "$path" || ! -f "$path" ]]; then
    echo "stamp_migration_header: not a file: ${path:-<empty>}" >&2
    return 1
  fi
  if head -n 1 "$path" | grep -q "migration-created-via"; then
    if [[ "${MIGRATION_QUIET:-}" != "1" ]]; then
      echo "Stamp already present: $path"
    fi
    return 0
  fi
  local tmp_file
  tmp_file="$(mktemp)"
  {
    echo "-- migration-created-via: pnpm supabase:migration:new"
    echo "-- created-at-utc: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo
    cat "$path"
  } > "$tmp_file"
  mv "$tmp_file" "$path"
  if [[ "${MIGRATION_QUIET:-}" != "1" ]]; then
    echo "Stamped migration file: $path"
  fi
}
