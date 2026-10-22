#!/bin/sh
# Regenerates the entire README.md, including the current chezmoi-managed
# file list. Can be run manually or installed as a Git pre-commit hook.

set -eu

REPO_ROOT="$(git rev-parse --show-toplevel)"
README="$REPO_ROOT/README.md"
TMP="$README.tmp"
NEW="$README.new"

trap 'rm -f "$TMP" "$NEW"' 0 HUP INT TERM

# Read the actual managed targets. Abort without changing README if this fails.
if ! RAW=$(chezmoi managed --path-style absolute); then
  echo "update-readme.sh: chezmoi managed failed; README not changed." >&2
  exit 1
fi

LIST=$(printf '%s\n' "$RAW" |
  while IFS= read -r path; do
    [ -f "$path" ] && printf '%s\n' "$path"
  done |
  sed "s|^$HOME|~|" |
  sort |
  sed 's/^/- `/; s/$/`/')

if [ -z "$LIST" ]; then
  echo "update-readme.sh: managed-file list is empty; README not changed." >&2
  exit 1
fi

# Generate the complete README from this template.
cat >"$TMP" <<'README'
# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io), synced across Termux (Android) and Linux from a single repository.

## What's tracked

This section is generated automatically by [`scripts/update-readme.sh`](scripts/update-readme.sh). Do not edit the managed-file list manually.

<!-- MANAGED_FILES_PLACEHOLDER -->

## Platform separation

One repository, with no forks or branches per operating system. Platform-specific behavior is handled through chezmoi templates (`.tmpl` files) using a `platform` variable, because Termux and other Linux systems both report `chezmoi.os` as `linux`.

Each machine needs its own `~/.config/chezmoi/chezmoi.toml`.

**Termux:**

```toml
[data]
    platform = "termux"
```

**Linux:**

```toml
[data]
    platform = "linux"
```

Termux-only files, such as `.termux/`, are skipped on non-Termux machines through `.chezmoiignore`.

## Repository layout

Source files sit at the repository root, using chezmoi's default source-directory behavior.

```text
dotfiles/
├── .github/
├── scripts/
│   └── update-readme.sh
├── README.md
├── .chezmoiignore
├── dot_zshrc.tmpl
├── dot_gitconfig
├── dot_p10k.zsh
└── private_dot_termux/
    ├── font.ttf
    └── termux.properties
```

The exact files can change as the repository evolves.

## Restore managed files from GitHub

Chezmoi stores the desired configuration in its source directory, normally `~/.local/share/chezmoi`. Applying the source state restores managed files to their target locations in your home directory.

### Existing setup

If chezmoi is already initialized and you want to restore the latest version from GitHub:

```bash
# Pull repository changes into chezmoi's source directory.
chezmoi git -- pull --ff-only

# Review what would change in your home directory.
chezmoi diff

# Restore/apply the managed files.
chezmoi apply
```

Review `chezmoi diff` before applying if you have important local changes. Applying can replace managed files with the versions generated from your source state.

If you only need to reapply the version already present in the local source directory, you can run:

```bash
chezmoi diff
chezmoi apply
```

### New or reinstalled device

Install Git and chezmoi first. Then configure the platform before initializing the repository.

**Termux:**

```bash
pkg install git chezmoi

mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<'EOF'
[data]
    platform = "termux"
EOF
```

**Linux:**

Install Git and chezmoi using your preferred installation method, then run:

```bash
mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<'EOF'
[data]
    platform = "linux"
EOF
```

**On either platform**, initialize your repository, review the changes, and apply them:

```bash
chezmoi init git@github.com:Cyber-Quasar/dotfiles.git

# Preview the files that will be restored.
chezmoi diff

# Apply the managed files to your home directory.
chezmoi apply
```

This requires GitHub SSH authentication to be configured on the device. Review the diff carefully before applying on a device that already has important configuration files.

## How to use

```bash
chezmoi edit ~/.zshrc   # Edit the source version of a managed file
chezmoi diff            # Preview changes to target files
chezmoi apply           # Apply the source state to your home directory
chezmoi update          # Pull updates and apply them
```

To edit the source repository directly and commit changes:

```bash
chezmoi cd
git status
git add -A
git commit -m "Describe the changes"
git push
exit
```

## Update the README

Run the generator from anywhere inside the repository:

```bash
sh scripts/update-readme.sh
```

It regenerates the entire README, refreshes the managed-file list, and stages `README.md` for Git.

To run it automatically before every commit, install it as a local pre-commit hook from the source directory:

```bash
chezmoi cd
cp scripts/update-readme.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
exit
```

Git hooks are local and do not travel with a clone. Repeat these commands on each device where you want the automatic update.

## Explicitly NOT tracked

`.ssh/`, `.suroot`, `.bash_history`, `.zsh_history`, and framework-managed directories such as `.oh-my-zsh`, `.cache`, `.npm`, `.local`, and `.android` are excluded because secrets, shell history, and generated files do not belong in a portable configuration repository.

## Relationship to the Termux backup system

This repository handles portable, hand-authored configuration. The separate Termux backup system (`termux-backup`) handles device state, caches, and files that should not necessarily be identical across machines.

The two systems serve different purposes and should not duplicate responsibility for the same files.
README

# Replace the placeholder with the current managed-file list.
awk -v list="$LIST" '
  /<!-- MANAGED_FILES_PLACEHOLDER -->/ { print list; next }
  { print }
' "$TMP" >"$NEW"

mv "$NEW" "$README"
rm -f "$TMP"

# Stage the regenerated README (also works when invoked by a pre-commit hook).
git add "$README"

echo "update-readme.sh: regenerated and staged README.md"
