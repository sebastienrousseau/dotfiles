# Troubleshooting

Fast checks for common issues.

## Install And Update

**Problem:** Install script fails immediately
- Verify that `git` and `curl` are installed.
- Check internet connectivity.
- Run with verbose output: `bash -x install.sh`

**Problem:** Chezmoi apply fails
- Re-run `chezmoi apply` to re-sync state.
- Check for merge conflicts: `chezmoi diff`
- If hooks fail, check `~/.local/share/dotfiles.log` for details.

**Problem:** Packages fail to install
- macOS: Verify Homebrew is installed and up to date (`brew update`)
- Linux: Run `sudo apt-get update` first
- Verify you have sufficient permissions

## Shell Startup

**Problem:** Shell is slow to start
- Run `dot benchmark` to measure startup time
- Profile with `zsh -x` to trace startup
- Check for slow plugins or large history files

**Problem:** Aliases or functions not available
- Run `chezmoi apply` to regenerate config files
- Source your shell config: `source ~/.zshrc`
- Verify the relevant tool is installed

**Problem:** Shell crashes on startup
- Temporarily move `~/.zshrc` and retry to isolate the fault
- Check for syntax errors: `zsh -n ~/.zshrc`
- Review recent changes: `chezmoi diff`

## Secrets And Encryption

**Problem:** Encrypted files fail to decrypt
- Confirm `~/.config/chezmoi/key.txt` exists.
- Verify the key matches the one used for encryption.
- Re-initialize with `dot secrets-init` if needed.

**Problem:** Age encryption not working
- Verify `age` is installed: `command -v age`
- Check key permissions: `ls -la ~/.config/chezmoi/key.txt` (should be 600)

## Neovim

**Problem:** Plugins fail to load
- Run `:checkhealth` in Neovim
- Update plugins: `:Lazy sync`
- Check for missing dependencies (node, python, etc.)

**Problem:** LSP not working
- Install required language servers
- Check `:LspInfo` for status
- Review `:LspLog` for errors

## Git

**Problem:** Git aliases not working
- Check if Git config is applied: `git config --list`
- Re-apply dotfiles: `chezmoi apply`

**Problem:** Delta (diff pager) not showing colors
- Verify `delta` is installed
- Confirm your terminal supports 256 colors

## Kubernetes Tools

**Problem:** kubectl context issues
- List contexts: `kubectl config get-contexts`
- Switch context: `kubectx <context-name>`
- Check kubeconfig: `echo $KUBECONFIG`

**Problem:** Minikube won't start
- Verify Docker is running
- Try: `minikube delete && minikube start`
- Check logs: `minikube logs`

## Performance

**Problem:** High memory usage
- Look for runaway processes: `htop` or `btop`
- Review shell history size in atuin config
- Disable unused plugins

## Advanced Troubleshooting

### WSL2 and Nix Integration Issues

For complex WSL2 edge cases, Nix integration problems, and recovery procedures, see the comprehensive guide:
**[WSL2 & Nix Troubleshooting Guide](WSL2_NIX_TROUBLESHOOTING.md)**

This guide covers:
- WSL2 filesystem and networking edge cases
- Nix installation and flake management issues
- Complete system recovery procedures
- Performance optimization for WSL2/Nix environments
- Cross-platform migration scenarios

## Still Stuck

Open an issue with:
- OS + version
- Output of `dot doctor` (if available)
- Relevant log snippets from `~/.local/share/dotfiles.log`
- Steps to reproduce the issue
- For WSL2/Nix issues: Include diagnostic report from the advanced guide
