# Walkthrough

A hands-on tour of the dotfiles after installation.

---

## Step 1: Verify Installation

```bash
dot --version
dot doctor
dot status
```

## Step 2: Explore the Shell

Your shell comes pre-configured with modern tools:

```bash
# Smart directory navigation
z dotfiles          # Jump to ~/.dotfiles
z -                 # Go back

# Fuzzy finding
<Ctrl-R>            # Search command history
<Ctrl-T>            # Find files

# Modern tool replacements
ls                  # Runs 'eza'
cat file.txt        # Runs 'bat'
```

## Step 3: Git Workflow

```bash
gst                 # git status
lg                  # pretty git log graph
ga .                # git add
gcm "message"       # git commit -m
lgui                # Open lazygit TUI
```

## Step 4: Tmux Basics

If tmux is running (prefix is `Ctrl-a`):

```bash
<Ctrl-a> c          # New window
<Ctrl-a> |          # Split vertically
<Ctrl-a> -          # Split horizontally
<Ctrl-a> h/j/k/l    # Navigate panes (vim-style)
<Ctrl-a> f          # Fuzzy session switcher
```

## Step 5: Neovim IDE

```bash
nvim .

# Inside Neovim:
<Space>             # Leader key, shows command menu
<Space>ff           # Find files
<Space>fg           # Live grep
<Space>e            # Toggle file tree
```

## Step 6: Docker Workflow

```bash
dps                 # List running containers
dco up -d           # Docker compose up
dlogsf container    # Follow container logs
lzd                 # Open lazydocker TUI
```

## Step 7: Kubernetes (if enabled)

```bash
k get pods          # kubectl get pods
kctx                # Switch context
kn                  # Switch namespace
k9                  # Open k9s TUI
```

---

## Core Architecture

- **Chezmoi** replaces legacy Makefiles and symlinks with a template engine.
- **Universal templates** — `run_onchange_*.sh.tmpl` scripts adapt to OS (Darwin/Linux) automatically.
- **Performance** — run `dot benchmark` for your numbers; `DOTFILES_FAST=1` yields the quickest first prompt.

## Quick Reference

| Action | Command |
|--------|---------|
| Update dotfiles | `dot update` |
| Check health | `dot doctor` |
| Show drift | `dot drift` |
| Apply changes | `dot apply` |
| Edit source | `dot edit` |
| Benchmark shell | `dot benchmark` |
| New project | `dot new python myapp` |
| Enter sandbox | `dot sandbox` |

## Next Steps

- Customize your prompt in `~/.config/starship.toml`
- Add custom aliases in `~/.dotfiles/.chezmoitemplates/aliases/`
- Configure Neovim plugins in `~/.config/nvim/`
- Set up secrets with `dot secrets-init`
