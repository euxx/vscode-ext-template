#!/bin/bash
# Usage: ./scripts/sync.sh /path/to/extension-project
# Syncs shared config files from this template to the target project.
# For files with a <!-- END-SHARED --> marker, only the shared section
# (before the marker) is updated; project-specific content is preserved.

set -euo pipefail

TEMPLATE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="${1:?Usage: sync.sh <path-to-extension-project>}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

SHARED_FILES=(
  "AGENTS.md"
  "DEVELOPMENT.md"
  "RELEASE.md"
  ".gitignore"
  ".vscodeignore"
  ".oxlintrc.json"
  ".husky/pre-commit"
  ".vscode/launch.json"
  ".github/workflows/ci.yml"
  ".github/workflows/release.yml"
)

MARKER="<!-- END-SHARED -->"
tmpfile=$(mktemp)
trap "rm -f '$tmpfile'" EXIT

echo "Template : $TEMPLATE_DIR"
echo "Target   : $TARGET_DIR"
echo ""

copied=0
skipped=0
apply_all=false

for f in "${SHARED_FILES[@]}"; do
  src="$TEMPLATE_DIR/$f"
  dst="$TARGET_DIR/$f"
  [ -f "$src" ] || continue

  # Build effective content: shared section from template + project section from target
  if grep -qF "$MARKER" "$src"; then
    # Shared section (up to and including marker line)
    awk '{print} index($0, "<!-- END-SHARED -->"){exit}' "$src" > "$tmpfile"
    # Project-specific section (lines after marker in target)
    if [ -f "$dst" ] && grep -qF "$MARKER" "$dst"; then
      awk 'found{print} index($0,"<!-- END-SHARED -->"){found=1}' "$dst" >> "$tmpfile"
    fi
  else
    cp "$src" "$tmpfile"
  fi

  if [ ! -f "$dst" ]; then
    echo "[ NEW  ] $f"
    if $apply_all; then
      confirm="y"
    else
      read -rp "Copy? (y/a/N) " confirm
      [[ "$confirm" == "a" || "$confirm" == "A" ]] && apply_all=true && confirm="y"
    fi
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      mkdir -p "$(dirname "$dst")"
      cp "$tmpfile" "$dst"
      echo "Copied: $f"
      copied=$((copied+1))
    else
      echo "Skipped."
      skipped=$((skipped+1))
    fi
  elif ! diff -q "$tmpfile" "$dst" > /dev/null 2>&1; then
    echo "[ DIFF ] $f"
    diff --color=always "$dst" "$tmpfile" || true
    echo ""
    if $apply_all; then
      confirm="y"
    else
      read -rp "Apply? (y/a/N) " confirm
      [[ "$confirm" == "a" || "$confirm" == "A" ]] && apply_all=true && confirm="y"
    fi
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      cp "$tmpfile" "$dst"
      echo "Updated: $f"
      copied=$((copied+1))
    else
      echo "Skipped."
      skipped=$((skipped+1))
    fi
  else
    echo "[ OK   ] $f"
  fi
  echo ""
done

echo "Done. Updated: $copied, Skipped: $skipped."
