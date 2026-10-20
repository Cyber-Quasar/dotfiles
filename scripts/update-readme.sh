#!/bin/sh
# Regenerates the "What's tracked" list in README.md from chezmoi's own
# managed-file list. Run manually, or installed as a pre-commit hook.
#
# Note: this reads chezmoi's *target* state (what's in ~), not the source
# repo layout, so it works the same whether or not .chezmoiroot is in use.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
README="$REPO_ROOT/README.md"

# Some POSIX shells (e.g. dash, Termux's default /bin/sh) don't reliably
# trigger `set -e` on a failed command substitution, so check explicitly
# instead of trusting set -e alone here.
if ! RAW=$(chezmoi managed --path-style absolute); then
  echo "update-readme.sh: 'chezmoi managed' failed, aborting (README not touched)" >&2
  exit 1
fi

LIST=$(printf '%s\n' "$RAW" \
  | while read -r path; do [ -f "$path" ] && echo "$path"; done \
  | sed "s|^$HOME|~|" \
  | sort \
  | sed 's/^/- `/; s/$/`/')

if [ -z "$LIST" ]; then
  echo "update-readme.sh: generated file list is empty, aborting (README not touched)" >&2
  exit 1
fi

awk -v list="$LIST" '
  /<!-- MANAGED_FILES_START -->/ { print; print list; skip=1; next }
  /<!-- MANAGED_FILES_END -->/   { skip=0 }
  !skip { print }
' "$README" > "$README.tmp" && mv "$README.tmp" "$README"

git add "$README"
