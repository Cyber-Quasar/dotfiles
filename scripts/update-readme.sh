#!/bin/sh
# Regenerates README.md from README.template.md and the current repository.
# Updates the managed-file list and repository file inventory automatically.
# Can be run manually or installed as a Git pre-commit hook.

set -eu

REPO_ROOT="$(git rev-parse --show-toplevel)"
TEMPLATE="$REPO_ROOT/README.template.md"
README="$REPO_ROOT/README.md"
TMP="$REPO_ROOT/.README.md.tmp"
MANAGED_TMP="$REPO_ROOT/.README-managed.tmp"
FILES_TMP="$REPO_ROOT/.README-files.tmp"

cleanup() {
  rm -f "$TMP" "$MANAGED_TMP" "$FILES_TMP"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

if [ ! -f "$TEMPLATE" ]; then
  echo "update-readme.sh: README.template.md not found; README unchanged." >&2
  exit 1
fi

# Read chezmoi's managed targets. Keep only targets that currently exist.
if ! RAW=$(chezmoi managed --path-style absolute); then
  echo "update-readme.sh: chezmoi managed failed; README unchanged." >&2
  exit 1
fi

printf '%s\n' "$RAW" |
  while IFS= read -r path; do
    [ -f "$path" ] || continue
    case "$path" in
    "$HOME"/*) path="~${path#"$HOME"}" ;;
    esac
    printf '%s\n' "$path"
  done |
  sort -u |
  sed 's/^/- `/; s/$/`/' >"$MANAGED_TMP"

if [ ! -s "$MANAGED_TMP" ]; then
  echo "update-readme.sh: managed-file list is empty; README unchanged." >&2
  exit 1
fi

# Inventory tracked and non-ignored untracked files.
# Exclude Git internals and the generated README temporary files.
if ! git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard |
  LC_ALL=C sort -u |
  while IFS= read -r path; do
    case "$path" in
    .git/* | .README.md.tmp | .README-managed.tmp | .README-files.tmp)
      continue
      ;;
    esac
    printf '%s\n' "$path"
  done >"$FILES_TMP"; then
  echo "update-readme.sh: failed to inventory repository; README unchanged." >&2
  exit 1
fi

if [ ! -s "$FILES_TMP" ]; then
  echo "update-readme.sh: repository inventory is empty; README unchanged." >&2
  exit 1
fi

# Ensure both markers exist exactly once before generating output.
for marker in \
  '<!-- GENERATED:MANAGED_FILES -->' \
  '<!-- GENERATED:REPO_FILES -->'; do
  count=$(grep -F -x -c "$marker" "$TEMPLATE" || :)
  if [ "$count" -ne 1 ]; then
    echo "update-readme.sh: expected exactly one $marker in template; README unchanged." >&2
    exit 1
  fi
done

# Replace generated markers with their corresponding dynamic sections.
if ! awk \
  -v managed_file="$MANAGED_TMP" \
  -v files_file="$FILES_TMP" '
  $0 == "<!-- GENERATED:MANAGED_FILES -->" {
    while ((getline line < managed_file) > 0) print line
    close(managed_file)
    next
  }
  $0 == "<!-- GENERATED:REPO_FILES -->" {
    print "```text"
    while ((getline line < files_file) > 0) print line
    close(files_file)
    print "```"
    next
  }
  { print }
' "$TEMPLATE" >"$TMP"; then
  echo "update-readme.sh: README generation failed; README unchanged." >&2
  exit 1
fi

# Validate output before replacing README.
if [ ! -s "$TMP" ] ||
  ! grep -F -q '## Repository layout' "$TMP" ||
  ! grep -F -q '## Restore managed files from GitHub' "$TMP" ||
  grep -F -q '<!-- GENERATED:' "$TMP"; then
  echo "update-readme.sh: generated README failed validation; README unchanged." >&2
  exit 1
fi

mv "$TMP" "$README"
git -C "$REPO_ROOT" add README.md

echo "update-readme.sh: regenerated and staged README.md"
