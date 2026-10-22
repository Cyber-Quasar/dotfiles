#!/data/data/com.termux/files/usr/bin/bash
#
# Generate README.md from README.template.md.
# Dynamically generates:
#   - The list of files managed by chezmoi.
#   - The repository layout as a proper directory tree.
#
# Required template markers:
#   <!-- GENERATED:MANAGED_FILES -->
#   <!-- GENERATED:REPO_FILES -->
#

set -eu

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_ROOT/README.template.md"
README="$REPO_ROOT/README.md"

TMP="$REPO_ROOT/.README.md.tmp"
MANAGED_TMP="$REPO_ROOT/.README-managed.tmp"
FILES_TMP="$REPO_ROOT/.README-files.tmp"
TREE_TMP="$REPO_ROOT/.README-tree.tmp"

cleanup() {
  rm -f "$TMP" "$MANAGED_TMP" "$FILES_TMP" "$TREE_TMP"
}
trap cleanup EXIT

cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------

if ! command -v chezmoi >/dev/null 2>&1; then
  printf 'Error: chezmoi is not installed or not in PATH.\n' >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  printf 'Error: git is not installed or not in PATH.\n' >&2
  exit 1
fi

if ! command -v awk >/dev/null 2>&1; then
  printf 'Error: awk is not installed or not in PATH.\n' >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
  printf 'Error: README template not found: %s\n' "$TEMPLATE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Generate the chezmoi-managed file list
# ---------------------------------------------------------------------------

chezmoi managed --path-style relative |
  LC_ALL=C sort |
  awk '
        BEGIN {
            print "| File |"
            print "| --- |"
        }
        {
            gsub(/\|/, "\\|")
            print "| `" $0 "` |"
        }
    ' >"$MANAGED_TMP"

# ---------------------------------------------------------------------------
# Generate the repository file inventory
# ---------------------------------------------------------------------------

# Include tracked and non-ignored untracked files, but omit tracked files
# that have been deleted from the working tree.
git ls-files --cached --others --exclude-standard |
  LC_ALL=C sort -u |
  while IFS= read -r path; do
    case "$path" in
    .git | .git/* | .README.md.tmp | .README-managed.tmp | .README-files.tmp | .README-tree.tmp)
      continue
      ;;
    esac

    if [[ -f "$path" || -L "$path" ]]; then
      printf '%s\n' "$path"
    fi
  done >"$FILES_TMP"

# ---------------------------------------------------------------------------
# Turn the inventory into a correctly nested directory tree
# ---------------------------------------------------------------------------

awk '
    function add_child(parent, name, fullpath, key) {
        key = parent SUBSEP name

        if (!(key in child_seen)) {
            child_seen[key] = 1
            children[parent, ++child_count[parent]] = name
        }

        fullpath = (parent == "" ? name : parent "/" name)
        return fullpath
    }

    {
        path = $0
        parent = ""
        count = split(path, parts, "/")

        for (i = 1; i <= count; i++) {
            name = parts[i]
            fullpath = add_child(parent, name)

            if (i < count) {
                is_dir[fullpath] = 1
            }

            parent = fullpath
        }
    }

    function print_tree(parent, prefix, i, name, fullpath, connector, next_prefix, total) {
        total = child_count[parent]

        for (i = 1; i <= total; i++) {
            name = children[parent, i]
            fullpath = (parent == "" ? name : parent "/" name)

            if (i == total) {
                connector = "`-- "
                next_prefix = prefix "    "
            } else {
                connector = "|-- "
                next_prefix = prefix "|   "
            }

            if (is_dir[fullpath]) {
                printf "%s%s%s/\n", prefix, connector, name
                print_tree(fullpath, next_prefix)
            } else {
                printf "%s%s%s\n", prefix, connector, name
            }
        }
    }

    END {
        print_tree("", "")
    }
' "$FILES_TMP" >"$TREE_TMP"

# ---------------------------------------------------------------------------
# Validate template markers
# ---------------------------------------------------------------------------

for marker in '<!-- GENERATED:MANAGED_FILES -->' \
  '<!-- GENERATED:REPO_FILES -->'; do
  count="$(grep -F -o "$marker" "$TEMPLATE" | wc -l | tr -d '[:space:]')"

  if [[ "$count" != "1" ]]; then
    printf 'Error: expected exactly one occurrence of %s in README.template.md; found %s.\n' \
      "$marker" "$count" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Render README.md
# ---------------------------------------------------------------------------

awk \
  -v managed_file="$MANAGED_TMP" \
  -v tree_file="$TREE_TMP" '
    $0 == "<!-- GENERATED:MANAGED_FILES -->" {
        while ((getline line < managed_file) > 0) {
            print line
        }
        close(managed_file)
        next
    }

    $0 == "<!-- GENERATED:REPO_FILES -->" {
        print "```text"
        print "dotfiles/"

        while ((getline line < tree_file) > 0) {
            # Use Unicode tree connectors in the rendered README.
            gsub(/\|-- /, "├── ", line)
            gsub(/`-- /, "└── ", line)
            gsub(/\|   /, "│   ", line)
            print line
        }

        close(tree_file)
        print "```"
        next
    }

    {
        print
    }
' "$TEMPLATE" >"$TMP"

# ---------------------------------------------------------------------------
# Replace README only if its content changed
# ---------------------------------------------------------------------------

if [[ -f "$README" ]] && cmp -s "$TMP" "$README"; then
  printf 'README.md is already up to date.\n'
  exit 0
fi

mv "$TMP" "$README"
printf 'README.md regenerated successfully.\n'

# Stage the generated README if this is a Git repository.
git add -- README.md
printf 'README.md staged for commit.\n'
