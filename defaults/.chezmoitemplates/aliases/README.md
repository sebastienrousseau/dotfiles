<img
  src="https://cloudcdn.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

# Dotfiles Aliases (v0.2.539)

Modular alias definitions managed by Chezmoi

![Dotfiles banner][banner]

This directory contains modular alias definitions managed by **chezmoi**.

## How it Works

Aliases are split into small, manageable files (e.g., `git/git.aliases.sh`, `docker/docker.aliases.sh`).

During `chezmoi apply`, two templates in `defaults/dot_config/shell/` scan this directory for
`**/*.aliases.sh` files and inline them, in path order:

1. `90-ux-aliases.sh.tmpl` builds `~/.config/shell/90-ux-aliases.sh`, the eager layer. It holds the
   core categories (`archives`, `cd`, `clear`, `compliance`, `configuration`, `default`,
   `diagnostics`, `disk-usage`, `editor`, `git`, `installer`, `interactive`, `mkdir`, `modern`,
   `ps`, `rsync`, `sudo`, `system`), with `archives` placed after the others, and, on macOS only,
   the `macOS` files.
2. `91-ux-aliases-lazy.sh.tmpl` builds `~/.config/shell/91-ux-aliases-lazy.sh`, the lazy layer,
   with every other directory.

Bash and zsh source both files, the eager layer first, so a later definition of a name replaces
an earlier one (the lazy layer wins over the eager one). Zsh loads the eager layer at startup and
defers the lazy layer. Fish converts the aliases of both files into abbreviations
(`defaults/dot_config/fish/conf.d/aliases.fish.tmpl`), skipping values that use bash-only syntax.

Three settings, read when `chezmoi apply` renders the templates, trim the set:

- `DOTFILES_ALIAS_PROFILE=minimal` drops `interactive` and `sudo` from the eager layer and
  `ai`, `benchmarks`, `docker`, `gcloud`, `kubernetes`, `security` and `terraform` from the
  lazy layer (the default profile is `standard`).
- `DOTFILES_ALIAS_ECOSYSTEMS` (default `all`) limits the ecosystem directories to the listed
  ones: `python`, `node` (`npm`, `pnpm`, `yarn`), `rust`, `network` (`dig`, `security`) and
  `legacy` (`subversion`, `vagrant`).
- `aliases.buckets.system` and `aliases.buckets.svn` in the chezmoi data (both `true` by default)
  turn off `system` and `subversion`.

Keep names unique across files: a later definition silently replaces an earlier one. Where two
files wanted the same name, the more common use kept it and the other definition was removed or
made conditional:

| Name | Kept | Gave way |
| --- | --- | --- |
| `d` | `dot` (`system`) | `dig` and `docker` define `d` only when `dot` is not installed |
| `dcl` | `docker compose logs` (`docker`) | `dot ai claude` (`ai`; `dcla`, `dclh`, `dclr` remain) |
| `dki` | `docker info` (`docker`) | `dot ai kiro` (`ai`; `dkia`, `dkih`, `dkir` remain) |
| `gci` | `gcloud compute instances` | `gcloud init` |
| `gcccc`, `gcccl` | `gcloud container clusters create`, `list` | `gcloud config configurations create`, `list` |
| `gcpd` | `gcloud projects describe` | `gcloud projects delete` (destructive) |
| `backup`, `extract`, `goto` | the `archives` and `cd` functions | the `functions/` files of the same name (fish still uses those) |

## Usage

### Adding a New Alias

1. Create a new directory or file (e.g., `mytool/mytool.aliases.sh`).
2. Define your aliases:

   ```bash
   alias mycmd="echo 'Hello World'"
   ```

3. Apply changes:

   ```bash
   chezmoi apply
   ```

## Component List

<!-- markdownlint-disable MD013-->

| Directory | Layer | Description | Link |
| :-- | :-- | :-- | :-- |
| `ai` | lazy | AI agent CLIs (Claude Code, Codex, aider, Ollama and more). | [View README](ai/README.md) |
| `archives` | eager | Create, list and extract archives. | [View README](archives/README.md) |
| `benchmarks` | lazy | Benchmark commands with hyperfine. | [View README](benchmarks/README.md) |
| `cd` | eager | Directory navigation, bookmarks and history. | [View README](cd/README.md) |
| `chmod` | lazy | Permission shortcuts with validation. | [View README](chmod/README.md) |
| `clear` | eager | Clear the screen, optionally listing the directory. | [View README](clear/README.md) |
| `compliance` | eager | Privacy mode and the configuration audit trail. | [View README](compliance/README.md) |
| `configuration` | eager | Open common configuration files in `$EDITOR`. | [View README](configuration/README.md) |
| `default` | eager | General-purpose shell aliases. | [View README](default/README.md) |
| `diagnostics` | eager | Doctor, drift and repair shortcuts. | [View README](diagnostics/README.md) |
| `dig` | lazy | DNS lookups and public IP checks. | [View README](dig/README.md) |
| `disk-usage` | eager | Disk usage summaries with `du`. | [View README](disk-usage/README.md) |
| `docker` | lazy | Docker, Compose, Buildx and Swarm. | [View README](docker/README.md) |
| `editor` | eager | Editor aliases that follow `$EDITOR`. | [View README](editor/README.md) |
| `find` | lazy | File search with `fd`. | [View README](find/README.md) |
| `fonts` | lazy | List installed fonts. | [View README](fonts/README.md) |
| `gcloud` | lazy | Google Cloud SDK. | [View README](gcloud/README.md) |
| `git` | eager | Git commands and commit signing helpers. | [View README](git/README.md) |
| `go` | lazy | Go toolchain commands. | [View README](go/README.md) |
| `heroku` | lazy | Heroku CLI. | [View README](heroku/README.md) |
| `installer` | eager | Installer and remote deployment. | [View README](installer/README.md) |
| `interactive` | eager | Opt-in interactive `cp`, `mv`, `rm` and friends. | [View README](interactive/README.md) |
| `kubernetes` | lazy | kubectl, Helm, minikube, stern and k9s. | [View README](kubernetes/README.md) |
| `legal` | lazy | License scanning, headers and attribution. | [View README](legal/README.md) |
| `lua` | lazy | Lua REPL shortcuts. | [`lua.aliases.sh`](lua/lua.aliases.sh) |
| `macOS` | eager (macOS only) | macOS Finder, network and maintenance helpers. | [View README](macOS/README.md) |
| `make` | lazy | Make targets. | [View README](make/README.md) |
| `mkdir` | eager | Create directories, including dated ones. | [View README](mkdir/README.md) |
| `modern` | eager | eza, bat, zoxide, mise and other modern tools. | [View README](modern/README.md) |
| `npm` | lazy | npm commands. | [View README](npm/README.md) |
| `permission` | lazy | Numeric `chmod`, `chown` and `chgrp` shortcuts. | [View README](permission/README.md) |
| `pnpm` | lazy | pnpm commands. | [View README](pnpm/README.md) |
| `ps` | eager | Empty; process aliases moved to `system`. | [View README](ps/README.md) |
| `python` | lazy | Python, pip, uv and virtual environments. | [View README](python/README.md) |
| `rsync` | eager | rsync transfers. | [View README](rsync/README.md) |
| `rust` | lazy | Cargo and rustup. | [View README](rust/README.md) |
| `security` | lazy | GPG, OpenSSL, SSH, firewall rules and file locking. | [View README](security/README.md) |
| `subversion` | lazy | Subversion (SVN). | [View README](subversion/README.md) |
| `sudo` | eager | Superuser shortcuts. | [View README](sudo/README.md) |
| `system` | eager | Shell, process, network and nmap helpers. | [View README](system/README.md) |
| `terraform` | lazy | Terraform, OpenTofu and Ansible. | [View README](terraform/README.md) |
| `tmux` | lazy | tmux sessions. | [View README](tmux/README.md) |
| `uuid` | lazy | Generate a UUID and copy it. | [View README](uuid/README.md) |
| `vagrant` | lazy | Vagrant. | [View README](vagrant/README.md) |
| `wget` | lazy | wget downloads. | [View README](wget/README.md) |
| `yarn` | lazy | Yarn commands. | [View README](yarn/README.md) |

<!-- markdownlint-enable MD013-->

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg
