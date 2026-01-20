# VS Code Aliases

if [[ "$(uname || true)" = "Darwin" ]]; then
  alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
elif [[ "$(uname || true)" = "Linux" ]]; then
  alias code="code"
fi

alias vs="code"
# alias vsc="code" -> Managed by function in functions.sh
alias vscode="code"
