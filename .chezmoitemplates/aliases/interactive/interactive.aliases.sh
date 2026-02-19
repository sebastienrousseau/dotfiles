# shellcheck shell=bash
# 🅸🅽🆃🅴🆁🅰🅲🆃🅸🆅🅴 🅰🅻🅸🅰🆂🅴🆂

# File manipulation aliases (opt-in; overrides core commands)
if [[ "${DOTFILES_SAFE_ALIASES:-0}" == "1" ]]; then
  # cp: Copy files and directories interactively (ask before overwrite) with verbose output.
  alias cp="cp -vi"

  # del: Remove files or directories interactively (ask before each removal) with verbose output, recursively.
  alias del="rm -rfvi"

  # ln: Create symbolic links interactively (ask before overwrite) with verbose output.
  alias ln='ln -vi'

  # mv: Move or rename files interactively (ask before overwrite) with verbose output.
  alias mv='mv -vi'

  # rm: Remove files or directories interactively (ask before each removal) with verbose output.
  alias rm='rm -vi'

  # zap: Alias for 'rm', removes files or directories interactively (ask before each removal) with verbose output.
  alias zap='rm -vi'

  # Trash manipulation alias
  # bin: Remove all files in the trash directory (user's .Trash) forcefully and recursively.
  alias bin='rm -fr ${HOME}/.Trash'

  # Other interactive aliases
  # diff: Compare and show differences between two files in unified format.
  alias diff='diff -u'

  # mkdir: Create a new directory, making parent directories as needed, with verbose output.
  alias mkdir='mkdir -pv'
fi
