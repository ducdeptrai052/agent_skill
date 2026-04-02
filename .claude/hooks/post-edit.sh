#!/bin/sh
# .claude/hooks/post-edit.sh
# Triggered by Claude Code after editing a file (PostToolUse: Edit/Write).
# Auto-formats the edited file immediately so the diff stays clean.

set -e

FILE="$1"  # passed as first argument from Claude Code hook

if [ -z "$FILE" ]; then
  exit 0
fi

# Only process TypeScript/JavaScript/JSON/YAML files
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx)
    # Format with Prettier
    npx prettier --write "$FILE" --log-level=warn
    # ESLint auto-fix (safe fixes only)
    npx eslint --fix "$FILE" --quiet 2>/dev/null || true
    ;;
  *.json|*.md|*.yml|*.yaml)
    npx prettier --write "$FILE" --log-level=warn
    ;;
  *.sql)
    # SQL files: normalize whitespace only (no auto-formatter needed)
    ;;
esac

exit 0
