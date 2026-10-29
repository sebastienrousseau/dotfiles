---
render_with_liquid: false
---

# Aliases

Shell aliases provided by the dotfiles, organized by category in `defaults/.chezmoitemplates/aliases/` in the source repo. This page lists a selection: `dot shell alias list` lists every alias, and `dot shell alias show <alias>` shows where one is defined.

Core categories (archives, cd, clear, configuration, default, diagnostics, disk-usage, editor, git, interactive, installer, mkdir, modern, ps, rsync, sudo, system, compliance) load at shell startup from `~/.config/shell/90-ux-aliases.sh`. The other categories (docker, kubernetes, cloud CLIs, language ecosystems and so on) load after the first prompt from `~/.config/shell/91-ux-aliases-lazy.sh`, and most of them only when the tool they wrap is installed.

## Categories

### Navigation

| Alias | Command | Description |
|-------|---------|-------------|
| `..` | `cd_with_history ..` | Go up one directory |
| `...` | `cd_with_history ../..` | Go up two directories |
| `....` | `cd_with_history ../../..` | Go up three directories |
| `-` | `cd -` | Go to previous directory |

### Git

| Alias | Command | Description |
|-------|---------|-------------|
| `g` | `git` | Git shorthand |
| `ga` | `git add` | Stage files |
| `gaa` | `git add --all` | Stage all files |
| `gc` | `git commit -a` | Commit all tracked changes |
| `gcm` | `git commit --message` | Commit with message |
| `gco` | `git checkout` | Checkout |
| `gd` | `git diff` | Show diff |
| `gf` | `git fetch` | Fetch |
| `gp` | `git pull` | Pull |
| `gph` | `git push` | Push |
| `gst` | `git status` | Status |
| `gl` | `git log --since="last month" --oneline` | Last month's log |
| `lg` | `git log --graph --oneline --decorate --all` | Graph log |
| `lgui` | `lazygit` | Open lazygit |

### Docker

Loaded only when `docker` is installed.

| Alias | Command | Description |
|-------|---------|-------------|
| `d` | `docker` | Docker shorthand (replaces the core `d` = `dot` once the lazy layer loads) |
| `dco` | `docker compose` | Docker Compose |
| `dkps` | `docker ps` | List containers |
| `dps` | `docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"` | Compact container table |
| `dkpsa` | `docker ps -a` | List all containers |
| `dkim` | `docker images` | List images |
| `dex` | `docker exec -it` | Execute in container |
| `dklf` | `docker logs -f` | Follow logs |
| `dksp` | `docker system prune` | Clean up |
| `lzd` | `lazydocker` | Open lazydocker |

### Kubernetes

Loaded only when `kubectl` is installed.

| Alias | Command | Description |
|-------|---------|-------------|
| `k` | `kubectl` | kubectl shorthand |
| `kg` | `kubectl get` | Get resources |
| `kgp` | `kubectl get pods` | Get pods |
| `kga` | `kubectl get all` | Get all resources |
| `kd` | `kubectl describe` | Describe resource |
| `kdel` | `kubectl delete` | Delete resource |
| `kl` | `kubectl logs` | View logs |
| `kex` | `kubectl exec -it` | Execute in pod |
| `kaf` | `kubectl apply -f` | Apply from file |
| `kctx` | `kubectx` | Switch context |
| `kn` | `kubens` | Switch namespace |
| `klog` | `stern` | Multi-pod logs |
| `klint` | `kube-linter lint` | Lint manifests |
| `ksec` | `kubesec scan` | Security scan |
| `mkg` | `minikube` | Minikube shorthand |
| `k9` | `k9s` | Open k9s |

### Modern replacements

Each wrapper uses the modern tool when it is installed and falls back to the classic command otherwise.

| Alias | Command | Description |
|-------|---------|-------------|
| `ls`, `l` | `dot_ls` | `eza --sort Name --icons --group-directories-first` |
| `ll` | `dot_ll` | `eza -alF` (long list) |
| `la` | `dot_la` | `eza -a` (list all) |
| `lt` | `dot_lt` | `eza -aT` (tree view) |
| `cat` | `dot_cat` | `bat` (or `batcat`), else `cat` |

### File operations

These override core commands, so they are opt-in: defined only when `DOTFILES_SAFE_ALIASES=1`.

| Alias | Command | Description |
|-------|---------|-------------|
| `cp` | `cp -vi` | Interactive verbose copy |
| `mv` | `mv -vi` | Interactive verbose move |
| `rm` | `rm -vi` | Interactive verbose remove |
| `mkdir` | `mkdir -pv` | Create dirs with parents |

### System

| Alias | Command | Description |
|-------|---------|-------------|
| `ports` | `ss -tulan` (`netstat -tulan` without `ss`) | Show open ports |
| `wip` | `dig +short myip.opendns.com @resolver1.opendns.com` | Show public IP (needs `dig`) |
| `path` | `echo ${PATH//:/\\n}` | Show PATH entries |

### Dotfiles

| Alias | Command | Description |
|-------|---------|-------------|
| `dot` | `$HOME/.local/bin/dot` | Dotfiles CLI |
| `d` | `dot` | Dotfiles CLI shorthand (until the Docker aliases load, see above) |

## Adding custom aliases

1. Create a new file in the appropriate category:

   ```bash
   vim ~/.dotfiles/defaults/.chezmoitemplates/aliases/mycategory/mycategory.aliases.sh
   ```

   A category that is not in the core list above loads with the lazy layer, after the first prompt.

2. Define your aliases:

   ```bash
   # shellcheck shell=bash
   # My Custom Aliases
   alias myalias='my-command'
   ```

3. Apply changes:

   ```bash
   chezmoi apply
   ```
