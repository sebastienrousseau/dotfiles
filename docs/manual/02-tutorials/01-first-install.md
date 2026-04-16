# Tutorial: First Install

End-to-end installation and verification, from zero to a fully-working environment in under 5 minutes.

## Prerequisites

- macOS 14+, Ubuntu/Debian 20.04+, Arch (rolling), Fedora 39+, or WSL2 on Windows 11
- `git` and `curl` installed
- Shell access (Zsh, Fish, or Bash)
- Optional but recommended: SSH key for signing commits

## Step 1: Run the Installer

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh)"
```

The installer:
1. Verifies prerequisites (`git`, `curl`, write access to `~`)
2. Downloads chezmoi via the SHA256-verified installer
3. Clones the dotfiles source to `~/.dotfiles`
4. Runs `chezmoi init` to prompt for per-machine settings
5. Runs `chezmoi apply` with progress output

Expected output:

```
[install] Verifying prerequisites
[install] Installing chezmoi (verified SHA256)
[install] Cloning source to ~/.dotfiles
[install] Running chezmoi init (interactive)
  Git email: you@example.com
  Machine preset [macbook-t2]:
  Default theme [tahoe-dark]:
  Default shell [fish]:
[install] Applying configuration (180 files)
[install] ✓ Installation complete
```

## Step 2: Verify

Open a new shell and run:

```sh
dot doctor
```

Expected output:

```
◈ DOTFILES
Dot • Diagnostics

--- Health Check ---
  ✓ Paths             ~/.local/bin, mise shims present
  ✓ Tools             git, chezmoi, mise installed
  ✓ Chezmoi           clean (no drift)
  ✓ Shell             fish (500ms startup)
  ✓ Security          SSH key present, Age key present
  ✓ Portability       LC_ALL=en_US.UTF-8, TERM=xterm-256color

Score: 98/100
```

Any warnings will be accompanied by a suggested fix.

## Step 3: Take the Tour

```sh
dot learn
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
machine = "macbook-t2"       # see .chezmoidata/hardware.toml for presets
theme = "tahoe-dark"         # see `dot theme list`
default_shell = "fish"       # fish, zsh, bash
terminal_font_family = "JetBrainsMono Nerd Font"
terminal_font_size = 12
```

### Feature Flags

Edit `.chezmoidata.toml` in the source directory (`~/.dotfiles/.chezmoidata.toml`):

```toml
[features]
dms = false                  # Dank Material Shell (Niri)
linux_desktop = false        # Linux-specific desktop configs
waybar = false               # Waybar status bar
```

After editing, apply:

```sh
dot apply
```

## Step 5: Add Your Identity

If you have an SSH key, configure signed commits:

```sh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
git config --global gpg.format ssh
git config --global gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers
```

Add your own key to `~/.ssh/allowed_signers`:

```
you@example.com ssh-ed25519 AAAA...
```

Test:

```sh
cd ~/.dotfiles
git commit --allow-empty -m "test: signature"
git verify-commit HEAD
# Good "git" signature for you@example.com
```

## Step 6: First Theme Switch

```sh
dot theme
```

A picker opens showing all paired wallpaper themes on your system. Select one and press Enter. The terminal, editor, desktop wallpaper, and macOS accent color update in about 3 seconds.

## Troubleshooting

If `dot doctor` shows failures:

```sh
dot heal      # auto-fix common issues
dot heal -n   # dry-run first to see what would change
```

If the installation is broken beyond repair:

```sh
dot rollback  # restore the previous known-good state
```

If `dot doctor` still fails after heal + rollback, check:

- `~/.local/state/dotfiles/install.log` — installer log
- `~/.local/state/dotfiles/heal.log` — heal attempts
- `chezmoi doctor` — chezmoi-specific diagnostics

Still stuck? See [Cookbook: Troubleshooting](../04-cookbook/02-troubleshooting.md).

## What Got Installed

After `dot doctor` reports a healthy score, you have:

| Surface | What's There |
|:---|:---|
| **Shell** | Fish (default), Zsh, Nushell, Bash all configured with cached init |
| **Editor** | Neovim with lazy.nvim + LSP + theme-synced colorscheme |
| **Terminal** | Ghostty/Alacritty/Kitty/WezTerm configs (pick whichever is installed) |
| **Git** | Signed commits, delta diff, conventional commit template |
| **AI tooling** | Claude Code, Codex, Copilot CLI, Gemini CLI via mise |
| **Secret store** | Age key, SOPS config, `dot secrets` command ready |
| **Security** | Gitleaks, detect-secrets baseline, signed attestation log |
| **Theme engine** | K-Means wallpaper extractor, system + custom wallpaper discovery |

## Next

- [Tutorial: Add a Wallpaper → Theme](02-add-wallpaper.md)
- [Tutorial: Create a Machine Profile](03-create-profile.md)
- [Tutorial: Encrypt a Secret](04-encrypt-secret.md)
- [Cookbook: 30+ recipes](../04-cookbook/01-recipes.md)
