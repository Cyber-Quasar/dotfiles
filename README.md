# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io), synced across
Termux (Android) and Linux from a single repo.

## What's tracked

This list is generated automatically by a git pre-commit hook — see
`scripts/update-readme.sh`. Don't edit the block below by hand; it will be
overwritten on the next commit.

<!-- MANAGED_FILES_START -->
- `~/.gitconfig`
- `~/.p10k.zsh`
- `~/.termux/font.ttf`
- `~/.termux/termux.properties`
- `~/.zshrc`
- `~/README.md`
<!-- MANAGED_FILES_END -->

## Platform separation

One repo, no forks or branches per OS. Platform-specific behavior is handled
via chezmoi templates (`.tmpl` files) using a `platform` variable, since
`chezmoi.os` alone can't distinguish Termux from other Linux systems (both
report `"linux"`).

Each machine needs its own `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
    platform = "termux"   # or "linux"
```

Termux-only files (like `.termux/`) are skipped entirely on non-Termux
machines via `.chezmoiignore`.

## Repo layout

Source files live under `home/`, not the repo root — a `.chezmoiroot` file
at the repo root points chezmoi there. This keeps the repo root readable
(README, workflows, scripts) separate from the actual managed dotfiles.

```
dotfiles/
├── .chezmoiroot          # contains: home
├── .github/workflows/
├── scripts/
│   └── update-readme.sh
├── README.md
└── home/
    ├── .chezmoiignore
    ├── dot_zshrc.tmpl
    ├── dot_gitconfig
    ├── dot_p10k.zsh
    └── private_dot_termux/
        ├── font.ttf
        └── termux.properties
```

## Setup on a new machine

**Termux:**
```bash
pkg install chezmoi
mkdir -p ~/.config/chezmoi
echo -e '[data]\n    platform = "termux"' > ~/.config/chezmoi/chezmoi.toml
chezmoi init --apply git@github.com:<you>/dotfiles.git
```

**Linux:**
```bash
sh -c "$(curl -fsLS get.chezmoi.io)"
mkdir -p ~/.config/chezmoi
echo -e '[data]\n    platform = "linux"' > ~/.config/chezmoi/chezmoi.toml
chezmoi init --apply git@github.com:<you>/dotfiles.git
```

**After cloning on any machine**, also install the pre-commit hook (it does
not travel with `git clone` automatically):
```bash
chezmoi cd
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## How to use

```bash
chezmoi edit ~/.zshrc     # edit the source template
chezmoi diff               # preview changes
chezmoi apply               # apply to actual home dir
chezmoi update              # pull latest from GitHub + apply
```

Commit and push from the source dir:
```bash
chezmoi cd
git add -A && git commit -m "message" && git push
```

## Explicitly NOT tracked

`.ssh/`, `.suroot`, `.bash_history`, `.zsh_history`, and framework-managed
dirs (`.oh-my-zsh`, `.cache`, `.npm`, `.local`, `.android`) — secrets,
history, and generated files don't belong in a synced config repo.

## Relationship to Termux backup system

This repo handles portable, hand-authored config. The separate Termux
backup system (Cyber-Quasar) handles device state, caches, and anything
not meant to be identical across machines. The two are not meant to
track the same files.
