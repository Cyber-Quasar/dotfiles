dotfiles

Personal dotfiles managed with "chezmoi" (https://chezmoi.io), synced across Termux (Android) and Linux from a single repository.

Chezmoi source entries

These entries are discovered from the repository's chezmoi source filenames. They describe the configuration stored in Git, not necessarily the files currently managed on every device.

<!-- GENERATED:MANAGED_FILES -->

## Platform separation

One repository, with platform-specific behavior handled through chezmoi templates and the "platform" variable.

Each machine needs "~/.config/chezmoi/chezmoi.toml".

Termux:

[data]
    platform = "termux"

Linux:

[data]
    platform = "linux"

Termux-only files are skipped on non-Termux machines through ".chezmoiignore".

Repository layout

This inventory is generated from files in the repository that Git tracks or recognizes as non-ignored untracked files.

<!-- GENERATED:REPO_FILES -->

## Restore managed files from GitHub

Chezmoi stores the desired configuration in its source directory, normally "~/.local/share/chezmoi".

Existing setup

Pull the latest repository changes, review them, and apply the managed files:

chezmoi git -- pull --ff-only
chezmoi diff
chezmoi apply

If your local branch has no upstream configured, check your Git remote and branch tracking before pulling.

If you only need to apply the source state already present locally:

chezmoi diff
chezmoi apply

Review the diff before applying because managed target files may be changed.

New or reinstalled device

Install Git and chezmoi first.

On Termux:

pkg install git chezmoi

mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<'EOF'
[data]
    platform = "termux"
EOF

On Linux, install Git and chezmoi using your preferred method, then configure:

mkdir -p ~/.config/chezmoi
cat > ~/.config/chezmoi/chezmoi.toml <<'EOF'
[data]
    platform = "linux"
EOF

Initialize the repository, review the changes, and apply:

chezmoi init git@github.com:Cyber-Quasar/dotfiles.git
chezmoi diff
chezmoi apply

GitHub SSH authentication must already be configured. Review the diff carefully on devices that already contain important configuration files.

How to use

chezmoi edit ~/.zshrc
chezmoi diff
chezmoi apply
chezmoi update

To work directly in the source repository:

chezmoi cd
git status
git add -A
git commit -m "Describe the changes"
git push
exit

Update the README

The README is regenerated from this template and the repository inventory.

Run the generator from anywhere inside the repository:

bash scripts/update-readme.sh

The script updates "README.md" using the two generated sections above and stages the result if it changes.

GitHub Actions can run the generator automatically after pushes to "main". Generated changes should be committed by the workflow when necessary.

Explicitly NOT tracked

".ssh/", ".suroot", shell histories, and framework-managed or generated directories should be excluded when they contain secrets, transient state, or machine-specific data.

See ".chezmoiignore" for the actual chezmoi exclusions.

Relationship to the Termux backup system

This repository handles portable, hand-authored configuration. The separate "termux-backup" system handles device state, caches, and files that should not necessarily be identical across machines.

The two systems serve different purposes and should not duplicate responsibility for the same files.

