#!/bin/bash
# Remove generated backend files by **filename** (see docs/guides/codegen-cleanup.md).
#
# Never deleted under `modules/`:
# - `profiles/`, `user-access/`, `user-roles/` (hand-maintained; see backend-codegen.md)
#
# Elsewhere: only `*.codegen.*` (actions/hooks) and semantic-plan reset.
#
# If output is wrong, fix `scripts/codegen/` / `packages/codegen-tools/` and re-run
# generators — do not patch `*.codegen.*` by hand.
#
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🧹 Cleaning files matching *.codegen.* ..."
echo ""

echo "📋 Preserved:"
echo -e "${GREEN}  ✓${NC} config/domain-map.json, config/repository-plan.json (local)"
echo -e "${GREEN}  ✓${NC} config/*.example.json"
echo -e "${GREEN}  ✓${NC} packages/supabase-infra/src/types/database.types.ts"
echo -e "${GREEN}  ✓${NC} Manual actions: _shared/, user-access/, user-roles/, profiles/, example/"
echo -e "${GREEN}  ✓${NC} modules/profiles/, user-access/, user-roles/ (skipped by prune)"
echo ""

# Plan-driven module artifacts: `*.dto.codegen.ts` / `*.mapper.codegen.ts` / `*.port.codegen.ts` /
# `*.repository.codegen.ts` (all match `*.codegen.ts`), plus legacy names from older emits.
MODULE_FIND=(
  packages/supabase-data/src/modules
  "(" "!" -path "*/profiles/*" "!" -path "*/user-access/*" "!" -path "*/user-roles/*" ")"
  -type f
  "("
  -name "*.codegen.ts"
  -o -name "*.dto.ts"
  -o -name "*.mapper.ts"
  -o -name "*-repository.port.ts"
  -o -name "*-supabase.repository.ts"
  ")"
)
echo "🗑️  modules … plan-driven dto/mapper/port/repository (*.codegen.ts + legacy names)"
M=$(find "${MODULE_FIND[@]}" 2>/dev/null | wc -l | tr -d "[:space:]")
find "${MODULE_FIND[@]}" -delete 2>/dev/null || true
echo -e "${GREEN}  ✓${NC} $M file(s)"

# Hooks
echo "🗑️  hooks … *.codegen.ts"
H=$(find packages/supabase-data/src/hooks -mindepth 2 -type f -name "*.codegen.ts" 2>/dev/null | wc -l | tr -d "[:space:]")
find packages/supabase-data/src/hooks -mindepth 2 -type f -name "*.codegen.ts" -delete 2>/dev/null || true
echo -e "${GREEN}  ✓${NC} $H file(s)"

# Actions (exclude manual dirs)
echo "🗑️  actions … *.codegen.ts"
A=$(find packages/supabase-data/src/actions -mindepth 2 -type f -name "*.codegen.ts" \
  ! -path "*/_shared/*" ! -path "*/user-access/*" ! -path "*/user-roles/*" \
  ! -path "*/profiles/*" ! -path "*/example/*" 2>/dev/null | wc -l | tr -d "[:space:]")
find packages/supabase-data/src/actions -mindepth 2 -type f -name "*.codegen.ts" \
  ! -path "*/_shared/*" ! -path "*/user-access/*" ! -path "*/user-roles/*" \
  ! -path "*/profiles/*" ! -path "*/example/*" \
  -delete 2>/dev/null || true
echo -e "${GREEN}  ✓${NC} $A file(s)"

# Integration tests (backend emit: *.repository.codegen.integration.test.ts)
# Unit: actions-hooks *.codegen.test.ts; generate-action-tests *.codegen.action.test.ts;
# generate-hook-tests *.hook.codegen.test.tsx — include *.tsx so hook tests are removed.
CODEGEN_TEST_FIND=( \( -name '*.codegen.test.ts' -o -name '*.codegen.*.test.ts' -o -name '*.codegen.test.tsx' -o -name '*.codegen.*.test.tsx' \) )

echo "🗑️  integration tests … *.codegen*.test.ts(x)"
TI=$(find tests/integration/supabase-data/modules -type f "${CODEGEN_TEST_FIND[@]}" 2>/dev/null | wc -l | tr -d "[:space:]")
find tests/integration/supabase-data/modules -type f "${CODEGEN_TEST_FIND[@]}" -delete 2>/dev/null || true
echo -e "${GREEN}  ✓${NC} $TI file(s)"

echo "🗑️  unit tests … *.codegen*.test.ts(x)"
TU=$(find tests/unit/supabase-data -type f "${CODEGEN_TEST_FIND[@]}" 2>/dev/null | wc -l | tr -d "[:space:]")
find tests/unit/supabase-data -type f "${CODEGEN_TEST_FIND[@]}" -delete 2>/dev/null || true
echo -e "${GREEN}  ✓${NC} $TU file(s)"
echo -e "${YELLOW}  Manual tests under tests/unit/codegen etc. preserved${NC}"
echo ""

# Reset semantic plan placeholder
echo "🗑️  Reset config/action-semantic-plan.json …"
if [ -f config/action-semantic-plan.example.json ]; then
  cp config/action-semantic-plan.example.json config/action-semantic-plan.json
  echo -e "${GREEN}  ✓${NC} from action-semantic-plan.example.json"
else
  printf '%s\n' '{"version":1,"generatedAt":"1970-01-01T00:00:00.000Z","actions":[],"meta":{"generator":"codegen-clean","confidence":"high","requiresHumanReview":false}}' > config/action-semantic-plan.json
  echo -e "${GREEN}  ✓${NC} minimal JSON"
fi
echo ""

# Prune empties
PRUNE_BASES=(
  "packages/supabase-data/src/actions"
  "packages/supabase-data/src/hooks"
  "packages/supabase-data/src/modules"
  "tests/unit/supabase-data/actions"
  "tests/unit/supabase-data/hooks"
  "tests/integration/supabase-data/modules"
)
PRUNED=0
for base in "${PRUNE_BASES[@]}"; do
  if [ -d "$base" ]; then
    C=$(find "$base" -mindepth 1 -depth -type d -empty 2>/dev/null | wc -l | tr -d "[:space:]")
    find "$base" -mindepth 1 -depth -type d -empty -delete 2>/dev/null || true
    PRUNED=$((PRUNED + C))
  fi
done
echo -e "${GREEN}  ✓${NC} Pruned $PRUNED empty dir(s)"

if [ ! -f packages/supabase-data/src/modules/.gitkeep ]; then
  touch packages/supabase-data/src/modules/.gitkeep
fi

echo ""
echo -e "${GREEN}✅ codegen:clean done.${NC}"
