---
render_with_liquid: false
---

# Tutorial: First Install

End-to-end installation and verification, from zero to a fully-working environment in under 5 minutes.

## Prerequisites

- macOS 15+, Ubuntu 22.04+, Debian 12+, NixOS 23.11+, Arch (rolling), Fedora 41+, or WSL2 with Ubuntu 22.04+ (see [Appendix A](../05-appendices/A-platform-matrix.md))
- `git` and `curl` installed
- Shell access (Zsh, Fish, or Bash)
- Optional but recommended: SSH key for signing commits

## Step 1: Run the Installer

First complete the [verified release download](../../../README.md#verified-release-installer), then:

```sh
bash /tmp/dotfiles-install.sh
```

The installer:

1. Checks prerequisites and bootstraps `gum` for nicer prompts (optional)
2. Installs chezmoi, checking the download against a pinned SHA-256
3. Clones the pinned release tag to `~/.dotfiles` (or reuses an existing checkout there)
4. Backs up every existing file chezmoi will overwrite to `~/.dotfiles.bak.<timestamp>/`
5. Writes `sourceDir` to `~/.config/chezmoi/chezmoi.toml`, copies your git name, email and signing key from `git config --global` into it when it has no `[data]` table yet, and runs `chezmoi apply`

It does not run `chezmoi init`, so it asks no per-machine questions: set those in `~/.config/chezmoi/chezmoi.toml` (Step 4). It installs no packages or fonts unless you pass `--provision`.

The step headings it prints:

```
==> Checking Prerequisites...
==> Preparing source directory...
==> Backing up existing dotfiles...
==> Applying Configuration...
==> Configs deployed. To also install the toolchain (packages, fonts, tools):
Success! Configuration loaded. Please restart your shell.
==> Run 'dot help tour' for an interactive tour of your new dotfiles.
```

## Step 2: Verify

Open a new shell and run:

```sh
dot doctor
```

It prints one section per area (core shells, CLI tools, infrastructure, AI CLIs, environment, platform, state, git signing, update tooling, performance), one line per check. An excerpt:

```
--- Dotfiles Doctor ---

== Core Shells ==
  ✓    zsh                                 /bin/zsh (system)
  ✓    fish                                /bin/fish (system)
...
== State ==
  ✗    chezmoi state                       drifted (run dot doctor drift show)
  ✓    .zshrc                              present
...
== Git Signing ==
  ✓    signing key                         ssh ~/.ssh/id_ed25519
  ✓    commit.gpgsign                      every commit is signed
...
  ✗    1 error(s)                          1 warning(s). Run 'dot doctor fix' to repair.
```

A failing check names the command that fixes it.

## Step 3: Take the Tour

```sh
dot help tour
```

An interactive walkthrough covering:

- Shell basics and aliases
- Secrets workflow
- Theme switching
- Performance tuning
- Security hardening

Each section takes 30-60 seconds. You can skip sections or exit at any time.

## Step 4: Customize

### Per-Machine Settings

Edit `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
machine = "macbook-t2"       # a preset in defaults/.chezmoidata/hardware.toml
theme = "tahoe-dark"         # see `dot theme list`
default_shell = "fish"       # zsh, fish, or nu
terminal_font_family = "JetBrainsMono Nerd Font"
terminal_font_size = 12      # default 20
```

### Feature Flags

The defaults live in `~/.dotfiles/defaults/.chezmoidata.toml` (the chezmoi source root is `defaults/`). To change a flag for one machine without touching the repository, override it in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data.features]
dms = false                  # Dank Material Shell (Niri)
linux_desktop = false        # Linux-specific desktop configs
waybar = false               # Waybar status bar
```

After editing, apply:

```sh
dot apply
```

## Step 5: Add Your Identity

`~/.gitconfig` is managed by chezmoi, so set signing through chezmoi data rather than `git config --global` (the next apply would overwrite it). In `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
git_name = "Your Name"
git_email = "you@example.com"
git_signingkey = "~/.ssh/id_ed25519"
git_signingformat = "ssh"
```

With a signing key set, the rendered `~/.gitconfig` turns on `commit.gpgsign` and `tag.gpgSign`, sets `gpg.format`, and points `gpg.ssh.allowedSignersFile` at `~/.config/git/allowed_signers`. That file is managed too: add your own key to its source with `dot config edit ~/.config/git/allowed_signers`, one line per key:

```
you@example.com ssh-ed25519 AAAA...
```

Then run `dot apply` and test:

```sh
cd ~/.dotfiles
git commit --allow-empty -m "test: signature"
git verify-commit HEAD
# Good "git" signature for you@example.com with ED25519 key SHA256:...
```

## Step 6: First Theme Switch

```sh
dot theme
```

With no arguments, `dot theme` opens a picker of the available themes. Select one and press Enter. `dot theme set <name>` switches without the picker.

## Troubleshooting

If `dot doctor` shows failures:

```sh
dot doctor fix      # auto-fix common issues
dot doctor fix -n   # dry-run first to see what would change
```

If the installation is broken beyond repair:

```sh
dot doctor rollback  # restore the previous known-good state
```

If `dot doctor` still fails after `dot doctor fix` and a rollback, check:

- `~/.local/state/dotfiles/heal.log`: what `dot doctor fix` did
- `~/.local/state/dotfiles/rollback.log`: rollback attempts
- `chezmoi doctor`: chezmoi-specific diagnostics

Still stuck? See [Cookbook: Troubleshooting](../04-cookbook/02-troubleshooting.md).

## What Got Installed

After the install (plus `--provision` for the packages themselves), you have:

| Surface | What's There |
|:---|:---|
| **Shell** | Fish (default), Zsh, Nushell, Bash all configured with cached init |
| **Editor** | Neovim with lazy.nvim + LSP + theme-synced colorscheme |
| **Terminal** | Ghostty/Alacritty/Kitty/WezTerm configs (pick whichever is installed) |
| **Git** | Signed commits, delta diff, conventional commit template |
| **AI tooling** | Agent CLIs installed with `dot ai install`, pinned in `[ai_tools]` in `defaults/.chezmoidata.toml` |
| **Secret store** | chezmoi age encryption and `dot secret`; `dot secret init` creates the age key at `~/.config/chezmoi/key.txt` |
| **Security** | Gitleaks, detect-secrets baseline, workstation attestation (`dot attest show`) |
| **Theme engine** | K-Means wallpaper extractor, system + custom wallpaper discovery |

## Next

- [Tutorial: Add a Wallpaper → Theme](02-add-wallpaper.md)
- [Tutorial: Create a Machine Profile](03-create-profile.md)
- [Tutorial: Encrypt a Secret](04-encrypt-secret.md)
- [Cookbook: Recipes](../04-cookbook/01-recipes.md)
