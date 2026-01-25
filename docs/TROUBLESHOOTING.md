# Troubleshooting

This page lists quick checks for common issues.

## Install and update

**Problem:** Install script fails immediately
- Ensure `git` and `curl` are installed.
- Check internet connectivity.
- Try running with verbose output: `bash -x install.sh`

**Problem:** Chezmoi apply fails
- Re-run `chezmoi apply` to re-sync state.
- Check for merge conflicts: `chezmoi diff`
- If hooks fail, check `~/.local/share/dotfiles.log` for details.

**Problem:** Packages fail to install
- macOS: Ensure Homebrew is installed and up to date (`brew update`)
- Linux: Run `sudo apt-get update` first
- Check if you have sufficient permissions

## Shell startup

**Problem:** Shell is slow to start
- Run `dot benchmark` to measure startup time
- Profile with `zsh -x` to trace startup
- Check for slow plugins or large history files

**Problem:** Aliases or functions not available
- Run `chezmoi apply` to regenerate config files
- Source your shell config: `source ~/.zshrc`
- Check if the relevant tool is installed

**Problem:** Shell crashes on startup
- Temporarily move `~/.zshrc` and retry to isolate the fault
- Check for syntax errors: `zsh -n ~/.zshrc`
- Review recent changes: `chezmoi diff`

## Secrets and encryption

**Problem:** Encrypted files fail to decrypt
- Confirm `~/.config/chezmoi/key.txt` exists.
- Verify the key matches the one used for encryption.
- Re-initialize with `dot secrets-init` if needed.

**Problem:** Age encryption not working
- Ensure `age` is installed: `command -v age`
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
- Ensure `delta` is installed
- Check terminal supports 256 colors

## Kubernetes tools

**Problem:** kubectl context issues
- List contexts: `kubectl config get-contexts`
- Switch context: `kubectx <context-name>`
- Check kubeconfig: `echo $KUBECONFIG`

**Problem:** Minikube won't start
- Check Docker is running
- Try: `minikube delete && minikube start`
- Check logs: `minikube logs`

## Performance

**Problem:** High memory usage
- Check for runaway processes: `htop` or `btop`
- Review shell history size in atuin config
- Disable unused plugins

## Still stuck

Open an issue with:
- OS + version
- Output of `dot doctor` (if available)
- Relevant log snippets from `~/.local/share/dotfiles.log`
- Steps to reproduce the issue
