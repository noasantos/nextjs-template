#!/bin/bash
set -e

echo "🔍 Checking for forbidden patterns..."

FOUND_VIOLATIONS=0

# Check 1: middleware.ts instead of proxy.ts
echo "  ├─ Checking for middleware.ts (should be proxy.ts)"
MIDDLEWARE_FILES=$(find apps -name "middleware.ts" 2>/dev/null || true)
if [ ! -z "$MIDDLEWARE_FILES" ]; then
  echo "  │  ❌ FORBIDDEN: middleware.ts files found (Next.js 16 uses proxy.ts)"
  echo "$MIDDLEWARE_FILES" | while read -r file; do
    echo "  │     - $file"
  done
  FOUND_VIOLATIONS=1
fi

# Check 2: Direct @supabase imports in apps (except @workspace/auth)
echo "  ├─ Checking for direct @supabase imports in apps"
IMPORT_VIOLATIONS=$(rg "from ['\"]@supabase" apps/ --include "*.tsx" --include "*.ts" 2>/dev/null | grep -v "@workspace/auth" || true)
if [ ! -z "$IMPORT_VIOLATIONS" ]; then
  echo "  │  ❌ FORBIDDEN: Direct @supabase imports in apps:"
  echo "$IMPORT_VIOLATIONS" | head -5 | while read -r line; do
    echo "  │     $line"
  done
  FOUND_VIOLATIONS=1
fi

# Check 3: Console.log in product code
echo "  ├─ Checking for console.log in product code"
CONSOLE_VIOLATIONS=$(rg "console\.(log|warn|error|info|debug)" apps/ packages/ --include "*.ts" --include "*.tsx" 2>/dev/null | grep -v "test" | grep -v "node_modules" || true)
if [ ! -z "$CONSOLE_VIOLATIONS" ]; then
  echo "  │  ❌ FORBIDDEN: console.log in product code (use @workspace/logging)"
  echo "$CONSOLE_VIOLATIONS" | head -5 | while read -r line; do
    echo "  │     $line"
  done
  FOUND_VIOLATIONS=1
fi

# Check 4: Throw in Server Actions
echo "  ├─ Checking for throw statements in Server Actions"
THROW_VIOLATIONS=$(rg "throw new Error" apps/ --include "*actions*.ts" 2>/dev/null | grep -v "test" || true)
if [ ! -z "$THROW_VIOLATIONS" ]; then
  echo "  │  ❌ FORBIDDEN: Throw statements in Server Actions (use Result pattern)"
  echo "$THROW_VIOLATIONS" | head -3 | while read -r line; do
    echo "  │     $line"
  done
  FOUND_VIOLATIONS=1
fi

# Summary
echo ""
if [ $FOUND_VIOLATIONS -eq 1 ]; then
  echo "❌ Forbidden patterns detected! Please fix violations before committing."
  echo ""
  echo "See docs/standards/golden-rules.md for details."
  exit 1
else
  echo "✅ No forbidden patterns found!"
  exit 0
fi
