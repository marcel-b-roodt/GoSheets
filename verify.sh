#!/usr/bin/env bash
# verify.sh — Run GDScript syntax and lint checks on all addon and test files.
#
# Usage:
#   ./verify.sh
#
# Requires gdtoolkit:
#   pip install gdtoolkit        # Ubuntu / macOS
#   pip install --break-system-packages gdtoolkit   # Arch Linux

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

# Collect all .gd files under addons/ and tests/ (excludes gdUnit4 itself)
mapfile -t GD_FILES < <(
	find addons tests test_scenes \
		-name "*.gd" \
		-not -path "*/gdUnit4/*" \
		2>/dev/null | sort
)

FILE_COUNT="${#GD_FILES[@]}"

if [[ "$FILE_COUNT" -eq 0 ]]; then
	echo "Nothing to verify — no GDScript files found."
	exit 0
fi

echo "GoSheets — verify.sh"
echo "Checking $FILE_COUNT GDScript file(s)..."
echo "────────────────────────────────────────"

# ── Syntax check ─────────────────────────────────────────────────────────────
SYNTAX_ERRORS=0
for f in "${GD_FILES[@]}"; do
	if ! gdparse "$f" > /dev/null 2>&1; then
		echo "  FAIL (syntax): $f"
		gdparse "$f" 2>&1 | sed 's/^/    /'
		SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
	fi
done

if [[ "$SYNTAX_ERRORS" -gt 0 ]]; then
	echo ""
	echo "✗ Syntax errors found in $SYNTAX_ERRORS file(s). Fix before committing."
	exit 1
fi

echo "  ✓ All files parsed OK."

# ── Lint check ────────────────────────────────────────────────────────────────
LINT_ERRORS=0
for f in "${GD_FILES[@]}"; do
	if ! gdlint "$f" > /dev/null 2>&1; then
		echo "  FAIL (lint): $f"
		gdlint "$f" 2>&1 | sed 's/^/    /'
		LINT_ERRORS=$((LINT_ERRORS + 1))
	fi
done

if [[ "$LINT_ERRORS" -gt 0 ]]; then
	echo ""
	echo "✗ Lint violations found in $LINT_ERRORS file(s). Fix before committing."
	exit 1
fi

echo "  ✓ All files lint-clean."
echo "────────────────────────────────────────"
echo "✓ Verification passed — safe to commit."
