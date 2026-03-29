#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=guard.sh
source "$SCRIPT_DIR/guard.sh"

while [[ "${1:-}" == "--" ]]; do
  shift
done

if [[ $# -lt 1 ]]; then
  echo "usage: pnpm supabase:migration:stamp -- <path-to-migration.sql>" >&2
  exit 1
fi

stamp_migration_header "$1"
