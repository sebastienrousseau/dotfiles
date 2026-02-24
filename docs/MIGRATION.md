# Migration Guides

Step-by-step guides for migrating from other dotfiles managers.

## Table of Contents

- [From GNU Stow](#from-gnu-stow)
- [From yadm](#from-yadm)
- [From bare Git repository](#from-bare-git-repository)
- [From dotbot](#from-dotbot)

---

## From GNU Stow

GNU Stow uses symlinks from a "stow directory" to your home. Chezmoi copies files (with templating support).

### Understanding the Difference

| GNU Stow | This Dotfiles |
|----------|---------------|
| Symlinks from `~/.dotfiles/zsh/.zshrc` → `~/.zshrc` | Copies from `~/.dotfiles/dot_zshrc` → `~/.zshrc` |
| No templating | Full Go template support |
| Manual stow/unstow | Automatic with `dot apply` |
| Single machine focus | Multi-machine with profiles |

### Migration Steps

#### 1. Backup your stow directory

```bash
cp -r ~/.dotfiles ~/.dotfiles-stow-backup
```

#### 2. Unstow all packages

```bash
cd ~/.dotfiles
for pkg in */; do
  stow -D "$pkg"
done
```

This converts symlinks back to the original files in your home directory.

#### 3. Install this dotfiles

```bash
# This will backup your existing files automatically
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
```

#### 4. Import your custom configurations

After installation, add your custom files:

```bash
# Add files you want to preserve
chezmoi add ~/.zshrc
chezmoi add ~/.config/nvim/init.lua
chezmoi add ~/.gitconfig
```

#### 5. Convert to templates (optional)

If you have machine-specific configs, convert to templates:

```bash
# Rename to .tmpl
chezmoi cd
mv dot_zshrc dot_zshrc.tmpl

# Edit and add template logic
# {{ if eq .chezmoi.os "darwin" }}
# macOS-specific config
# {{ end }}
```

#### 6. Clean up

```bash
# Remove old stow directory after verifying everything works
rm -rf ~/.dotfiles-stow-backup  # Only after thorough testing!
```

### Stow Package → Chezmoi Mapping

| Stow Structure | Chezmoi Structure |
|----------------|-------------------|
| `~/.dotfiles/zsh/.zshrc` | `~/.dotfiles/dot_zshrc` |
| `~/.dotfiles/vim/.vimrc` | `~/.dotfiles/dot_vimrc` |
| `~/.dotfiles/git/.gitconfig` | `~/.dotfiles/dot_gitconfig.tmpl` |
| `~/.dotfiles/nvim/.config/nvim/` | `~/.dotfiles/dot_config/nvim/` |

---

## From yadm

yadm uses a bare Git repository in `~/.local/share/yadm/repo.git`. This dotfiles uses chezmoi with a standard Git repo in `~/.dotfiles`.

### Understanding the Difference

| yadm | This Dotfiles |
|------|---------------|
| Bare Git repo in `~/.local/share/yadm` | Normal repo in `~/.dotfiles` |
| Files tracked in-place | Files managed separately, applied to home |
| Alternate files (##os.Linux) | Go templates (.tmpl) |
| External templates (envtpl) | Built-in templating |

### Migration Steps

#### 1. List your yadm-managed files

```bash
yadm list -a > ~/yadm-files.txt
cat ~/yadm-files.txt
```

#### 2. Export your configuration

```bash
# Create export directory
mkdir -p ~/yadm-export

# Copy all managed files
while read -r file; do
  mkdir -p ~/yadm-export/"$(dirname "$file")"
  cp ~/"$file" ~/yadm-export/"$file"
done < ~/yadm-files.txt
```

#### 3. Backup yadm state

```bash
cp -r ~/.local/share/yadm ~/.local/share/yadm-backup
cp -r ~/.config/yadm ~/.config/yadm-backup
```

#### 4. Install this dotfiles

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
```

#### 5. Import your files

```bash
cd ~/yadm-export
for file in $(find . -type f); do
  chezmoi add ~/"${file#./}"
done
```

#### 6. Convert alternate files to templates

yadm alternate files like `.bashrc##os.Linux` become templates:

**Before (yadm):**
```
~/.bashrc##os.Linux
~/.bashrc##os.Darwin
```

**After (chezmoi):**
```bash
# In ~/.dotfiles/dot_bashrc.tmpl:
{{ if eq .chezmoi.os "linux" }}
# Linux-specific config
export PATH="$HOME/.local/bin:$PATH"
{{ else if eq .chezmoi.os "darwin" }}
# macOS-specific config
export PATH="/opt/homebrew/bin:$PATH"
{{ end }}

# Common config
alias ll='ls -la'
```

#### 7. Migrate encrypted files

If using yadm encryption:

```bash
# Decrypt yadm files first
yadm decrypt

# Then add to chezmoi with age encryption
chezmoi add --encrypt ~/.ssh/id_rsa
```

#### 8. Clean up

```bash
# After verifying everything works
yadm destroy  # Removes yadm configuration
rm -rf ~/.local/share/yadm-backup
rm -rf ~/yadm-export
```

---

## From Bare Git Repository

Many people use a bare Git repo with an alias like `config` or `dotfiles`.

### Migration Steps

#### 1. Identify your setup

Common patterns:
```bash
# Check for bare repo
ls ~/.cfg  # or ~/.dotfiles.git, ~/.dot, etc.

# Check for alias
alias | grep -E '(config|dotfiles).*git'
```

#### 2. List tracked files

```bash
# Using your alias (e.g., 'config')
config ls-tree --name-only -r HEAD > ~/bare-git-files.txt
```

#### 3. Export files

```bash
mkdir -p ~/dotfiles-export
while read -r file; do
  mkdir -p ~/dotfiles-export/"$(dirname "$file")"
  cp ~/"$file" ~/dotfiles-export/"$file" 2>/dev/null || true
done < ~/bare-git-files.txt
```

#### 4. Backup bare repo

```bash
cp -r ~/.cfg ~/.cfg-backup  # Use your actual directory name
```

#### 5. Install and import

```bash
# Install
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"

# Import your files
cd ~/dotfiles-export
for file in $(find . -type f); do
  chezmoi add ~/"${file#./}"
done
```

---

## From dotbot

dotbot uses a YAML configuration file to manage symlinks.

### Migration Steps

#### 1. Review your install.conf.yaml

```bash
cat ~/dotfiles/install.conf.yaml
```

#### 2. Install this dotfiles

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
```

#### 3. Add your files

For each entry in your dotbot config:

```yaml
# dotbot config:
- link:
    ~/.zshrc: zsh/zshrc
    ~/.config/nvim: nvim
```

Becomes:
```bash
chezmoi add ~/.zshrc
chezmoi add ~/.config/nvim
```

#### 4. Handle shell commands

dotbot shell commands become chezmoi scripts:

```yaml
# dotbot:
- shell:
    - [git submodule update --init, Installing submodules]
```

Becomes `~/.dotfiles/run_once_install-submodules.sh`:
```bash
#!/bin/bash
git submodule update --init
```

---

## Common Post-Migration Tasks

### Verify managed files

```bash
chezmoi managed
```

### Check for drift

```bash
chezmoi diff
```

### Run setup wizard

```bash
dot setup
```

### Run health check

```bash
dot doctor
```

---

## Getting Help

If you encounter issues during migration:

1. **Check the troubleshooting guide**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. **Run diagnostics**: `dot doctor`
3. **Open an issue**: [GitHub Issues](https://github.com/sebastienrousseau/dotfiles/issues)

---

## See Also

- [Installation Guide](INSTALL.md)
- [Architecture](ARCHITECTURE.md)
- [CLI Reference](CLI_REFERENCE.md)
