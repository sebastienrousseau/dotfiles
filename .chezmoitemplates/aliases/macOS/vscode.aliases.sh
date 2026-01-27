# shellcheck shell=bash
# VS Code Aliases

if command -v code &>/dev/null || [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
  if [[ "$(uname || true)" = "Darwin" ]]; then
    alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
  fi

  alias vs="code"
  # alias vsc="code" -> Managed by function in functions.sh
  alias vscode="code"
fi
