#!/usr/bin/env bash
#
# Generate README.md from README.template.md.
# Dynamically generates:
#   - The list of chezmoi source entries.
#   - The repository layout as a directory tree.
#
# Required template markers:
#   <!-- GENERATED:MANAGED_FILES -->
#   <!-- GENERATED:REPO_FILES -->
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_ROOT/README.template.md"
README="$REPO_ROOT/README.md"

TMP="$REPO_ROOT/.README.md.tmp"
FILES_TMP="$REPO_ROOT/.README-files.tmp"
SOURCE_TMP="$REPO_ROOT/.README-source.tmp"
TREE_TMP="$REPO_ROOT/.README-tree.tmp"

cleanup() {
  rm -f "$TMP" "$FILES_TMP" "$SOURCE_TMP" "$TREE_TMP"
}
trap cleanup EXIT

cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------

for command in git awk sort grep cmp; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Error: required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

if [[ ! -f "$TEMPLATE" ]]; then
  printf 'Error: README template not found: %s\n' "$TEMPLATE" >&2
  exit 1
fi

# Each generated section must have exactly one standalone marker line.
for marker in '<!-- GENERATED:MANAGED_FILES -->' \
  '<!-- GENERATED:REPO_FILES -->'; do
  count="$(awk -v marker="$marker" \
    '$0 == marker { count++ } END { print count + 0 }' "$TEMPLATE")"

  if [[ "$count" != "1" ]]; then
    printf 'Error: expected exactly one standalone line containing %s; found %s.\n' \
      "$marker" "$count" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Build the repository file inventory
# ---------------------------------------------------------------------------

# Include tracked files and non-ignored untracked files that currently exist.
# Git does not track empty directories.
git ls-files --cached --others --exclude-standard |
  LC_ALL=C sort -u |
  while IFS= read -r path; do
    case "$path" in
    .git | .git/* | .README.md.tmp | .README-files.tmp | .README-source.tmp | .README-tree.tmp)
      continue
      ;;
    esac

    if [[ -f "$path" || -L "$path" ]]; then
      printf '%s\n' "$path"
    fi
  done >"$FILES_TMP"

# ---------------------------------------------------------------------------
# Identify chezmoi source entries and decode their target filenames.
#
# Output columns, separated by tabs:
#   target path, source entry, type

decode_target_component() {
  local component="$1"

  # .tmpl changes processing, not the destination filename.
  [[ "$component" == *.tmpl ]] && component="${component%.tmpl}"

  while :; do
    case "$component" in
      literal_*)
        component="${component#literal_}"
        break
        ;;
      dot_*)
        component=".${component#dot_}"
        break
        ;;
      private_* | executable_* | readonly_* | symlink_* | empty_* | \
      encrypted_* | exact_* | create_* | modify_* | remove_* | \
      run_* | before_* | after_* | once_*)
        component="${component#*_}"
        ;;
      *)
        break
        ;;
    esac
  done

  printf '%s' "$component"
}

describe_source_entry() {
  local component="$1"
  local is_template=0
  local is_private=0
  local is_executable=0
  local is_readonly=0
  local is_symlink=0
  local is_empty=0
  local is_encrypted=0
  local is_exact=0
  local is_create=0
  local is_modify=0
  local is_remove=0
  local is_action=0
  local -a labels=()

  if [[ "$component" == *.tmpl ]]; then
    is_template=1
    component="${component%.tmpl}"
  fi

  while :; do
    case "$component" in
      literal_*)
        component="${component#literal_}"
        break
        ;;
      dot_*)
        component="${component#dot_}"
        break
        ;;
      private_*)
        is_private=1
        component="${component#private_}"
        ;;
      executable_*)
        is_executable=1
        component="${component#executable_}"
        ;;
      readonly_*)
        is_readonly=1
        component="${component#readonly_}"
        ;;
      symlink_*)
        is_symlink=1
        component="${component#symlink_}"
        ;;
      empty_*)
        is_empty=1
        component="${component#empty_}"
        ;;
      encrypted_*)
        is_encrypted=1
        component="${component#encrypted_}"
        ;;
      exact_*)
        is_exact=1
        component="${component#exact_}"
        ;;
      create_*)
        is_create=1
        component="${component#create_}"
        ;;
      modify_*)
        is_modify=1
        component="${component#modify_}"
        ;;
      remove_*)
        is_remove=1
        component="${component#remove_}"
        ;;
      run_* | before_* | after_* | once_*)
        is_action=1
        component="${component#*_}"
        ;;
      *)
        break
        ;;
    esac
  done

  if (( is_action )); then
    labels+=("Lifecycle script")
  else
    (( is_private )) && labels+=("Private")
    (( is_executable )) && labels+=("Executable")
    (( is_readonly )) && labels+=("Read-only")
    (( is_symlink )) && labels+=("Symlink")
    (( is_empty )) && labels+=("Empty")
    (( is_encrypted )) && labels+=("Encrypted")
    (( is_exact )) && labels+=("Exact")
    (( is_create )) && labels+=("Create")
    (( is_modify )) && labels+=("Modify")
    (( is_remove )) && labels+=("Remove")

    if (( is_template )); then
      labels+=("Template")
    else
      labels+=("Regular file")
    fi
  fi

  local IFS=' '
  printf '%s' "${labels[*]}"
}

while IFS= read -r source_path; do
  case "$source_path" in
    README.md | README.template.md | .chezmoiignore | .github/* | scripts/*)
      continue
      ;;
  esac

  source_name="${source_path##*/}"
  source_type="$(describe_source_entry "$source_name")"

  # Lifecycle scripts are actions, not ordinary destination files.
  case "$source_name" in
    run_* | before_* | after_* | once_*)
      target_path="—"
      ;;
    *)
      target_path=""
      IFS='/' read -r -a components <<< "$source_path"

      for component in "${components[@]}"; do
        decoded="$(decode_target_component "$component")"

        if [[ -z "$target_path" ]]; then
          target_path="$decoded"
        else
          target_path="$target_path/$decoded"
        fi
      done

      target_path="~/$target_path"
      ;;
  esac

  printf '%s\t%s\t%s\n' \
    "$target_path" "$source_path" "$source_type"
done < "$FILES_TMP" |
  LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k2,2 > "$SOURCE_TMP"

# Generate a properly sorted directory tree
# ---------------------------------------------------------------------------

awk '
    function add_child(parent, name, fullpath, key, n) {
        key = parent SUBSEP name

        if (!(key in child_seen)) {
            child_seen[key] = 1

            # Insert children in lexical order, independently of path order.
            n = ++child_count[parent]

            while (n > 1 && children[parent, n - 1] > name) {
                children[parent, n] = children[parent, n - 1]
                n--
            }

            children[parent, n] = name
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
                connector = "└── "
                next_prefix = prefix "    "
            } else {
                connector = "├── "
                next_prefix = prefix "│   "
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
# Render README.md from the template

awk \
  -v source_file="$SOURCE_TMP" \
  -v tree_file="$TREE_TMP" '
    $0 == "<!-- GENERATED:MANAGED_FILES -->" {
        print "| Original filename (target) | Chezmoi source entry | Type |"
        print "| --- | --- | --- |"

        while ((getline line < source_file) > 0) {
            count = split(line, columns, "\t")

            for (i = 1; i <= count; i++) {
                gsub(/\|/, "\\|", columns[i])
            }

            printf "| `%s` | `%s` | %s |\n", \
                columns[1], columns[2], columns[3]
        }

        close(source_file)
        next
    }

    $0 == "<!-- GENERATED:REPO_FILES -->" {
        print "```text"
        print "dotfiles/"

        while ((getline line < tree_file) > 0) {
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

# Replace README only if its content changed
# ---------------------------------------------------------------------------

if [[ -f "$README" ]] && cmp -s "$TMP" "$README"; then
  printf 'README.md is already up to date.\n'
  exit 0
fi

mv "$TMP" "$README"
printf 'README.md regenerated successfully.\n'

git add -- README.md
printf 'README.md staged for commit.\n'
