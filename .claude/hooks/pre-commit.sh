#!/bin/sh
# .claude/hooks/pre-commit.sh
# Auto-runs before every commit via Husky + Claude Code hook integration.
# Fails fast: stops at first error.

set -e

echo "🔍 Pre-commit checks starting..."

# ─────────────────────────────────────────
# 1. TypeScript type check (no emit)
# ─────────────────────────────────────────
echo "→ TypeScript check..."
npx tsc --noEmit
echo "  ✓ TypeScript OK"

# ─────────────────────────────────────────
# 2. ESLint on staged files only
# ─────────────────────────────────────────
echo "→ ESLint..."
STAGED_TS=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(ts|tsx)$' || true)
if [ -n "$STAGED_TS" ]; then
  echo "$STAGED_TS" | xargs npx eslint --max-warnings=0
fi
echo "  ✓ ESLint OK"

# ─────────────────────────────────────────
# 3. Prettier format check on staged files
# ─────────────────────────────────────────
echo "→ Prettier..."
STAGED_ALL=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(ts|tsx|json|md|yml|yaml)$' || true)
if [ -n "$STAGED_ALL" ]; then
  echo "$STAGED_ALL" | xargs npx prettier --check
fi
echo "  ✓ Prettier OK"

# ─────────────────────────────────────────
# 4. No secrets check (block obvious leaks)
# ─────────────────────────────────────────
echo "→ Secret scan..."
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR || true)
if [ -n "$STAGED_FILES" ]; then
  SECRET_PATTERNS="(password|secret|api_key|apikey|private_key|access_token|auth_token)\s*=\s*['\"][^'\"]{8,}"
  if echo "$STAGED_FILES" | xargs grep -rniE "$SECRET_PATTERNS" 2>/dev/null | grep -v "\.example" | grep -v "test\|spec\|mock\|fixture"; then
    echo "  ✗ Possible secret found in staged files. Review above and remove before committing."
    exit 1
  fi
fi
echo "  ✓ No secrets found"

# ─────────────────────────────────────────
# 5. Unit tests (fast, no DB)
# ─────────────────────────────────────────
echo "→ Unit tests..."
npx vitest run --reporter=dot --exclude="tests/integration/**"
echo "  ✓ Unit tests passed"

echo ""
echo "✅ All pre-commit checks passed. Proceeding with commit."
