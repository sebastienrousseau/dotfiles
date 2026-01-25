# Troubleshooting

This page lists quick checks for common issues.

## Install / Update

- Ensure `git` and `curl` are installed.
- Re-run `chezmoi apply` to re-sync state.
- If hooks fail, check `~/.local/share/dotfiles.log` for details.

## Shell Startup Errors

- Run `zsh -x` to trace startup.
- Temporarily move `~/.zshrc` and retry to isolate the fault.

## Secrets / age

- Confirm `~/.config/chezmoi/key.txt` exists.
- Re-initialize with `dot secrets-init` if needed.

## Still stuck?

Open an issue with:
- OS + version
- Output of `dot doctor` (if available)
- Relevant log snippets from `~/.local/share/dotfiles.log`
