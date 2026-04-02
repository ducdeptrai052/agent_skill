#!/bin/sh
# .claude/hooks/pre-push.sh
# Runs before git push. Heavier checks than pre-commit.
# Runs full test suite including integration tests.

set -e

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
TARGET_BRANCH="$2"  # remote branch being pushed to

echo "🚀 Pre-push checks for branch: $CURRENT_BRANCH"

# ─────────────────────────────────────────
# Block force-push to main/develop
# ─────────────────────────────────────────
if echo "$TARGET_BRANCH" | grep -qE "^(main|master|develop)$"; then
  while read local_ref local_sha remote_ref remote_sha; do
    if [ "$local_sha" = "0000000000000000000000000000000000000000" ]; then
      continue  # deleting branch, skip
    fi
    # Check if this is a force push (remote has commits not in local)
    if [ "$remote_sha" != "0000000000000000000000000000000000000000" ]; then
      if ! git merge-base --is-ancestor "$remote_sha" "$local_sha" 2>/dev/null; then
        echo "✗ Force push to $TARGET_BRANCH is not allowed."
        echo "  Use 'git revert' to undo changes on protected branches."
        exit 1
      fi
    fi
  done
fi

# ─────────────────────────────────────────
# Full test suite (unit + integration)
# ─────────────────────────────────────────
echo "→ Full test suite..."
npx vitest run --reporter=verbose
echo "  ✓ All tests passed"

# ─────────────────────────────────────────
# Coverage check (must meet thresholds)
# ─────────────────────────────────────────
echo "→ Coverage check..."
npx vitest run --coverage --reporter=dot
echo "  ✓ Coverage thresholds met"

# ─────────────────────────────────────────
# Build check (ensure dist compiles clean)
# ─────────────────────────────────────────
echo "→ Build check..."
npm run build
echo "  ✓ Build successful"

echo ""
echo "✅ All pre-push checks passed."
