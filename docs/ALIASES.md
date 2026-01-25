# Aliases

This page lists all shell aliases provided by the dotfiles.

## Organization

Aliases are organized in `~/.dotfiles/.chezmoitemplates/aliases/` by category. Each category has its own directory containing a `<name>.aliases.sh` file.

## Categories

### Navigation

| Alias | Command | Description |
|-------|---------|-------------|
| `..` | `cd ..` | Go up one directory |
| `...` | `cd ../..` | Go up two directories |
| `....` | `cd ../../..` | Go up three directories |
| `-` | `cd -` | Go to previous directory |

### Git

| Alias | Command | Description |
|-------|---------|-------------|
| `g` | `git` | Git shorthand |
| `ga` | `git add` | Stage files |
| `gaa` | `git add --all` | Stage all files |
| `gc` | `git commit` | Commit |
| `gcm` | `git commit -m` | Commit with message |
| `gco` | `git checkout` | Checkout |
| `gd` | `git diff` | Show diff |
| `gf` | `git fetch` | Fetch |
| `gl` | `git pull` | Pull |
| `gp` | `git push` | Push |
| `gst` | `git status` | Status |
| `lg` | `git log --graph --oneline` | Graph log |
| `lgui` | `lazygit` | Open lazygit |

### Docker

| Alias | Command | Description |
|-------|---------|-------------|
| `d` | `docker` | Docker shorthand |
| `dco` | `docker compose` | Docker Compose |
| `dps` | `docker ps` | List containers |
| `dpsa` | `docker ps -a` | List all containers |
| `di` | `docker images` | List images |
| `dexec` | `docker exec -it` | Execute in container |
| `denter` | `docker exec -it <container> /bin/bash` | Enter container |
| `dlogsf` | `docker logs -f` | Follow logs |
| `dl` | `docker logs` | Show logs |
| `dprune` | `docker system prune` | Clean up |
| `dprunea` | `docker system prune -a` | Clean up all |
| `lzd` | `lazydocker` | Open lazydocker |

### Kubernetes

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
| `mk` | `minikube` | Minikube shorthand |
| `k9` | `k9s` | Open k9s |

### Modern Replacements

| Alias | Command | Description |
|-------|---------|-------------|
| `ls` | `eza` | Modern ls |
| `ll` | `eza -la` | Long list |
| `la` | `eza -a` | List all |
| `lt` | `eza --tree` | Tree view |
| `cat` | `bat` | Syntax highlighted cat |

### File Operations

| Alias | Command | Description |
|-------|---------|-------------|
| `cp` | `cp -iv` | Interactive verbose copy |
| `mv` | `mv -iv` | Interactive verbose move |
| `rm` | `rm -iv` | Interactive verbose remove |
| `mkdir` | `mkdir -pv` | Create dirs with parents |

### System

| Alias | Command | Description |
|-------|---------|-------------|
| `ports` | `netstat -tulanp` | Show open ports |
| `myip` | `curl ifconfig.me` | Show public IP |
| `path` | `echo $PATH \| tr ':' '\n'` | Show PATH entries |

### Dotfiles

| Alias | Command | Description |
|-------|---------|-------------|
| `dot` | `~/.local/bin/dot` | Dotfiles CLI |
| `dotcd` | `cd ~/.dotfiles` | Go to dotfiles |
| `dotedit` | `$EDITOR ~/.dotfiles` | Edit dotfiles |

## Adding Custom Aliases

1. Create a new file in the appropriate category:
   ```bash
   vim ~/.dotfiles/.chezmoitemplates/aliases/mycategory/mycategory.aliases.sh
   ```

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
