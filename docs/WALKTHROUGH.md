# Walkthrough

A hands-on tour of the dotfiles after installation. Run each step in your terminal to get comfortable with what's available.

## Step 1: Verify Installation

Make sure everything landed correctly:

```bash
dot --version
dot doctor
dot status
```

`dot doctor` catches common problems early. If something's off, it'll tell you.

## Step 2: Explore the Shell

The shell ships with modern replacements wired in:

```bash
z dotfiles          # Jump to ~/.dotfiles (zoxide)
z -                 # Go back

<Ctrl-R>            # Fuzzy search command history (fzf)
<Ctrl-T>            # Fuzzy find files

ls                  # Aliased to eza
cat file.txt        # Aliased to bat
```

## Step 3: Git Workflow

```bash
gst                 # git status
lg                  # Pretty log graph
ga .                # git add
gcm "message"       # git commit -m
lgui                # Launch lazygit
```

## Step 4: Tmux

Prefix is `Ctrl-a`:

```bash
<Ctrl-a> c          # New window
<Ctrl-a> |          # Split vertically
<Ctrl-a> -          # Split horizontally
<Ctrl-a> h/j/k/l    # Navigate panes (vim-style)
<Ctrl-a> f          # Fuzzy session switcher
```

## Step 5: Neovim

```bash
nvim .

# Inside Neovim:
<Space>             # Leader — shows command palette
<Space>ff           # Find files
<Space>fg           # Live grep
<Space>e            # Toggle file tree
```

## Step 6: Docker

```bash
dps                 # List running containers
dco up -d           # docker compose up
dlogsf container    # Follow container logs
lzd                 # Launch lazydocker
```

## Step 7: Kubernetes (if enabled)

```bash
k get pods          # kubectl
kctx                # Switch context
kn                  # Switch namespace
k9                  # Launch k9s
```
