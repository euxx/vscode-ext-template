#!/bin/bash
# Tests for scripts/sync.sh
# Usage: ./scripts/test-sync.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SYNC_SH="$SCRIPT_DIR/sync.sh"

pass=0
fail=0
failed_tests=()

ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
fail() { echo "  ✗ $1"; fail=$((fail+1)); failed_tests+=("$1"); }

assert_contains()     { grep -qF "$3" "$2" 2>/dev/null && ok "$1" || fail "$1 — '$3' not found in $2"; }
assert_not_contains() { [ -f "$2" ] && ! grep -qF "$3" "$2" && ok "$1" || fail "$1 — '$3' should not be in $2"; }
assert_files_equal()  { diff -q "$2" "$3" > /dev/null 2>&1 && ok "$1" || fail "$1 — $2 and $3 differ"; }

TMPDIRS=()
cleanup() {
  for d in "${TMPDIRS[@]+"${TMPDIRS[@]}"}"; do rm -rf "$d"; done
}
trap cleanup EXIT

# Run sync.sh with all prompts answered 'y'
sync_yes() { yes y 2>/dev/null | bash "$SYNC_SH" "$1" 2>&1 || true; }
# Run sync.sh with all prompts answered 'n'
sync_no()  { yes n 2>/dev/null | bash "$SYNC_SH" "$1" 2>&1 || true; }

# Creates a temp dir, stores path in $dir, and registers for cleanup.
# Avoids $() subshell so TMPDIRS is updated in the parent shell.
mktest() { dir=$(mktemp -d); TMPDIRS+=("$dir"); }

echo "=== sync.sh tests ==="
echo ""

# ── 1. No-marker file: copies whole content ────────────────────────────────────
echo "1. No-marker file syncs completely"
mktest
echo "old AGENTS content" > "$dir/AGENTS.md"
sync_yes "$dir" > /dev/null
assert_files_equal "AGENTS.md matches template" "$TEMPLATE_DIR/AGENTS.md" "$dir/AGENTS.md"
echo ""

# ── 2. Up-to-date file: shows OK ───────────────────────────────────────────────
echo "2. Up-to-date file shows OK"
mktest
cp "$TEMPLATE_DIR/AGENTS.md" "$dir/AGENTS.md"
output=$(sync_yes "$dir")
[[ "$output" == *"[ OK   ] AGENTS.md"* ]] && ok "Shows [ OK ]" || fail "Expected [ OK ] for up-to-date file"
echo ""

# ── 3. Declining prompt: file unchanged ────────────────────────────────────────
echo "3. Declining prompt leaves file unchanged"
mktest
echo "original content" > "$dir/AGENTS.md"
sync_no "$dir" > /dev/null
assert_contains "File unchanged after 'n'" "$dir/AGENTS.md" "original content"
echo ""

# ── 4. Marker file: shared section updated, project section preserved ──────────
echo "4. Marker file: project section preserved after sync"
MARKER="<!-- END-SHARED -->"
mktest

# Build target: corrupted shared section + marker + project-specific section
shared=$(awk '{print} index($0, "<!-- END-SHARED -->"){exit}' "$TEMPLATE_DIR/DEVELOPMENT.md")
{ echo "$shared" | sed 's/npm run ci/npm run ci-STALE/'; printf '\n## Project Notes\n\nproject-specific text here\n'; } > "$dir/DEVELOPMENT.md"

assert_contains "Target has corrupted shared line before sync" "$dir/DEVELOPMENT.md" "ci-STALE"
assert_contains "Target has project section before sync" "$dir/DEVELOPMENT.md" "project-specific text"

sync_yes "$dir" > /dev/null

assert_not_contains "Stale line removed by sync" "$dir/DEVELOPMENT.md" "ci-STALE"
assert_contains     "Shared content restored" "$dir/DEVELOPMENT.md" "npm run ci"
assert_contains     "Project section preserved" "$dir/DEVELOPMENT.md" "project-specific text"
assert_contains     "Marker still present" "$dir/DEVELOPMENT.md" "$MARKER"
echo ""

# ── 5. Marker file: target has no marker yet — gets full template copy ─────────
echo "5. Marker file: target without marker gets full template content"
mktest
echo "old DEVELOPMENT content without marker" > "$dir/DEVELOPMENT.md"
sync_yes "$dir" > /dev/null
assert_contains "Marker added to target" "$dir/DEVELOPMENT.md" "$MARKER"
assert_contains "Template content synced" "$dir/DEVELOPMENT.md" "npm run ci"
assert_not_contains "Old content gone" "$dir/DEVELOPMENT.md" "old DEVELOPMENT content"
echo ""

# ── 6. New file: copied on first sync ─────────────────────────────────────────
echo "6. New file is created in empty project"
mktest
sync_yes "$dir" > /dev/null
[ -f "$dir/AGENTS.md" ] && ok "AGENTS.md created in empty project" || fail "AGENTS.md not created"
[ -f "$dir/DEVELOPMENT.md" ] && ok "DEVELOPMENT.md created in empty project" || fail "DEVELOPMENT.md not created"
echo ""

# ── 7. 'a' applies all remaining diffs without further prompting ───────────────
echo "7. 'a' applies all remaining changes"
mktest
# Create targets: AGENTS.md is stale, DEVELOPMENT.md is stale
echo "old AGENTS" > "$dir/AGENTS.md"
echo "old DEVELOPMENT" > "$dir/DEVELOPMENT.md"
# Answer 'a' to the first prompt — all subsequent diffs should auto-apply
printf 'a\n' | bash "$SYNC_SH" "$dir" > /dev/null
assert_files_equal "AGENTS.md applied via 'a'" "$TEMPLATE_DIR/AGENTS.md" "$dir/AGENTS.md"
assert_files_equal "DEVELOPMENT.md applied via 'a'" "$TEMPLATE_DIR/DEVELOPMENT.md" "$dir/DEVELOPMENT.md"
echo ""

# ── 8. No-marker template + target with marker: project section preserved ──────
echo "8. No-marker template, target has marker: project section preserved"
mktest
# Build target: template content (no marker in template) + marker + project section
cat "$TEMPLATE_DIR/AGENTS.md" > "$dir/AGENTS.md"
printf '\n%s\n\n## Custom Notes\n\nproject-only content\n' "<!-- END-SHARED -->" >> "$dir/AGENTS.md"
sync_yes "$dir" > /dev/null
assert_contains "Marker preserved in target" "$dir/AGENTS.md" "<!-- END-SHARED -->"
assert_contains "Project section preserved" "$dir/AGENTS.md" "project-only content"
assert_contains "Template content present" "$dir/AGENTS.md" "npm run ci"
echo ""

# ── Summary ────────────────────────────────────────────────────────────────────
echo "Results: $pass passed, $fail failed"
if [[ $fail -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  printf '  - %s\n' "${failed_tests[@]}"
  exit 1
fi
