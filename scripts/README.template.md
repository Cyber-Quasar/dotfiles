
# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io), synced across Termux (Android) and Linux from a single repository.

## What's tracked

The list below is generated from chezmoi's managed targets that currently exist on this device.

<!-- GENERATED:MANAGED_FILES -->

## Platform separation

One repository, with platform-specific behavior handled through chezmoi templates and the `platform` variable.

Each machine needs `~/.config/chezmoi/chezmoi.toml`.

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

Termux-only files are skipped on non-Termux machines through `.chezmoiignore`.

## Repository layout

This inventory is generated from files in the repository that Git tracks or recognizes as non-ignored untracked files.

<!-- GENERATED:REPO_FILES -->

## Restore managed files from GitHub

Chezmoi stores the desired configuration in its source directory, normally `~/.local/share/chezmoi`.

### Existing setup

Pull the latest repository changes, review them, and apply the managed files:

```bash
chezmoi git -- pull --ff-only
chezmoi diff
chezmoi apply
```

If your local branch has no upstream configured, check your Git remote and branch tracking before pulling.

If you only need to apply the source state already present locally:

```bash
chezmoi diff
chezmoi apply
```

Review the diff before applying because managed target files may be changed.

### New or reinstalled device

Install Git and chezmoi first.

On Termux:

```bash
pkg install git chezmoi

mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<'EOF'
[data]
    platform = "termux"
EOF
```

On Linux, install Git and chezmoi using your preferred method, then configure:

```bash
mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<'EOF'
[data]
    platform = "linux"
EOF
```

Initialize the repository, review the changes, and apply:

```bash
chezmoi init git@github.com:Cyber-Quasar/dotfiles.git
chezmoi diff
chezmoi apply
```

GitHub SSH authentication must already be configured. Review the diff carefully on devices that already contain important configuration files.

## How to use

```bash
chezmoi edit ~/.zshrc
chezmoi diff
chezmoi apply
chezmoi update
```

To work directly in the source repository:

```bash
chezmoi cd
git status
git add -A
git commit -m "Describe the changes"
git push
exit
```

## Update the README

Run from anywhere inside the repository:

```bash
sh scripts/update-readme.sh
```

The script regenerates `README.md` from this template, updates both generated sections, and stages the result.

To run the generator automatically before every commit, install a local pre-commit hook:

```bash
chezmoi cd
cp scripts/update-readme.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
exit
```

Git hooks are local and do not transfer when cloning the repository. Install the hook separately on each device where you want it.

## Explicitly NOT tracked

`.ssh/`, `.suroot`, shell histories, and framework-managed or generated directories should be excluded when they contain secrets, transient state, or machine-specific data.

See `.chezmoiignore` for the actual chezmoi exclusions.

## Relationship to the Termux backup system

This repository handles portable, hand-authored configuration. The separate `termux-backup` system handles device state, caches, and files that should not necessarily be identical across machines.

The two systems serve different purposes and should not duplicate responsibility for the same files.

